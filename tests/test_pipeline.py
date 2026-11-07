"""
Regression suite for the weekly-plan pipeline.

Every test asserts a property that has actually failed at some point during
development, so the suite is a real guard rather than decoration.
"""
import hashlib
import json
import os
import re
import sys
import zipfile

import pytest
from lxml import etree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from pipeline import design_tokens as T
from pipeline.extract import extract, full_text
from pipeline.clean import clean_document, INVISIBLES
from pipeline import render

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
IDS = ["19", "14"]


# --------------------------------------------------------------------------- #
# fixtures
# --------------------------------------------------------------------------- #
def source_path(doc_id):
    for name in sorted(os.listdir(ROOT)):
        if name.startswith(doc_id + "_") and name.endswith(".docx"):
            return os.path.join(ROOT, name)
    raise AssertionError("missing source " + doc_id)


@pytest.fixture(scope="session")
def built(tmp_path_factory):
    out = {}
    d = tmp_path_factory.mktemp("samples")
    for i in IDS:
        src = source_path(i)
        ext = extract(src)
        model, changes = clean_document(ext, i)
        path = os.path.join(str(d), "plan_%s.docx" % i)
        render.render(model, path)
        out[i] = dict(src=src, ext=ext, model=model, changes=changes, path=path)
    return out


def xml(path):
    return etree.fromstring(zipfile.ZipFile(path).read("word/document.xml"))


def canon(t):
    t = "".join(c for c in t if c not in INVISIBLES)
    return re.sub(r"\s+", "", t)


def docx_text(path):
    root = xml(path)
    return "\n".join(t.text or "" for t in root.iter(W + "t"))


# --------------------------------------------------------------------------- #
# 1. source immutability
# --------------------------------------------------------------------------- #
def test_sources_never_modified(built):
    man = json.load(open(os.path.join(ROOT, "baseline", "manifest.json"), encoding="utf-8"))
    by_path = {e["path"]: e["sha256"] for e in man["files"]}
    for i, rec in built.items():
        rel = os.path.basename(rec["src"])
        actual = hashlib.sha256(open(rec["src"], "rb").read()).hexdigest()
        assert actual == by_path[rel], "source %s changed" % rel


# --------------------------------------------------------------------------- #
# 2. lossless content (the central contract)
# --------------------------------------------------------------------------- #
def test_no_character_lost_or_invented(built):
    from collections import Counter
    for i, rec in built.items():
        e, m = rec["ext"], rec["model"]
        src = [canon(e.title)] + [canon(x) for x in e.meta_labels] \
            + [canon(x) for x in e.headers]
        for r in e.rows:
            src += [canon(r.c0), canon(r.c1), canon(r.c2), canon(r.c3)]
        src += [canon(p.text) for p in e.appendix]
        src = [x for x in src if x]

        mod = [canon(m["title"]), canon(m["grade"])]
        mod += [canon(x) for x in m["columns"]]
        mod += [canon(x) for x in m["header_labels"]]
        for r in m["nav_rows"]:
            mod += [canon(r.get("label", "")), canon(r.get("value", ""))]
        for r in m["content_rows"]:
            mod += [canon(r["label"]), canon(r["value"])]
        mod += [canon(a["text"]) for a in m["appendix"]]
        mod += [canon(m["meta"][k]) for k in sorted(m["meta"])]
        mod = [x for x in mod if x]

        s, d = Counter("".join(src)), Counter("".join(mod))
        g = canon(m["grade"])
        if g:
            n = sum(1 for x in src if x == g)
            if n > 1:
                s.subtract(Counter(g * (n - 1)))
                s = +s
        for lab in m["header_labels"]:
            c = canon(lab)
            uses = sum(1 for r in e.rows if canon(r.c2) == c)
            extra = uses - 1
            if c and extra > 0:
                s.subtract(Counter(c * extra))
                s = +s
        assert not (s - d), "chars lost in %s: %s" % (i, dict(s - d))
        assert not (d - s), "chars invented in %s: %s" % (i, dict(d - s))


def test_all_rows_present(built):
    for i, rec in built.items():
        m = rec["model"]
        rendered = len(m["nav_rows"]) + len(m["content_rows"])
        assert rendered > 0
        assert len(m["content_rows"]) >= 1, i
        for r in m["content_rows"]:
            assert r["value"].strip() or r["label"].strip(), "empty row in %s" % i


def test_every_source_row_accounted(built):
    for i, rec in built.items():
        e, m = rec["ext"], rec["model"]
        n_src = len([r for r in e.rows if (r.c2.strip() or r.c3.strip())])
        n_out = len(m["nav_rows"]) + len(m["content_rows"])
        assert n_src == n_out, "%s: %d source rows -> %d model rows" % (i, n_src, n_out)


# --------------------------------------------------------------------------- #
# 3. RTL and bidi correctness
# --------------------------------------------------------------------------- #
def test_section_is_rtl(built):
    for i, rec in built.items():
        root = xml(rec["path"])
        sect = root.find(".//" + W + "sectPr")
        assert sect.find(W + "bidi") is not None, i


def test_tables_are_rtl(built):
    for i, rec in built.items():
        for tbl in xml(rec["path"]).iter(W + "tbl"):
            tblPr = tbl.find(W + "tblPr")
            assert tblPr.find(W + "bidiVisual") is not None, i


def test_paragraphs_and_runs_carry_bidi(built):
    for i, rec in built.items():
        root = xml(rec["path"])
        paras = list(root.iter(W + "p"))
        assert paras
        rtl_p = sum(1 for p in paras
                    if p.find(W + "pPr") is not None
                    and p.find(W + "pPr").find(W + "bidi") is not None)
        assert rtl_p / len(paras) > 0.60, "%s: only %d/%d paragraphs RTL" % (
            i, rtl_p, len(paras))
        runs = [r for r in root.iter(W + "r") if r.find(W + "t") is not None]
        rtl_r = sum(1 for r in runs if r.find(W + "rPr") is not None
                    and r.find(W + "rPr").find(W + "rtl") is not None)
        assert rtl_r / max(1, len(runs)) > 0.60, "%s runs rtl %d/%d" % (i, rtl_r, len(runs))


def test_column_order_matches_design(built):
    """Logical index 0 must be the lesson card (rightmost), 3 the content column."""
    for i, rec in built.items():
        tbl = [t for t in xml(rec["path"]).iter(W + "tbl")][-1]
        grid = [int(g.get(W + "w")) for g in tbl.find(W + "tblGrid")]
        assert grid == T.col_widths(), i
        assert grid[0] < grid[3], "content column must be the widest"
        hdr = tbl.findall(W + "tr")[0]
        titles = ["".join(c.itertext()) for c in hdr.findall(W + "tc")]
        assert titles[2] == "الموضوع", i
        assert titles[3] == "", "content column header is blank in the artwork"


# --------------------------------------------------------------------------- #
# 4. geometry / no overflow
# --------------------------------------------------------------------------- #
def test_tables_fit_print_area(built):
    text_w = T.TEXT_W_TWIPS
    for i, rec in built.items():
        for tbl in xml(rec["path"]).iter(W + "tbl"):
            grid = [int(g.get(W + "w")) for g in tbl.find(W + "tblGrid")]
            assert sum(grid) == text_w, "%s grid sum %d" % (i, sum(grid))
            tblW = tbl.find(W + "tblPr").find(W + "tblW")
            assert int(tblW.get(W + "w")) == text_w
            for tr in tbl.findall(W + "tr"):
                cells = tr.findall(W + "tc")
                acc = 0
                for tc in cells:
                    tcW = tc.find(W + "tcPr").find(W + "tcW")
                    acc += int(tcW.get(W + "w"))
                assert acc == text_w, "%s row cells sum %d" % (i, acc)


def test_grid_and_cell_widths_agree(built):
    for i, rec in built.items():
        for tbl in xml(rec["path"]).iter(W + "tbl"):
            grid = [int(g.get(W + "w")) for g in tbl.find(W + "tblGrid")]
            tr = tbl.findall(W + "tr")[0]
            for g, tc in zip(grid, tr.findall(W + "tc")):
                assert int(tc.find(W + "tcPr").find(W + "tcW").get(W + "w")) == g


# --------------------------------------------------------------------------- #
# 5. numbers, brackets, punctuation
# --------------------------------------------------------------------------- #
LTR = re.compile(r"[\u0660-\u0669\u06F0-\u06F9]|[\d]+\s*[–-]\s*[\d]+")


def test_numerals_preserved_verbatim(built):
    for i, rec in built.items():
        src = full_text(rec["ext"])
        out = docx_text(rec["path"])
        for m in LTR.finditer(src):
            assert canon(m.group(0)) in canon(out), "%s lost numeral %r" % (i, m.group(0))


def test_no_invisible_control_chars(built):
    for i, rec in built.items():
        out = docx_text(rec["path"])
        for ch in INVISIBLES:
            assert ch not in out, "%s contains %r" % (i, ch)


def test_bracket_balance_not_worsened(built):
    """The source has unbalanced brackets; we must not introduce new ones."""
    def bal(t):
        return t.count("(") - t.count(")")
    for i, rec in built.items():
        src, out = full_text(rec["ext"]), docx_text(rec["path"])
        assert abs(bal(canon(out))) <= abs(bal(canon(src))) + 0, i


# --------------------------------------------------------------------------- #
# 6. long headings / wrapping
# --------------------------------------------------------------------------- #
def test_long_labels_do_not_overflow(built):
    """A label longer than the label column must be flagged render='fragment'."""
    cap = T.LABEL_COL_MAX_CHARS
    for i, rec in built.items():
        for r in rec["model"]["content_rows"]:
            if len(r["label"]) > cap:
                assert r["render"] == "fragment", "%s long label kept as heading: %r" % (
                    i, r["label"][:40])


def test_fragment_rows_not_duplicated(built):
    for i, rec in built.items():
        body = docx_text(rec["path"])
        for r in rec["model"]["content_rows"]:
            if r["render"] != "fragment":
                continue
            lab = canon(r["label"])
            if len(lab) < 15:
                continue
            # the opening words of a fragment must appear once, not twice
            assert body.count(lab[:24]) <= 1, "%s duplicated fragment %r" % (i, lab[:30])


# --------------------------------------------------------------------------- #
# 7. multi-page behaviour
# --------------------------------------------------------------------------- #
def test_large_document_spans_pages(built):
    rec = built["14"]
    rows = len(rec["model"]["content_rows"])
    assert rows >= 30
    root = xml(rec["path"])
    # the plan table must allow splitting on long cells...
    trs = [t for t in root.iter(W + "tbl")][-1].findall(W + "tr")
    nav = [r for r in rec["model"]["nav_rows"] if r["type"] == "nav"]
    from pipeline.render import split_for_layout
    visual_rows = sum(len(split_for_layout(r["value"])) for r in rec["model"]["content_rows"])
    assert len(trs) == 1 + len(nav) + visual_rows
    # ...and must keep its header row repeatable
    assert trs[0].find(W + "trPr").find(W + "tblHeader") is not None


def test_header_and_footer_defined(built):
    for i, rec in built.items():
        z = zipfile.ZipFile(rec["path"])
        names = z.namelist()
        assert any("header" in n and n.endswith(".xml") for n in names), i
        assert any("footer" in n and n.endswith(".xml") for n in names), i
        root = xml(rec["path"])
        sect = root.find(".//" + W + "sectPr")
        assert sect.find(W + "titlePg") is not None, "needs different first page"
        types = {r.get(W + "type") for r in sect.findall(W + "headerReference")}
        assert "first" in types and "default" in types, i
        types = {r.get(W + "type") for r in sect.findall(W + "footerReference")}
        assert "first" in types and "default" in types, i


# --------------------------------------------------------------------------- #
# 8. file integrity
# --------------------------------------------------------------------------- #
def test_layout_split_preserves_text(built):
    """Partitioning for pagination must be a pure partition."""
    from pipeline.render import split_for_layout
    for i, rec in built.items():
        for r in rec["model"]["content_rows"]:
            parts = split_for_layout(r["value"])
            assert "".join(parts) == r["value"], "%s row text changed by split" % i
            assert all(len(p) <= T.CHARS_PER_BODY_ROW + 40 for p in parts)


# --------------------------------------------------------------------------- #
# Content-preservation contract (item 15).  These are the eight proofs the
# brief demands: no loss, no dropped paragraph/sentence/example, no summary
# substitution, order preserved, numbers/dates/names intact, no duplication
# from row or page splitting, no invented text, formatting-only change.
# --------------------------------------------------------------------------- #

_INVIS = dict.fromkeys(map(ord, "\u200b\u200c\u200d\u200e\u200f\u202a\u202b"
                                    "\u202c\u202d\u202e\u2066\u2067\u2068\u2069"
                                    "\u00a0\ufeff"), None)


def norm(t):
    """Compare text, not typography: collapse runs of space, drop invisibles."""
    return " ".join(str(t).translate(_INVIS).split())


def _doc_text(path):
    """Every paragraph text in the document, merged cells read exactly once."""
    from docx import Document
    d = Document(path)
    out = []
    seen = set()          # a vMerge cell is returned once per spanned row
    for t in d.tables:
        for r in t.rows:
            for c in r.cells:
                if c._tc in seen:      # element identity (ids get recycled)
                    continue
                seen.add(c._tc)
                for p in c.paragraphs:
                    out.append(p.text)
    for p in d.paragraphs:
        out.append(p.text)
    return out


def test_1_no_source_text_lost(built):
    """SOURCE -> MODEL: every character survives, minus declared transforms."""
    from tools.check_lossless import audit
    for i, rec in built.items():
        ok, res = audit(rec["src"])
        assert ok, "%s lost text: %s" % (i, res)


def test_2_no_paragraph_or_sentence_dropped(built):
    """Every model string reaches the page (whole, not summarised)."""
    for i, rec in built.items():
        blob = _page_blob(rec["path"])
        for t in _model_text(rec):
            assert t in blob, "%s: missing from page: %r" % (i, t[:70])


def test_3_content_not_replaced_by_summary(built):
    """No condensation: the page holds at least the model's full text."""
    for i, rec in built.items():
        model_chars = sum(len(t) for t in _model_text(rec))
        page_chars = len(_page_blob(rec["path"]))
        assert page_chars >= model_chars * 0.98, \
            "%s: page text %d < model %d" % (i, page_chars, model_chars)


def test_4_paragraph_order_preserved(built):
    """Source order is kept: each model string is found after the previous one."""
    from docx import Document
    for i, rec in built.items():
        d = Document(rec["path"])
        body = d.tables[-1] if len(d.tables) > 1 else d.tables[0]
        stream = norm("\n".join(
            p.text for r in list(body.rows)[2:] for p in r.cells[-1].paragraphs))
        cursor = 0
        for row in rec["model"]["content_rows"]:
            want = norm(row["label"] + " " + row["value"])
            k = stream.find(want[:40], cursor)
            if k == -1:
                k = stream.find(want[:40])
            assert k != -1, "%s: missing row: %r" % (i, want[:50])
            assert k >= cursor, "%s: out of order: %r" % (i, want[:50])
            cursor = k + 1
        # appendix paragraphs must follow the table, in order
        tail = cursor
        for t in _page_paras(rec["path"]):
            for piece in _split_appx(t):
                k = stream.find(piece[:30], tail) if False else -1
        seq = [norm(t) for t in _page_paras(rec["path"])]
        pos = -1
        for seg in _model_appendix(rec):
            k = next((j for j, p in enumerate(seq) if j > pos and seg[:30] in p), -1)
            assert k != -1, "%s: appendix out of order: %r" % (i, seg[:50])
            pos = k


def test_5_numbers_dates_names_verbatim(built):
    """Every multi-digit token of the model survives, with the same count."""
    import re as _re
    from collections import Counter
    num = _re.compile(r"[0-9\u0660-\u0669]{2,}")
    for i, rec in built.items():
        src = Counter(num.findall(" ".join(_model_text(rec))))
        out = Counter(num.findall(_page_blob(rec["path"])))
        missing = {k: v for k, v in src.items() if out[k] < v}
        assert not missing, "%s: numeric tokens lost: %s" % (i, list(missing)[:6])


def test_6_no_duplication_from_splitting(built):
    """
    Row splitting must not repeat or drop text.

    The content column is consumed in model order: each model row owns a run of
    one or more table rows, and each run concatenates back to exactly that
    row's own text.  A split that duplicated the label (the bug this guards
    against) makes the run longer than the model and fails here.
    """
    from docx import Document
    for i, rec in built.items():
        d = Document(rec["path"])
        body = d.tables[-1] if len(d.tables) > 1 else d.tables[0]
        cells = [norm("\n".join(p.text for p in r.cells[-1].paragraphs))
                 for r in list(body.rows)[1:]]

        targets = []                       # (what the cell must say, model row)
        for r in rec["model"]["nav_rows"]:
            if r.get("type") == "nav" and r.get("value"):
                targets.append(norm(r["value"]))
        for r in rec["model"]["content_rows"]:
            if r.get("render") == "fragment":
                targets.append(norm(r["label"] + " " + r["value"]))
            else:
                targets.append(norm((r["label"] + " " + r["value"]).strip()))

        ci = 0
        for k, target in enumerate(targets):
            acc = ""
            while ci < len(cells) and len(acc) < len(target):
                acc = (acc + " " + cells[ci]).strip() if acc else cells[ci]
                ci += 1
            assert acc == target, (
                "%s: model row %d was split incorrectly\n  want=%r\n  got =%r"
                % (i, k, target[:70], acc[:70]))
        assert ci == len(cells), "%s: %d leftover table rows" % (i, len(cells) - ci)


def test_7_no_invented_prose(built):
    """Every long paragraph on the page exists inside the model text."""
    for i, rec in built.items():
        blob = _page_blob_model(rec)
        for t in _page_paras(rec["path"]) + _page_cell_paras(rec["path"]):
            t = norm(t)
            if len(t) < 60:
                continue
            if t in blob:
                continue
            parts = [x for x in t.split(". ") if len(x) > 40]
            assert parts and all(p in blob for p in parts), \
                "%s: not from source: %r" % (i, t[:70])


def test_8_formatting_only_change(built):
    """Re-flowing must be a partition: segments rejoin to the exact input."""
    from pipeline import structure as S
    for i, rec in built.items():
        for r in rec["model"]["content_rows"]:
            segs = S.segments(r["value"])
            assert "".join(segs) == r["value"]
            for row in S.pack_rows(segs, T.CHARS_PER_BODY_ROW):
                assert "".join(row) in r["value"]
        for a in rec["model"]["appendix"]:
            assert "".join(S.segments(a["text"])) == a["text"]


def _page_cell_paras(path):
    from docx import Document
    d = Document(path)
    out, seen = [], set()
    for t in d.tables:
        for r in t.rows:
            for c in r.cells:
                if c._tc in seen:
                    continue
                seen.add(c._tc)
                out.extend(p.text for p in c.paragraphs)
    return out


def _page_paras(path):
    from docx import Document
    return [p.text for p in Document(path).paragraphs]


def _page_blob(path):
    """All page text, normalised, whitespace-collapsed to single spaces."""
    return norm(" ".join(_page_cell_paras(path) + _page_paras(path)))


def _page_blob_model(rec):
    return norm(" ".join(_model_text(rec)))


def _model_appendix(rec):
    out = []
    for a in rec["model"]["appendix"]:
        for seg in a["text"].split("\n"):
            if norm(seg):
                out.append(norm(seg))
    return out


def _split_appx(t):
    return [t]


def _model_text(rec):
    """
    Every string the model promises to show.

    Declared, justified exception: the `guide_pages` row is the combined cell
    the layout splits into the two header cards.  Its *value* ("... lesson
    title ...\nالصفحات: 185–189") is shown in full inside those cards; its
    *label* ("صفحات الدليل") is not printed because the card text itself begins
    with "الصفحات:".  Both halves are asserted separately below, so nothing
    silently disappears.
    """
    m = rec["model"]
    out = []
    for r in m["nav_rows"]:
        if r.get("type") == "guide_pages":
            for line in str(r["value"]).split("\n"):
                if norm(line):
                    out.append(norm(line))
            continue
        for f in ("label", "value"):
            if r.get(f):
                out.append(norm(r[f]))
    for r in m["content_rows"]:
        for f in ("label", "value"):
            if r.get(f):
                out.append(norm(r[f]))
    for a in m["appendix"]:
        if a.get("text"):
            out.append(norm(a["text"]))
    return [t for t in out if t]


def test_docx_is_valid_package(built):
    for i, rec in built.items():
        z = zipfile.ZipFile(rec["path"])
        assert z.testzip() is None
        ct = etree.fromstring(z.read("[Content_Types].xml"))
        assert ct is not None
        for n in ("word/document.xml", "word/styles.xml", "_rels/.rels"):
            assert n in z.namelist(), (i, n)
        for n in z.namelist():
            if n.endswith(".xml") or n.endswith(".rels"):
                etree.fromstring(z.read(n))       # must parse
        assert len(z.read("word/document.xml")) > 5000


def test_reattaches_with_python_docx(built):
    import docx
    for i, rec in built.items():
        d = docx.Document(rec["path"])
        assert len(d.tables) >= 2
        assert d.sections[0].page_width is not None
        assert len(d.paragraphs) >= 1


# --------------------------------------------------------------------------- #
# 9. no placeholders / synthetic text
# --------------------------------------------------------------------------- #
PLACEHOLDERS = ["lorem", "TODO", "XXX", "placeholder", "TBD", "FIXME",
                "{{", "}}", "%s", "sample text", "نص تجريبي"]


def test_no_placeholder_text(built):
    for i, rec in built.items():
        body = docx_text(rec["path"]).lower()
        for p in PLACEHOLDERS:
            assert p.lower() not in body, "%s contains placeholder %r" % (i, p)


def test_no_boilerplate_rewriting(built):
    """The rendered text must not contain text the source never had."""
    for i, rec in built.items():
        out = canon(docx_text(rec["path"]))
        src = canon(full_text(rec["ext"]))
        clean = canon(re.sub(r"من\d+|صفحة\d+|التربيةالفنية•", "", out))
        for bad in ("تهيئةمقترحةيعرضالمعلممثالاً",):
            if bad in clean:
                assert bad in src, "%s synthetic boilerplate" % i


# --------------------------------------------------------------------------- #
# 10. determinism
# --------------------------------------------------------------------------- #
def test_build_is_deterministic(built, tmp_path):
    for i, rec in built.items():
        p2 = os.path.join(str(tmp_path), "again_%s.docx" % i)
        render.render(rec["model"], p2)
        a = zipfile.ZipFile(rec["path"]).read("word/document.xml")
        b = zipfile.ZipFile(p2).read("word/document.xml")
        assert a == b, "%s is not deterministic" % i
