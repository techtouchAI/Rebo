#!/usr/bin/env python3
"""
Rebo · content pipeline
=======================

Reads the official .docx sources in the repository root and produces the
structured data the app renders:

    app/www/js/data.js      window.REBO_CONTENT = {...}   (units, plans, index)
    app/www/media/*.jpg     the guide's illustration plates, split out of the
                            stacked scans embedded in the .docx files

Usage:
    python3 app/pipeline/build_content.py [--repo ROOT]

Only the Python standard library is required.
"""
import argparse
import json
import os
import re
import zipfile
from xml.etree import ElementTree as ET

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
AR_DIAC = re.compile('[\u064b-\u0652\u0670\u0640]')
SENT = re.compile(r'(?<=[.؟!])\s+')

DOC_ORDER = [
    ('08', 'الصف الأول المتوسط', 'الوحدة الأولى', 'التعبير الفني'),
    ('09', 'الصف الأول المتوسط', 'الوحدة الثانية', 'التصميم والزخرفة'),
    ('10', 'الصف الأول المتوسط', 'الوحدة الثالثة', 'التشكيل الفني والهندسي'),
    ('11', 'الصف الأول المتوسط', 'الوحدة الرابعة', 'التذوق وتاريخ الفن'),
    ('12', 'الصف الثاني المتوسط', 'الوحدة الأولى', 'التعبير الفني والهندسي'),
    ('13', 'الصف الثاني المتوسط', 'الوحدة الثانية', 'التصميم والزخرفة'),
    ('14', 'الصف الثاني المتوسط', 'الوحدة الثالثة', 'التشكيل المجسم'),
    ('15', 'الصف الثاني المتوسط', 'الوحدة الرابعة', 'التذوق الفني وتاريخ الفن'),
    ('16', 'الصف الثالث المتوسط', 'الوحدة الأولى', 'التعبير الفني والهندسي'),
    ('17', 'الصف الثالث المتوسط', 'الوحدة الثانية', 'التصميم والزخرفة'),
    ('18', 'الصف الثالث المتوسط', 'الوحدة الثالثة', 'التشكيل المجسم'),
    ('19', 'الصف الثالث المتوسط', 'الوحدة الرابعة', 'التذوق وتاريخ الفن'),
    ('20', 'المرحلة المتوسطة', 'وحدة عامة', 'مفردات الأنشطة المسرحية'),
]

PLAN_ORDER = [
    ('التعرف على الطلاب', 'الأول المتوسط', 'تهيئة'),
    ('المنظور', 'الأول المتوسط', 'نظري'),
    ('المنظور العملي', 'الأول المتوسط', 'عملي'),
    ('الظل والضوء', 'الأول المتوسط', 'نظري'),
    ('الظل والضوء العملي', 'الأول المتوسط', 'عملي'),
    ('الرخرفة', 'الأول المتوسط', 'نظري'),
    ('الزخرفة عملي', 'الأول المتوسط', 'عملي'),
    ('تصميم غلاف كتاب', 'الأول المتوسط', 'نظري'),
    ('تصميم غلاف كتاب عملي', 'الأول المتوسط', 'عملي'),
]

PLAN_LABELS = {
    'الموضوع': 'title',
    'الأهداف العامة': 'objectives',
    'الأهداف الخاصة': 'specific',
    'الوسائل التعليمية': 'tools',
    'المقدمة': 'intro',
    'العرض': 'present',
}


# --------------------------------------------------------------------- docx
def para_text(p):
    out = []
    for node in p.iter():
        if node.tag == W + 't':
            out.append(node.text or '')
        elif node.tag == W + 'tab':
            out.append(' ')
        elif node.tag == W + 'br':
            out.append('\n')
    return ''.join(out)


def para_runs(p):
    runs = []
    for r in p.iter(W + 'r'):
        t = ''.join(x.text or '' for x in r.iter(W + 't'))
        if not t:
            continue
        rpr = r.find(W + 'rPr')
        bold = False
        if rpr is not None:
            b = rpr.find(W + 'b')
            if b is not None and b.get(W + 'val') not in ('0', 'false'):
                bold = True
        runs.append((t, bold))
    return runs


def clean(t):
    t = (t.replace('\u200b', ' ').replace('\u200c', '').replace('\u200d', '')
         .replace('\u00a0', ' ').replace('\ufeff', ''))
    return re.sub(r'[ \t]+', ' ', t).strip()


def load(path):
    z = zipfile.ZipFile(path)
    root = ET.fromstring(z.read('word/document.xml'))
    paras = []
    for p in root.iter(W + 'p'):
        txt = clean(para_text(p))
        if not txt:
            continue
        runs = para_runs(p)
        paras.append({'t': txt, 'b': bool(runs) and all(b for _, b in runs)})
    tables = []
    for tbl in root.iter(W + 'tbl'):
        rows = []
        for tr in tbl.iter(W + 'tr'):
            rows.append([clean(' '.join(para_text(p) for p in tc.iter(W + 'p')))
                         for tc in tr.iter(W + 'tc')])
        tables.append(rows)
    media = [n for n in z.namelist() if n.startswith('word/media/')]
    return paras, tables, media, z


def split_plates(raw_bytes, out_dir, prefix, ext):
    """A guide page often stacks several illustration plates on one scan.
    Split the scan on fully-white horizontal bands and write each plate as its
    own trimmed JPEG. Falls back to a single plate when Pillow is unavailable."""
    try:
        import io
        from PIL import Image
    except ImportError:
        name = prefix + '_1' + ext
        with open(os.path.join(out_dir, name), 'wb') as f:
            f.write(raw_bytes)
        return [name]

    im = Image.open(io.BytesIO(raw_bytes)).convert('RGB')
    g = im.convert('L')
    mask = g.point(lambda p: 255 if p < 246 else 0)
    bbox = mask.getbbox()
    if bbox:
        pad = 8
        bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                min(im.width, bbox[2] + pad), min(im.height, bbox[3] + pad))
        im = im.crop(bbox)

    mask = im.convert('L').point(lambda p: 255 if p < 246 else 0)
    px = mask.convert('1').load()
    w, h = im.size
    empty = []
    for y in range(h):
        row_has_ink = any(px[x, y] for x in range(0, w, 4))
        empty.append(not row_has_ink)
    runs, start = [], None
    for y, is_empty in enumerate(empty):
        if is_empty and start is None:
            start = y
        elif not is_empty and start is not None:
            runs.append((start, y))
            start = None
    if start is not None:
        runs.append((start, h))
    cuts = [(a + b) // 2 for a, b in runs
            if (b - a) > h * 0.06 and a > 5 and b < h - 5]
    bounds = [0] + cuts + [h]

    names = []
    for i in range(len(bounds) - 1):
        top, bot = bounds[i], bounds[i + 1]
        if bot - top < 40:
            continue
        sub = im.crop((0, top, w, bot))
        trim = sub.convert('L').point(lambda p: 255 if p < 246 else 0).getbbox()
        if trim:
            sub = sub.crop(trim)
        if sub.width < 60 or sub.height < 60:
            continue
        if sub.width > 1000:
            sub = sub.resize((1000, round(sub.height * 1000 / sub.width)), Image.LANCZOS)
        name = '%s_%d.jpg' % (prefix, len(names) + 1)
        sub.save(os.path.join(out_dir, name), 'JPEG', quality=84,
                 optimize=True, progressive=True)
        names.append(name)
    if not names:
        name = prefix + '_1.jpg'
        im.save(os.path.join(out_dir, name), 'JPEG', quality=84, optimize=True)
        names.append(name)
    return names


def norm_label(t):
    t = AR_DIAC.sub('', t.replace('\u200b', '').replace('\u200c', ''))
    return re.sub(r'\s+', ' ', t).strip()


def norm_key(t):
    t = AR_DIAC.sub('', t)
    return re.sub(r'[^\u0621-\u064a\u0660-\u0669a-zA-Z0-9]', '', t)


def chunk_paragraphs(lines, target=420):
    """Join hard-wrapped docx lines, then re-split into readable paragraphs."""
    text = re.sub(r'\s+', ' ', ' '.join(l.strip() for l in lines)).strip()
    out, buf = [], ''
    for snt in SENT.split(text):
        if buf and len(buf) + len(snt) > target:
            out.append(buf.strip())
            buf = snt
        else:
            buf = (buf + ' ' + snt).strip()
    if buf:
        out.append(buf.strip())
    return [p for p in out if len(p) > 2]


def split_objectives(txt):
    txt = clean(txt)
    out = []
    for part in re.split(r'(?=\d\)\s)', txt):
        part = re.sub(r'^\d\)\s*', '', part).strip()
        if len(part) > 3:
            out.append(part)
    return out


def split_by_titles(paras, titles):
    """Split a flat prose block into sections anchored on the guide's own
    topic titles (taken from the lesson-summary bullets)."""
    text = '\n'.join(paras)
    norm, idx = [], []
    for i, ch in enumerate(text):
        c = norm_key(ch)
        if c:
            norm.append(c)
            idx.append(i)
    norm = ''.join(norm)
    marks, cursor = [], 0
    for t in titles:
        k = norm_key(t)[:28]
        if len(k) < 8:
            continue
        pos = norm.find(k, cursor)
        if pos < 0:
            pos = norm.find(k)
        if pos >= 0:
            marks.append((idx[pos], t))
            cursor = pos + len(k)
    if len(marks) < 2:
        return [{'title': 'شرح الدرس', 'paras': paras}] if paras else []
    out = []
    if marks[0][0] > 40:
        head = text[:marks[0][0]].strip()
        if head:
            out.append({'title': 'تمهيد', 'paras': chunk_paragraphs(head.split('\n'))})
    for n, (pos, title) in enumerate(marks):
        end = marks[n + 1][0] if n + 1 < len(marks) else len(text)
        seg = re.sub(r'\s*\n\s*', ' ', text[pos:end]).strip()
        seg = re.sub(r'^' + re.escape(title) + r'\s*', '', seg, count=1)
        seg = re.sub(r'^[-\u2013:؛.\s]+', '', seg)
        if len(seg) < 25:
            continue
        out.append({'title': title, 'paras': chunk_paragraphs([seg])})
    return out


# ---------------------------------------------------------------- unit docs
def parse_unit(prefix, root_dir):
    path = next(os.path.join(root_dir, f) for f in os.listdir(root_dir)
                if f.startswith(prefix + '_') and f.endswith('.docx'))
    paras, tables, media, z = load(path)
    texts = [p['t'] for p in paras]
    grade, unit_name, topic = next((g, u, t) for p, g, u, t in DOC_ORDER if p == prefix)
    unit = {'id': prefix, 'grade': grade, 'unitName': unit_name, 'title': topic,
            'pages': ''}

    for t in texts[:14]:
        m = re.search(r'الصفحات:\s*([\d\u0660-\u0669–-]+)', t)
        if m:
            unit['pages'] = m.group(1)
        if (' - ' in t and ('الوحدة' in t or 'مفردات' in t)
                and not t.startswith('تنمية')):
            unit['title'] = re.sub(r'الصفحات:.*', '', t).strip()

    label_idx = {}
    for i, p in enumerate(paras):
        for lab in ('الأهداف العامة', 'الأهداف الخاصة', 'الوسائل التعليمية', 'المقدمة'):
            if p['t'] == lab:
                label_idx[lab] = i
    if 'الأهداف العامة' in label_idx:
        unit['objectives'] = paras[label_idx['الأهداف العامة'] + 1]['t']
    if 'الأهداف الخاصة' in label_idx:
        unit['specific'] = split_objectives(paras[label_idx['الأهداف الخاصة'] + 1]['t'])
    if 'الوسائل التعليمية' in label_idx:
        unit['tools'] = paras[label_idx['الوسائل التعليمية'] + 1]['t']
    if 'المقدمة' in label_idx:
        unit['intro'] = paras[label_idx['المقدمة'] + 1]['t']

    # body between العرض and خلاصة الدرس
    start = None
    for i, p in enumerate(paras):
        if norm_label(p['t']).startswith('العرض'):
            start = i + 1
    if start is None and 'المقدمة' in label_idx:
        start = label_idx['المقدمة'] + 2
    stop = len(paras)
    for i, p in enumerate(paras):
        if p['t'].startswith('خلاصة الدرس'):
            stop = i
            break
    body = paras[start:stop] if start else []
    ORD = re.compile(r'^[0-9\u0660-\u0669]+\s*-\s*')
    unit['body'] = chunk_paragraphs([ORD.sub('', p['t']) for p in body])

    # summary / evaluation questions
    summ_start = next((i for i, p in enumerate(paras)
                       if p['t'].startswith('خلاصة الدرس')), None)
    unit['summary'], unit['mcq'], unit['truefalse'], unit['answerKey'] = [], [], [], ''
    if summ_start is not None:
        mode = None
        for p in paras[summ_start:]:
            t = p['t']
            if t.startswith('أولاً:'):
                mode = 'sum'
                continue
            if t.startswith('ثانياً:'):
                mode = 'mcq'
                continue
            if t.startswith('ثالثاً:'):
                mode = 'tf'
                continue
            if t.startswith('مفتاح الإجابة'):
                mode = 'key'
                continue
            if t.startswith('لوحة توضيحية') or t.startswith('المصدر:') or t.startswith('خلاصة الدرس'):
                mode = None
                continue
            if mode == 'sum' and t.startswith('•'):
                unit['summary'].append(t.lstrip('• ').strip())
            elif mode == 'mcq':
                m = re.match(r'^(\d+)\.\s*(.*)', t)
                if m:
                    q = {'n': int(m.group(1)), 'q': '', 'options': [], 'answer': None}
                    unit['mcq'].append(q)
                    chunks = re.split(r'\s(?=[أبج]\)\s)', m.group(2))
                    q['q'] = chunks[0].strip()
                    q['options'] += [re.sub(r'^[أبج]\)\s*', '', c).strip() for c in chunks[1:]]
                elif unit['mcq']:
                    q = unit['mcq'][-1]
                    for c in re.split(r'\s(?=[أبج]\)\s)', t):
                        c2 = re.sub(r'^[أبج]\)\s*', '', c).strip()
                        if c2:
                            if len(q['options']) < 3:
                                q['options'].append(c2)
                            else:
                                q['q'] += ' ' + c2
            elif mode == 'tf':
                m = re.match(r'^(\d+)\.\s*(.*)', t)
                if m:
                    unit['truefalse'].append({'n': int(m.group(1)), 'q': m.group(2).strip()})
            elif mode == 'key':
                unit['answerKey'] += ' ' + t

    key = unit['answerKey']
    mc = re.search(r'متعدد[:：]\s*([^|]+)', key)
    if mc:
        amap = {int(n): a for n, a in re.findall(r'(\d+)\s*[ـ\-]\s*([أبج])', mc.group(1))}
        for q in unit['mcq']:
            q['answer'] = amap.get(q['n'])
    tf = re.search(r'الخطأ[:：]\s*(.+)$', key)
    if tf:
        amap = {int(n): a for n, a in re.findall(r'(\d+)\s*[ـ\-]\s*(صح|خطأ)', tf.group(1))}
        for q in unit['truefalse']:
            q['answer'] = amap.get(q['n'])

    titles = []
    for b in unit['summary']:
        t = re.sub(r'[\u2026\.]+$', '', b.split('؛')[0].split(';')[0]).strip()
        t = re.sub(r'^[\u0660-\u0669\d]+\s*-\s*', '', t)
        if len(t) > 6 and t not in titles:
            titles.append(t)
    unit['topics'] = titles
    unit['sections'] = split_by_titles(unit['body'], titles)

    # illustration plates (scans may stack several plates on one page)
    plates = []
    for n in media:
        ext = os.path.splitext(n)[1].lower()
        if ext not in ('.jpg', '.jpeg', '.png'):
            continue
        plates += split_plates(z.read(n), OUT_MEDIA, prefix, ext)
    unit['plates'] = plates
    return unit


# -------------------------------------------------------------- lesson plans
LABEL_SEQ = [
    ('الموضوع', 'title'),
    ('الأهداف العامة', 'objectives'),
    ('الأهداف الخاصة', 'specific'),
    ('الوسائل التعليمية', 'tools'),
    ('المقدمة', 'intro'),
    ('العرض', 'present'),
]


def _collapse(lines):
    """Drop the duplicated/blank cells Word produces for merged table rows."""
    out = []
    for line in lines:
        line = line.replace('\u00a0', ' ').strip()
        if not line:
            continue
        if out and (norm_key(out[-1]) == norm_key(line)
                    or norm_key(out[-1]).endswith(norm_key(line))
                    or norm_key(line).endswith(norm_key(out[-1])) and len(line) < 22):
            if len(line) > len(out[-1]):
                out[-1] = line
            continue
        out.append(line)
    return out


def parse_plan_fallback(paras, plan):
    """Some lesson plans lay the table out label-after-content (or the table
    cells are merged beyond recognition). Recover the fields by reading the
    plan as a linear document and pairing each field label with the paragraph
    directly above it."""
    lines = _collapse([p['t'] for p in paras])
    keys = [norm_key(l) for l in lines]
    labels = [norm_key(x) for x, _ in LABEL_SEQ]

    # 1) collapse the runs of label cells into a single (field, end_index) list
    marks, i = [], 0
    while i < len(lines):
        for n in range(1, 4):           # a label can be split across 2–3 cells
            blob = ''.join(keys[i:i + n])
            hit = next((f for lab, f in LABEL_SEQ if blob == norm_key(lab)), None)
            if hit:
                marks.append((hit, i, i + n))
                i += n
                break
        else:
            i += 1

    # 2) fill each field from the text that sits *above* its label run, taking
    #    the lines back to (but not past) the previous label
    found = {}
    for idx, (field, start, _end) in enumerate(marks):
        floor = marks[idx - 1][2] if idx else 0
        picked = []
        for back in range(start - 1, floor - 1, -1):
            cand = lines[back]
            if norm_key(cand) in labels or len(cand) < 4:
                continue
            picked.insert(0, cand)
            if len(' '.join(picked)) > 24 and field != 'title':
                break
        if picked:
            found[field] = ' '.join(picked)
    return found


def parse_plan_degenerate(paras, plan, lines=None):
    """The «التعرف على الطلاب» plan is a single merged table cell: labels and
    contents are split into separate rows, so position-based parsing fails.
    Classify the lines by shape instead."""
    lines = lines or _collapse([p['t'] for p in paras])
    labels = [norm_key(x) for x, _ in LABEL_SEQ]
    noise = {'الأهداف', 'العامة', 'الخاصة', 'الوسائل', 'التعليمية', 'الموضوع',
             'المقدمة', 'العرض', 'ملاحظات', 'الصفوالشعبة', 'الدرس', 'معلومات'}
    content = [l for l in lines
               if norm_key(l) not in labels and norm_key(l) not in noise
               and not re.match(r'^(الأول|الثاني|الثالث) المتوسط$', l)
               and 'الخطة الأسبوعية' not in l and len(l) > 3]
    if not content:
        return plan
    TOOL = re.compile('السبورة|وسائل|صور|نماذج|مصباح|ألوان|خامات|أدوات|دفاتر')
    INTRO = re.compile('الترحيب|تهيئة|استذكار|سؤال|توجيه|تعريف الطلاب')
    ORDINAL = re.compile(r'^(الأول|الثاني|الثالث|الرابع)$')

    tools = [l for l in content if TOOL.search(l) and len(l.split()) <= 3]
    intro = next((l for l in content if INTRO.search(l) and l not in tools), None)
    rest = [l for l in content if l not in tools and l != intro
            and not ORDINAL.match(l)]
    if rest:
        plan.setdefault('title', rest[0])
    long_lines = [l for l in rest if len(l.split()) > 3]
    if long_lines:
        plan.setdefault('objectives', long_lines[0])
    if len(long_lines) > 1:
        plan.setdefault('specific', long_lines[1:])
    if tools:
        plan.setdefault('tools', tools[:4])
    if intro:
        plan.setdefault('intro', intro)
    return plan


def parse_plan(name, root_dir):
    path = os.path.join(root_dir, 'محتوى مكتمل', name + '.docx')
    if not os.path.exists(path):
        return None
    paras, tables, media, z = load(path)
    grade, kind = next(((g, k) for n, g, k in PLAN_ORDER if n == name), (None, None))
    plan = {'name': name, 'grade': grade, 'kind': kind}
    for rows in tables:
        for cells in rows:
            label, label_i = None, -1
            for i, c in enumerate(cells):
                if norm_label(c) in PLAN_LABELS:
                    label, label_i = PLAN_LABELS[norm_label(c)], i
                    break
            if not label:
                continue
            content = re.sub(r'\s+', ' ', ' '.join(
                c for i, c in enumerate(cells) if i != label_i and c)).strip()
            if not content:
                continue
            if label == 'specific':
                plan['specific'] = split_objectives(content) if re.search(r'\d\)', content) \
                    else [s.strip() for s in SENT.split(content) if len(s.strip()) > 8]
            elif label == 'tools':
                plan['tools'] = [x.strip() for x in re.split(r'[–-]', content) if x.strip()]
            elif label == 'title':
                plan['title'] = content
            else:
                plan[label] = content
    lines_used = _collapse([p['t'] for p in paras])
    if not plan.get('objectives') or not plan.get('intro'):
        for field, value in parse_plan_fallback(paras, plan).items():
            plan.setdefault(field, value)
    if len(plan.get('objectives') or '') < 12 or not plan.get('intro'):
        plan = parse_plan_degenerate(paras, plan, lines_used)
    if isinstance(plan.get('tools'), str):
        plan['tools'] = [x.strip() for x in re.split(r'\s*[–-]\s*', plan['tools'])
                         if x.strip()]
    if isinstance(plan.get('specific'), str):
        plan['specific'] = [s.strip() for s in SENT.split(plan['specific'])
                            if len(s.strip()) > 6]
    t = re.sub(r'^الموضوع\s*', '', plan.get('title', name))
    t = re.sub(r'\s*(الأول|الثاني|الثالث) المتوسط\s*', ' ', t)
    t = re.sub(r'\s+', ' ', t).strip()
    plan['title'] = t if 0 < len(t) <= 60 else name
    return plan


# ------------------------------------------------------------------- book
def parse_intro(root_dir):
    """The introduction document is hard-wrapped: sentences are broken across
    lines and lists are marked with Arabic numerals. Rebuild readable blocks."""
    path = os.path.join(root_dir, 'محتوى مكتمل', 'مقدمة.docx')
    paras, tables, media, z = load(path)
    lines = [p['t'] for p in paras]
    NUM = re.compile(r'^[\u0660-\u0669\d]+\s*[-.)]\s*')
    HEAD = re.compile(r'^(انواع طرائق التدريس|أنواع طرائق التدريس|'
                      r'الأهداف العامة لمادة التربية الفنية.*)$')

    intro = {'title': 'التربية الفنية — المقدمة', 'sections': [], 'maps': []}
    sec, buf = None, []

    def flush():
        if buf:
            text = re.sub(r'\s+', ' ', ' '.join(buf)).strip()
            if text:
                sec['paras'].append(text)
            buf.clear()

    def new_section(title):
        nonlocal sec
        if sec is not None:
            flush()
        sec = {'title': title, 'paras': []}
        intro['sections'].append(sec)

    DAY = {'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الاربعاء', 'الخميس', 'الجمعة'}
    skip = {'اليوم', 'الدرس الاول', 'الدرس الثاني', 'الدرس الثالث', 'الدرس الرابع',
            'الدرس الخامس', 'الدرس السادس', 'التربية الفنية', 'المقدمة'} | DAY
    for line in lines:
        if line in skip:
            continue
        if line == 'المرحلة المتوسطة' or re.match(r'^الصف (الأول|الثاني|الثالث)$', line):
            break                      # curriculum map follows, parsed below
        if HEAD.match(line):
            new_section(line.strip())
            continue
        if sec is None:
            new_section('المقدمة')
        if NUM.match(line):
            flush()
            buf.append(NUM.sub('', line))
        elif line.startswith(('أ -', 'ب -', 'ج -')):
            flush()
            buf.append(line)
        elif buf and len(line) < 40 and not buf[-1].rstrip().endswith(('.', '،', ':')):
            buf.append(line)          # continuation of a hard-wrapped line
        else:
            buf.append(line)
    flush()
    # drop the empty trailing section created by headings with no prose
    intro['sections'] = [x for x in intro['sections'] if x['paras']]

    # ---- curriculum map (الصف ← الوحدات ← الموضوعات)
    cur, grade, unit = None, None, None
    for line in lines:
        if line == 'المرحلة المتوسطة':
            grade, unit = None, None
            continue
        if re.match(r'^الصف (الأول|الثاني|الثالث)$', line):
            grade = line.replace('الصف ', '')
            cur = {'grade': grade, 'units': []}
            intro['maps'].append(cur)
            unit = None
            continue
        if cur is None:
            continue
        if line.startswith('الوحدة'):
            unit = {'name': re.sub(r'^الوحدة\s*', '', line).strip(' /'), 'items': []}
            cur['units'].append(unit)
            continue
        if unit is not None and NUM.match(line):
            unit['items'].append(NUM.sub('', line).strip())
    intro['maps'] = [m for m in intro['maps'] if m['units']]
    return intro


def parse_index(root_dir):
    paras, tables, media, z = load(os.path.join(root_dir, '00_فهرس_الموضوعات.docx'))
    rows = []
    for tbl in tables:
        for cells in tbl:
            if len(cells) >= 4 and re.match(r'^\d+$', cells[0].strip()):
                rows.append({'n': int(cells[0]), 'title': cells[1],
                             'grade': cells[2], 'pages': cells[3]})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=os.path.abspath(
        os.path.join(os.path.dirname(__file__), '..', '..')))
    args = ap.parse_args()
    root_dir = os.path.abspath(args.repo)

    global OUT_MEDIA
    out_www = os.path.join(root_dir, 'app', 'www')
    OUT_MEDIA = os.path.join(out_www, 'media')
    os.makedirs(OUT_MEDIA, exist_ok=True)

    data = {
        'meta': {
            'title': 'التربية الفنية — المرحلة المتوسطة',
            'subtitle': 'دليل المعلم والخطط الأسبوعية',
            'source': 'دليل معلم التربية الفنية للمرحلة المتوسطة',
            'version': '1.0.0',
        },
        'index': parse_index(root_dir),
        'intro': parse_intro(root_dir),
        'units': [parse_unit(p, root_dir) for p, *_ in DOC_ORDER],
        'plans': [x for x in (parse_plan(n, root_dir) for n, *_ in PLAN_ORDER) if x],
    }
    for u in data['units']:
        u.pop('body', None)
    out = os.path.join(out_www, 'js', 'data.js')
    with open(out, 'w', encoding='utf8') as f:
        f.write('window.REBO_CONTENT=' +
                json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ';\n')
    print('units=%d plans=%d index=%d -> %s (%.0f KB)' % (
        len(data['units']), len(data['plans']), len(data['index']),
        os.path.relpath(out, root_dir), os.path.getsize(out) / 1024))


if __name__ == '__main__':
    main()
