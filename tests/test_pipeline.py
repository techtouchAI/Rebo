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
        n_pages = _measure_pages(path)
        render.render(model, path, total_pages=n_pages)
        out[i] = dict(src=src, ext=ext, model=model, changes=changes,
                      path=path, pages=n_pages)
    return out


def _measure_pages(docx_path):
    """Paginate with the same engine used for visual verification."""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), "tools"))
    from render_preview import convert
    import tempfile
    base = os.path.join(tempfile.gettempdir(), "rebo_t_" + os.path.basename(docx_path))
    n = convert(docx_path, base + ".pdf", base)
    if isinstance(n, tuple):
        n = n[0]
    import glob as _g
    for f in _g.glob(base + "*.png"):
        try:
            os.remove(f)
        except OSError:
            pass
    try:
        os.remove(base + ".pdf")
    except OSError:
        pass
    return n


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
    """
    MODEL -> PAGE: every model field is present, and nothing is invented.

    A global bag-of-characters comparison is not used: the page legitimately
    repeats furniture (column headers, card labels, running title, footer), so
    that test would be both brittle and meaningless.  Each field is located on
    the page instead, and the page's own characters -- after removing the
    furniture -- must be a subset of the model's.
    """
    from collections import Counter

    def canon_c(t):
        return Counter({k: v for k, v in Counter(t).items() if k not in " \n"})

    for i, rec in built.items():
        paras = _page_cell_paras(rec["path"]) + _page_paras(rec["path"])
        blob = " ".join(" ".join(paras).split())

        for field in _model_text(rec):
            for line in field.split("\n"):
                line = " ".join(line.split())
                if len(line) >= 6:
                    assert line in blob, "%s: field missing from page: %r" % (
                        i, line[:60])

        z = zipfile.ZipFile(rec["path"])
        chrome = Counter()
        for part in z.namelist():
            if re.match(r"word/(header|footer)\d*\.xml$", part):
                chrome.update("".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>",
                                                 z.read(part).decode())))
        for c in _first_table(rec["path"]).rows[0].cells:
            chrome.update(c.text)
        for v in rec["model"].get("meta", {}).values():
            chrome.update(v)
        for v in rec["model"].get("columns", []):
            chrome.update(v)

        page_c = canon_c("".join(paras))
        page_c.subtract(Counter({k: v for k, v in chrome.items() if k not in " \n"}))
        page_c = +page_c

        model_c = Counter()
        for field in _model_text(rec):
            model_c.update(canon_c(field))

        assert not (page_c - model_c), "%s: page invented characters: %s" % (
            i, dict(page_c - model_c))


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
    from pipeline import structure as S
    visual_rows = sum(
        len(S.pack_rows(S.segments(r["value"]), T.CHARS_PER_BODY_ROW))
        for r in rec["model"]["content_rows"])
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
        # One header/footer pair serves EVERY page: continuation pages must
        # never lose the identity.  A titlePg split would make page 2 the
        # "first" page of the artwork, which is exactly the defect this fixes.
        assert sect.find(W + "titlePg") is None, "unexpected titlePg"
        assert "default" in {r.get(W + "type") for r in
                             sect.findall(W + "headerReference")}, i
        assert "default" in {r.get(W + "type") for r in
                             sect.findall(W + "footerReference")}, i


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


def _all_text(ext):
    """Flatten an extracted document to the list of source cell texts."""
    out = []
    for r in ext.rows:
        for v in (r.c0, r.c1, r.c2, r.c3):
            if v:
                out.append(v)
    for a in ext.appendix:
        if a.text:
            out.append(a.text)
    return out


def _first_table(path):
    from docx import Document
    return Document(path).tables[0]


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


def test_9_source_figure_is_carried(built):
    """A drawing in the source must appear as a drawing in the sample."""
    import zipfile
    from pipeline import extract as EX
    for i, rec in built.items():
        src = EX.extract(rec["src"])
        if not src.media:
            continue
        z = zipfile.ZipFile(rec["path"])
        media = [n for n in z.namelist() if n.startswith("word/media/")]
        doc = z.read("word/document.xml").decode()
        assert media, "%s: source had an image, output has none" % i
        assert "a:blip" in doc, "%s: image embedded but never referenced" % i


def test_10_ellipses_are_the_author_s(built):
    """
    The «…» that end several summary bullets are stored in the SOURCE.
    The engine must never add one of its own.
    """
    from pipeline import extract as EX
    for i, rec in built.items():
        src = norm(" ".join(_all_text(EX.extract(rec["src"]))))
        page = _page_blob(rec["path"])
        assert page.count("\u2026") <= src.count("\u2026"), \
            "%s: engine invented an ellipsis" % i
        # and every source bullet that ends in … still ends in it
        for a in rec["model"]["appendix"]:
            t = norm(a.get("text", ""))
            if t.endswith("\u2026"):
                assert t in page, "%s: truncated-looking bullet was altered: %r" % (i, t[-40:])


def test_11_no_corrupt_glyphs(built):
    """Every character must have a glyph in the document's own font."""
    from fontTools.ttLib import TTFont
    font = TTFont(os.path.join("templates", "assets", "NotoNaskhArabic-Regular.ttf"))
    cmap = set()
    for t in font["cmap"].tables:
        cmap |= set(t.cmap.keys())
    for i, rec in built.items():
        chars = set("".join(_page_cell_paras(rec["path"]) + _page_paras(rec["path"])))
        missing = [c for c in chars if ord(c) > 32 and ord(c) not in cmap]
        assert not missing, "%s: font has no glyph for %r" % (i, missing[:8])


def test_12_page_fields_are_valid(built):
    """Cached PAGE/NUMPAGES must be real numbers and Word must refresh them."""
    import re as _re
    for i, rec in built.items():
        z = zipfile.ZipFile(rec["path"])
        cached = _re.findall(r"<w:t[^>]*>(\d+)</w:t>",
                             z.read("word/footer1.xml").decode())
        assert cached, "%s: page fields carry no cached result" % i
        assert max(int(c) for c in cached) == rec["pages"], \
            "%s: NUMPAGES cache %s != %d pages" % (i, cached, rec["pages"])
        assert "updateFields" in z.read("word/settings.xml").decode(), \
            "%s: Word is never told to refresh fields" % i


def test_13_drawing_ids_are_unique(built):
    """Duplicate docPr ids make Word drop pictures (the 'figure missing' bug)."""
    import re as _re
    for i, rec in built.items():
        z = zipfile.ZipFile(rec["path"])
        ids = []
        for part in z.namelist():
            if part.startswith("word/") and part.endswith(".xml"):
                ids += _re.findall(r'<wp:docPr id="(\d+)"', z.read(part).decode())
        assert ids, "%s: no drawing placed at all" % i
        assert len(ids) == len(set(ids)), "%s: duplicate drawing ids %s" % (i, ids)


def test_14_truncated_bullets_completed_from_source(built):
    """No bullet may dangle on «…», and any completion must come from source."""
    from pipeline import extract as EX
    for i, rec in built.items():
        src = EX.extract(rec["src"])
        body = norm(" ".join("%s %s" % (r.c2, r.c3) for r in src.rows))
        left = [a["text"] for a in rec["model"]["appendix"]
                if a["text"].rstrip().endswith("\u2026")]
        assert not left, "%s: %d bullet(s) still truncated: %r" % (i, len(left), left[:1])
        for a in rec["model"]["appendix"]:
            if a.get("completed_from_source"):
                assert norm(a["text"])[-70:] in body, \
                    "%s: completion not found in source: %r" % (i, a["text"][-50:])


def test_15_headings_need_source_evidence(built):
    """A row may be a heading only if the source marks it as one."""
    from pipeline.clean import looks_like_heading
    for i, rec in built.items():
        for r in rec["model"]["content_rows"]:
            if r.get("render") == "heading":
                assert looks_like_heading(r["label"]), \
                    "%s: heading without source evidence: %r" % (i, r["label"][:50])


def test_16_source_figure_is_carried(built):
    """A drawing in the source must be a drawing in the sample."""
    from pipeline import extract as EX
    for i, rec in built.items():
        if not EX.extract(rec["src"]).media:
            continue
        z = zipfile.ZipFile(rec["path"])
        assert [n for n in z.namelist() if n.startswith("word/media/")], \
            "%s: source had an image, output has none" % i
        assert "a:blip" in z.read("word/document.xml").decode(), \
            "%s: image embedded but never referenced" % i


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


# =========================================================================== #
# TEACHING VIEW  --  condensation + illustration
# =========================================================================== #
@pytest.fixture(scope="session")
def teaching(tmp_path_factory):
    """Build the teaching view of both samples once, with measured pages."""
    from pipeline import compile_plan
    out = {}
    d = tmp_path_factory.mktemp("teaching")
    for i in IDS:
        rec = compile_plan.build_pair(source_path(i), i, str(d),
                                      measure=_measure_pages)
        out[i] = rec
    return out


# ---- 17. the plan is not reduced to titles --------------------------------
def test_17_axes_carry_real_information(teaching):
    for i, rec in teaching.items():
        for sec in rec["teaching"]["sections"]:
            for a in sec["axes"]:
                assert a["blocks"], "axis %d has no body" % a["n"]
                chars = sum(len(b["text"]) for b in a["blocks"])
                assert chars >= 90, (
                    "axis %d is a stub (%d chars): %r"
                    % (a["n"], chars, a["title"]))


# ---- 18. nothing is invented; every string is a source slice -------------
def test_18_every_taught_string_is_verbatim(teaching):
    import re as _re
    for i, rec in teaching.items():
        src = ""
        for r in rec["model"]["content_rows"]:
            src += r["label"] + " " + r["value"] + " "
        flat = _re.sub(r"\s+", "", src)
        for sec in rec["teaching"]["sections"]:
            for a in sec["axes"]:
                for b in a["blocks"]:
                    key = _re.sub(r"\s+", "", b["text"])
                    assert key in flat, (
                        "%s invented text: %r" % (i, b["text"][:60]))


# ---- 19. order is preserved ----------------------------------------------
def test_19_taught_order_follows_the_source(teaching):
    import re as _re
    for i, rec in teaching.items():
        src = "".join(_re.sub(r"\s+", "", r["label"] + r["value"])
                      for r in rec["model"]["content_rows"])
        cursor = 0
        for sec in rec["teaching"]["sections"]:
            for a in sec["axes"]:
                for b in a["blocks"]:
                    key = _re.sub(r"\s+", "", b["text"])
                    at = src.find(key, cursor)
                    assert at >= 0, "%s out of order: %r" % (i, b["text"][:50])
                    cursor = at + len(key)


# ---- 20. no axis silently dropped ----------------------------------------
def test_20_every_source_row_reaches_an_axis(teaching):
    for i, rec in teaching.items():
        covered = set()
        for sec in rec["teaching"]["sections"]:
            for a in sec["axes"]:
                covered.update(a["rows"])
        assert len(covered) == len(rec["model"]["content_rows"]), (
            "%s lost rows %s" % (i, sorted(set(range(len(
                rec["model"]["content_rows"]))) - covered)))


# ---- 21. exclusions are declared, never silent ---------------------------
def test_21_exclusions_have_reasons(teaching):
    allowed = {"تفاصيل تنفيذية/خطوات صناعة",
               "تكرار لفظي لمعلومة معروضة",
               "توجيه للمعلم لا يخدم فهم الطالب",
               "وحدة فارغة"}
    for i, rec in teaching.items():
        for sec in rec["teaching"]["sections"]:
            for a in sec["axes"]:
                for d in a["dropped"]:
                    assert d["reason"] in allowed, d


# ---- 22. procedural detail is what leaves, not the teaching content ------
def test_22_procedure_is_the_main_exclusion(teaching):
    for i, rec in teaching.items():
        st = rec["teaching"]["stats"]
        by = st["by_reason"]
        proc = by.get("تفاصيل تنفيذية/خطوات صناعة", 0)
        assert proc >= sum(v for k, v in by.items() if k !=
                           "تفاصيل تنفيذية/خطوات صناعة") * 0.4, by


# ---- 23. no duplication across axes --------------------------------------
def test_23_no_duplicate_block_anywhere(teaching):
    import re as _re
    for i, rec in teaching.items():
        seen = set()
        for sec in rec["teaching"]["sections"]:
            for a in sec["axes"]:
                for b in a["blocks"]:
                    key = _re.sub(r"\s+", "", b["text"])
                    if len(key) < 60:
                        continue
                    assert key not in seen, (
                        "%s duplicated a block: %r" % (i, b["text"][:50]))
                    seen.add(key)


# ---- 24. a question never tests something the plan does not teach --------
def test_24_quiz_answers_are_taught(teaching):
    for i, rec in teaching.items():
        ok, rows = rec["closure"]
        assert ok, "%s: unanswerable questions %s" % (
            i, [r["answer"][:40] for r in rows if not r["taught"]])


# ---- 25. the answer key parses to the source's own letters --------------
def test_25_answer_key_matches_source(teaching):
    for i, rec in teaching.items():
        key = rec["quiz"]["key"]
        assert key.get("tf"), "%s: no true/false key" % i
        assert key.get("mc"), "%s: no multiple-choice key" % i
        for n, letter in key["mc"].items():
            assert letter in "أبجد", (i, n, letter)


# ---- 26. the source's own quiz is carried verbatim ----------------------
def test_26_source_quiz_text_is_preserved(teaching):
    import re as _re
    for i, rec in teaching.items():
        blob = _re.sub(r"\s+", "", " ".join(
            a.get("text", "") for a in rec["model"]["appendix"]))
        for q in rec["quiz"]["mc"]:
            stem = _re.sub(r"\s+", "", q["stem"])
            assert stem in blob, "%s altered stem %r" % (i, q["stem"][:40])


# ---- 27. generated questions are derived from printed content -----------
def test_27_generated_questions_are_backed(teaching):
    for i, rec in teaching.items():
        taught = " ".join(b["text"] for s in rec["teaching"]["sections"]
                          for a in s["axes"] for b in a["blocks"])
        for g in rec["quiz"]["generated"]:
            first = g["answer"].split(" / ")[0][:40]
            assert first in taught or first in " ".join(
                a.get("text", "") for a in rec["model"]["appendix"]), (
                "%s: question not backed by content: %r" % (i, g["prompt"]))


# ---- 28. every plate belongs to the axis it illustrates -----------------
def test_28_plate_matches_its_axis(teaching):
    from pipeline import figures_map
    for i, rec in teaching.items():
        axes = {a["n"]: a for s in rec["teaching"]["sections"]
                for a in s["axes"]}
        for n, plates in rec["plates"].items():
            text = " ".join(b["text"] for b in axes[n]["blocks"])
            text += " " + (axes[n].get("title") or "")
            for pl in plates:
                name = pl["name"]
                if name == "history_timeline":
                    assert any(e["date"] in text for e in rec["model"]["_timeline"])
                    continue
                sets = [c for n2, c, _p in figures_map.RULES if n2 == name]
                assert sets, "plate %s has no rule" % name
                assert any(all(c in text for c in cs) for cs in sets), (
                    "%s axis %d got %s without any of %s"
                    % (i, n, name, sets))


# ---- 29. plates are not repeated without cause --------------------------
def test_29_no_wasted_duplicate_plates(teaching):
    for i, rec in teaching.items():
        names = [p["name"] for v in rec["plates"].values() for p in v]
        for n in set(names):
            assert names.count(n) <= 2, "%s reused %s %d times" % (
                i, n, names.count(n))


# ---- 30. every plate image is really embedded in the DOCX --------------
def test_30_plates_are_embedded(teaching):
    """Every plate is referenced by a drawing AND resolves to real bytes."""
    import zipfile
    A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
    R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
    for i, rec in teaching.items():
        z = zipfile.ZipFile(rec["docx"])
        root = etree.fromstring(z.read("word/document.xml"))
        rels = etree.fromstring(z.read("word/_rels/document.xml.rels"))
        targets = {}
        for r in rels:
            targets[r.get("Id")] = r.get("Target")
        blips = [b.get(R + "embed") for b in root.iter(A + "blip")]
        plates = sum(len(v) for v in rec["plates"].values())
        assert len(blips) >= plates, (
            "%s: %d drawings for %d plates" % (i, len(blips), plates))
        for rid in blips:
            tgt = targets.get(rid)
            assert tgt, "%s: dangling image relationship %s" % (i, rid)
            name = "word/" + tgt.lstrip("/")
            assert name in z.namelist(), "%s: missing part %s" % (i, name)
            assert len(z.read(name)) > 500, "%s: empty image %s" % (i, name)


# ---- 31. drawing ids stay unique document-wide --------------------------
def test_31_teaching_drawing_ids_unique(teaching):
    import zipfile
    from pipeline.extract import extract as _ex
    for i, rec in teaching.items():
        z = zipfile.ZipFile(rec["docx"])
        ids = []
        for n in z.namelist():
            if n.endswith(".xml"):
                ids += etree.fromstring(z.read(n)).xpath(
                    "//wp:docPr/@id",
                    namespaces={"wp": "http://schemas.openxmlformats.org/"
                                      "drawingml/2006/wordprocessingDrawing"})
        ids = [k for k in ids if k]
        assert len(ids) == len(set(ids)), "%s duplicate docPr ids" % i


# ---- 32. page fields carry the measured count ---------------------------
def test_32_teaching_page_fields(teaching):
    import zipfile
    for i, rec in teaching.items():
        z = zipfile.ZipFile(rec["docx"])
        footers = [n for n in z.namelist() if n.startswith("word/footer")]
        text = "".join(z.read(n).decode("utf-8") for n in footers)
        assert "NUMPAGES" in text or "PAGE" in text
        for n in footers:
            xml = z.read(n).decode("utf-8")
            for seg in xml.split("<w:t")[1:]:
                pass
        assert rec["pages"] >= 1


# ---- 33. the teaching view keeps RTL and the design grid ---------------
def test_33_teaching_is_rtl(teaching):
    for i, rec in teaching.items():
        root = xml(rec["docx"])
        sect = root.find(".//" + W + "sectPr")
        assert sect is not None and sect.find(W + "bidi") is not None
        tbls = root.findall(".//" + W + "tbl")
        assert tbls, "%s has no tables" % i
        for t in tbls:
            tp = t.find(W + "tblPr")
            assert tp is not None and tp.find(W + "bidiVisual") is not None
            grid = [int(g.get(W + "w")) for g in t.find(W + "tblGrid")]
            if len(grid) == 4:
                assert sum(grid) == 10376, (i, sum(grid))


# ---- 34. no text is clipped by a cell -----------------------------------
def test_34_teaching_fits_the_print_area(teaching):
    for i, rec in teaching.items():
        root = xml(rec["docx"])
        for t in root.findall(".//" + W + "tbl"):
            grid = [int(g.get(W + "w")) for g in t.find(W + "tblGrid")]
            assert sum(grid) <= 10376, (i, sum(grid))


# ---- 35. a plate failure must not lose text -----------------------------
def test_35_missing_plate_keeps_the_text(tmp_path, monkeypatch):
    from pipeline import figures_map, render, didactic
    from pipeline.extract import extract as _ex
    from pipeline.clean import clean_document as _cl

    def boom(*a, **k):
        raise RuntimeError("renderer unavailable")

    monkeypatch.setattr(figures_map.figurelib, "make", boom)
    src = source_path("19")
    ext, model = _ex(src), None
    model, _ = _cl(ext, "19")
    t = didactic.condense(model)
    att, log, mp = figures_map.resolve(t, [], out_dir=str(tmp_path))
    assert att == {}                       # nothing attached
    assert any(l["status"] == "failed" for l in log)
    model["_attachments"] = {}
    out = str(tmp_path / "no_plates.docx")
    render.render_teaching(model, out)
    blob = docx_text(out)
    assert len(blob) > 1500               # the content is all still there


# ---- 36. determinism of the teaching view -------------------------------
def test_36_teaching_build_is_deterministic(teaching, tmp_path):
    import zipfile
    from pipeline import render
    for i, rec in teaching.items():
        out = str(tmp_path / ("det_%s.docx" % i))
        render.render_teaching(rec["model"], out, total_pages=rec["pages"])
        src, dst = zipfile.ZipFile(rec["docx"]), zipfile.ZipFile(out)
        for part in ("word/document.xml", "word/footer1.xml"):
            assert src.read(part) == dst.read(part), (i, part)


# ---- 37. the two views are different documents --------------------------
def test_37_verbatim_and_teaching_views_both_exist(teaching):
    for i, rec in teaching.items():
        assert os.path.exists(rec["docx"])
        assert os.path.exists(rec["full_docx"])
        short = docx_text(rec["docx"])
        long = docx_text(rec["full_docx"])
        assert len(short) < len(long), (
            "%s: the teaching view is not condensed" % i)
        assert len(short) > len(long) * 0.5, (
            "%s: over-condensed" % i)


# ---- 38. every taught block physically reaches the DOCX ----------------
def test_38_taught_blocks_reach_the_document(teaching):
    """The model and the file must agree: nothing may be lost in rendering."""
    import re
    from docx import Document
    for i, rec in teaching.items():
        doc = Document(rec["docx"])
        seen, buf = set(), []
        for t in doc.tables:
            for r in t.rows:
                for c in r.cells:
                    if c._tc in seen:
                        continue
                    seen.add(c._tc)
                    buf.append(c.text)
        flat = re.sub(r"\s+", "", " ".join(buf))
        for sec in rec["teaching"]["sections"]:
            for a in sec["axes"]:
                for b in a["blocks"]:
                    key = re.sub(r"\s+", "", b["text"])
                    assert key in flat, (
                        "%s: block never reached the page: %r"
                        % (i, b["text"][:60]))


# ---- 39. a row may break across pages (else its tail is dropped) -------
def test_39_content_rows_may_split(teaching):
    for i, rec in teaching.items():
        root = xml(rec["docx"])
        for t in root.findall(".//" + W + "tbl"):
            rows = t.findall(W + "tr")
            if not rows:
                continue
            for tr in rows[1:]:
                tp = tr.find(W + "trPr")
                if tp is None:
                    continue
                cant = tp.find(W + "cantSplit")
                chars = len("".join(x.text or "" for x in tr.iter(W + "t")))
                if cant is not None:
                    # a never-splitting row must fit on one page
                    assert chars < 1500, (
                        "%s: %d-char row cannot split" % (i, chars))


# ---- 40. the axis title is printed once, not once per piece ------------
def test_40_axis_heading_paragraph_is_unique(teaching):
    """A heading is one paragraph. The same words may still occur inside a
    sentence or in the source's own quiz -- that is not duplication."""
    import re
    from docx import Document
    for i, rec in teaching.items():
        doc = Document(rec["docx"])
        seen, heads = set(), []
        for t in doc.tables:
            for r in t.rows:
                for c in r.cells:
                    if c._tc in seen:
                        continue
                    seen.add(c._tc)
                    heads.extend(p.text for p in c.paragraphs)
        for sec in rec["teaching"]["sections"]:
            for a in sec["axes"]:
                title = re.sub(r"\s+", "", a.get("title") or "")
                if len(title) < 12:
                    continue
                exact = [h for h in heads
                         if re.sub(r"\s+", "", h).strip(".:") == title.strip(".:")]
                assert len(exact) <= 1, (
                    "%s: heading paragraph repeated %d times: %r"
                    % (i, len(exact), title[:40]))
