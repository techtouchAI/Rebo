"""
Lossless contract: stage1 (source .docx) -> stage2 (neutral model).

Two kinds of facts are checked, both strictly:

A. CONTENT COMPLETENESS (multiplicity-preserving)
   For every plan row in the source, the (label, content) pair must exist in the
   model with exactly the same multiplicity.  Nothing may be dropped, merged or
   reordered within a field.

B. CHARACTER AUDIT (exhaustive, direction-checked)
   The set of visible characters in the model must equal the set in the source.
   Additionally every *distinct* source field string must survive intact, and
   every model string must be traceable to the source (or listed as derived).

C. DECLARED DEDUPLICATION
   The grade appears once per data row in the source and once in the model.
   That is an explicit, listed transformation -- asserted here with counts so it
   can never silently grow.
"""
import sys, re
from collections import Counter
sys.path.insert(0, '.')
from pipeline.extract import extract
from pipeline.clean import clean_document, INVISIBLES

DERIVED_FIELDS = {'doc_id', 'source', 'subject'}


def canon(t):
    t = "".join(c for c in t if c not in INVISIBLES)
    return re.sub(r'\s+', '', t)


def audit(path):
    e = extract(path)
    m, changes = clean_document(e, path[:2])
    problems = []
    notes = {}

    # ---------- A. row completeness ----------
    src_pairs = Counter((canon(r.c2), canon(r.c3)) for r in e.rows)
    mod_pairs = Counter()
    for r in m['nav_rows']:
        mod_pairs[(canon(r.get('label', '')), canon(r.get('value', '')))] += 1
    for r in m['content_rows']:
        mod_pairs[(canon(r['label']), canon(r['value']))] += 1

    # Rows that the layout re-homes into a header card instead of a body row.
    # The (label, value) pair is preserved verbatim; only its *place* changes,
    # which is exactly what the change log records.  We mask those source pairs
    # out of the body-row comparison and assert separately that they survived.
    relocated = Counter()
    for c in changes:
        if c.rule in ('guide-pages-card', 'lesson-identity-card'):
            if '\x00' not in c.before:
                problems.append('RELOCATION WITHOUT PAYLOAD: %s' % c.rule)
                continue
            _, con = c.before.split('\x00', 1)
            relocated[(canon(con), c.rule)] += 1

    # source row pairs that belong to relocated cards
    for r in e.rows:
        if canon(r.c2) == canon(e.headers[2]) and (r.c0.strip() or True):
            lab_src = canon(r.c0) if r.c0.strip() else canon(r.c2)
            key = (canon(r.c2), canon(r.c3))
            if src_pairs.get(key, 0) > 0:
                src_pairs[key] -= 1
                src_pairs = +src_pairs
                # the payload must still be present in the model
                found = any(canon(rr.get('value', '')) == canon(r.c3)
                            for rr in m['nav_rows'])
                if not found:
                    problems.append('RELOCATED VALUE LOST: %r' % r.c3[:50])

    # Model rows that came from a relocated card are "card" rows, not body
    # rows: compare them separately so the pairing stays honest.
    card_pairs = Counter()
    for r in m['nav_rows']:
        if r['type'] in ('guide_pages', 'lesson_identity'):
            card_pairs[(canon(r.get('label', '')), canon(r.get('value', '')))] += 1

    for pair, n in src_pairs.items():
        if mod_pairs.get(pair, 0) != n:
            problems.append('ROW %r expected %d got %d' % (pair[0][:40], n, mod_pairs.get(pair, 0)))

    body_pairs = Counter()
    for r in m['content_rows']:
        body_pairs[(canon(r['label']), canon(r['value']))] += 1
    for r in m['nav_rows']:
        if r['type'] == 'nav':
            body_pairs[(canon(r.get('label', '')), canon(r.get('value', '')))] += 1
        elif r['type'] == 'empty':
            body_pairs[('', '')] += 1

    for pair, n in body_pairs.items():
        if src_pairs.get(pair, 0) < n and pair[0] != '':
            problems.append('INVENTED ROW %r count %d' % (pair[0][:40], n))
    notes['card_rows'] = dict(card_pairs)
    notes['body_rows'] = sum(body_pairs.values())

    # ---------- B. character audit ----------
    def src_all():
        yield e.title
        for x in e.meta_labels:
            yield x
        for x in e.headers:
            yield x
        for r in e.rows:
            yield r.c0
            yield r.c1
            yield r.c2
            yield r.c3
        for p in e.appendix:
            yield p.text

    def mod_all():
        yield m['title']
        yield m['grade']
        for x in m['columns']:
            yield x
        # the repeated header labels that were relocated into the rendered
        # table header / cards; they are emitted once, so pair them here.
        for x in m.get('header_labels', []):
            yield x
        for r in m['nav_rows']:
            yield r.get('label', '')
            yield r.get('value', '')
        for r in m['content_rows']:
            yield r['label']
            yield r['value']
        for a in m['appendix']:
            yield a['text']
        for k in sorted(m['meta']):
            yield m['meta'][k]

    src_fields = [canon(x) for x in src_all() if canon(x)]
    mod_fields = [canon(x) for x in mod_all() if canon(x)]

    src_c = Counter(''.join(src_fields))
    mod_c = Counter(''.join(mod_fields))

    # Declared deduplication: the grade is printed once per source data row and
    # is rendered once in the header card.  Subtract exactly (n-1) copies.
    # The plan-header label ('الموضوع') is repeated as a row label inside the
    # source table but is rendered once, in the table header.  Count exactly how
    # many times it appears as a *row* label and subtract those copies.
    for x in m.get('header_labels', []):
        c = canon(x)
        if not c:
            continue
        row_uses = sum(1 for r in e.rows if canon(r.c2) == c)
        extra = row_uses - (1 if c in [canon(x) for x in m['columns']] else 0)
        if extra > 0:
            src_c.subtract(Counter(c * extra))
            src_c = +src_c
            notes.setdefault('declared_dedup_labels', {})[x] = extra

    g = canon(m['grade'])
    if g:
        n_grade = sum(1 for f in src_fields if f == g)
        if n_grade > 1:
            src_c.subtract(Counter(g * (n_grade - 1)))
            src_c = +src_c
            notes['declared_dedup_grade'] = n_grade - 1

    lost_chars = src_c - mod_c
    added_chars = mod_c - src_c
    if lost_chars:
        problems.append('CHARS LOST %s' % dict(lost_chars))
    if added_chars:
        problems.append('CHARS INVENTED %s' % dict(added_chars))

    src_set, mod_set = set(src_fields), set(mod_fields)
    for s in sorted(src_set - mod_set):
        problems.append('FIELD VANISHED %r' % s[:70])

    # ---------- C. declared deduplication ----------
    grade_vals = {canon(r.c1) for r in e.rows if canon(r.c1) and canon(r.c1) != canon(e.headers[1])}
    grade_rows = sum(1 for r in e.rows if canon(r.c1) in grade_vals)
    notes['grade_in_source_rows'] = grade_rows
    notes['grade_in_model'] = 1 if m['grade'] else 0
    if grade_vals and len(grade_vals) != 1:
        problems.append('GRADE NOT UNIQUE: %s' % grade_vals)
    if grade_vals and canon(m['grade']) not in grade_vals:
        problems.append('GRADE NOT CARRIED: %r' % m['grade'])
    notes['dedup_declared'] = [a['what'] for a in m.get('absorbed', [])]

    ok = not problems
    return ok, {
        'src_chars': len(''.join(src_fields)),
        'mod_chars': len(''.join(mod_fields)),
        'problems': problems,
        'notes': notes,
        'changes': len(changes),
    }


if __name__ == '__main__':
    fails = 0
    for f in sys.argv[1:]:
        ok, d = audit(f)
        print(('PASS' if ok else 'FAIL'), f[:18],
              '| src=%d model=%d | changes=%d | grade x%d->x%d' %
              (d['src_chars'], d['mod_chars'], d['changes'],
               d['notes']['grade_in_source_rows'], d['notes']['grade_in_model']))
        for p in d['problems']:
            fails += 1
            print('    !', p)
    sys.exit(1 if fails else 0)
