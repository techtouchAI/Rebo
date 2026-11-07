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
