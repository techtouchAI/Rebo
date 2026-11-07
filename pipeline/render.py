"""
Stage 4/5 -- LAYOUT ENGINE + DOCX EXPORT.

Visual reference: تصميم الخطة.jpg

  +-------------------------------------------------------------+
  | [banner artwork: brushes, palette, title ribbon]            |  first page only
  | ( معلومات )( الصف )( الدرس )                                 |  meta cards
  | +----------+---------+---------+---------------------------+ |
  | |  الدرس   | معلومات | الموضوع |  محتوى البند  (53.5%)      | |  table header
  | +----------+---------+---------+---------------------------+ |
  | | merged   | merged  | label   | value                     | |  3 ruled rows
  | | (white)  | gradient| column  | column                    | |  then as many as
  | +----------+---------+---------+---------------------------+ |  the content needs
  | [wave + paint pots]  +  التربية الفنية • صفحة X من Y        |  footer
  +-------------------------------------------------------------+

Column index order below is the LOGICAL order; `w:bidiVisual` puts index 0 at the
physical RIGHT edge, which reproduces the artwork exactly.
"""
from __future__ import annotations

import os

from docx import Document
from docx.shared import Inches
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

from . import design_tokens as T
from . import ooxml as X

ASSET_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                         "templates", "assets")


# --------------------------------------------------------------------------- #
def setup_section(doc):
    s = doc.sections[0]
    s.page_width = Inches(T.PAGE_W_TWIPS / 1440)
    s.page_height = Inches(T.PAGE_H_TWIPS / 1440)
    s.top_margin = Inches(T.MARGIN_TOP_TWIPS / 1440)
    s.bottom_margin = Inches(T.MARGIN_BOTTOM_TWIPS / 1440)
    s.left_margin = Inches(T.MARGIN_LEFT_TWIPS / 1440)
    s.right_margin = Inches(T.MARGIN_RIGHT_TWIPS / 1440)
    s.header_distance = Inches(T.HEADER_DIST_TWIPS / 1440)
    s.footer_distance = Inches(T.FOOTER_DIST_TWIPS / 1440)
    sectPr = s._sectPr
    if sectPr.find(qn("w:bidi")) is None:
        sectPr.append(X.el("w:bidi", val="1"))
    return s


def _rtl_defaults(doc):
    styles = doc.styles.element
    dd = styles.find(qn("w:docDefaults"))
    if dd is None:
        dd = OxmlElement("w:docDefaults")
        styles.insert(0, dd)
    ppd = dd.find(qn("w:pPrDefault"))
    if ppd is None:
        ppd = OxmlElement("w:pPrDefault")
        dd.append(ppd)
    pPr = ppd.find(qn("w:pPr"))
    if pPr is None:
        pPr = OxmlElement("w:pPr")
        ppd.append(pPr)
    if pPr.find(qn("w:bidi")) is None:
        pPr.insert(0, X.el("w:bidi", val="1"))
    rpd = dd.find(qn("w:rPrDefault"))
    if rpd is None:
        rpd = OxmlElement("w:rPrDefault")
        dd.append(rpd)
    rPr = rpd.find(qn("w:rPr"))
    if rPr is None:
        rPr = OxmlElement("w:rPr")
        rpd.append(rPr)
    if rPr.find(qn("w:rtl")) is None:
        rPr.append(X.el("w:rtl", val="1"))


def _pic_para(container, png, width_in):
    p = container.add_paragraph()
    X.para_props(p, rtl=True, align="center", space_before=0, space_after=0, line=240)
    p.add_run().add_picture(png, width=Inches(width_in))
    return p


# --------------------------------------------------------------------------- #
def build_headers(section, model):
    """
    First page  : full banner artwork (holds the constant title).
    Later pages : slim navy running bar.
    A full-page-height banner on every page would consume 84% of the writing area,
    so the design's header treatment is applied to page 1 and reduced thereafter.
    """
    section.different_first_page_header_footer = True
    banner = os.path.join(ASSET_DIR, "banner.png")
    text_w = T.TEXT_W_TWIPS / 1440

    hdr = section.header
    hdr.is_linked_to_previous = False
    for p in list(hdr.paragraphs):
        p._p.getparent().remove(p._p)
    _pic_para(hdr, banner, text_w)
    # pages 2+ must not print the banner again
    for p in hdr.paragraphs:
        for r in p.runs:
            pass
    # hide the banner on continuation pages by putting it in the first-page header
    # and leaving the default header with the running bar only
    for p in list(hdr.paragraphs):
        p._p.getparent().remove(p._p)
    bar = hdr.add_table(rows=1, cols=1, width=Inches(text_w))
    X.tbl_pr_ordered(bar, T.TEXT_W_TWIPS)
    bar.autofit = False
    X.table_set_grid(bar, [T.TEXT_W_TWIPS])
    cell = bar.rows[0].cells[0]
    cell_shade(cell, T.C_BANNER_NAVY)
    _cell_frame(cell, pad=40)
    par = cell.paragraphs[0]
    X.para_props(par, rtl=True, align="center", space_before=20, space_after=20, line=240)
    X.add_text_run(par, T.TITLE_TEXT, font=T.FONT_HEADING, size=T.SZ_RUNNING,
                   bold=True, color="FFFFFF")

    fp = section.first_page_header
    fp.is_linked_to_previous = False
    for q in list(fp.paragraphs):
        q._p.getparent().remove(q._p)
    _pic_para(fp, banner, text_w)


def build_footers(section, model):
    section.different_first_page_header_footer = True
    wave = os.path.join(ASSET_DIR, "footer_wave.png")
    text_w = T.TEXT_W_TWIPS / 1440

    ftr = section.footer
    ftr.is_linked_to_previous = False
    for p in list(ftr.paragraphs):
        p._p.getparent().remove(p._p)
    _rule_para(ftr)
    _page_line(ftr)

    ff = section.first_page_footer
    ff.is_linked_to_previous = False
    for q in list(ff.paragraphs):
        q._p.getparent().remove(q._p)
    _pic_para(ff, wave, text_w)
    _page_line(ff)


def _rule_para(container):
    p = container.add_paragraph()
    X.para_props(p, rtl=True, align="center", space_before=0, space_after=0, line=240)
    pPr = p._p.find(qn("w:pPr"))
    bdr = OxmlElement("w:pBdr")
    bdr.append(X.el("w:bottom", val="single", sz="8", space="1", color=T.C_RULE))
    pPr.append(bdr)
    return p


def _page_line(container):
    """«التربية الفنية  •  صفحة X من Y» with real PAGE/NUMPAGES fields."""
    p = container.add_paragraph()
    X.para_props(p, rtl=True, align="center", space_before=20, space_after=0, line=240)

    def field(instr):
        r = OxmlElement("w:r")
        f1 = OxmlElement("w:fldChar"); f1.set(qn("w:fldCharType"), "begin")
        it = OxmlElement("w:instrText"); it.set(qn("xml:space"), "preserve"); it.text = instr
        f2 = OxmlElement("w:fldChar"); f2.set(qn("w:fldCharType"), "separate")
        t = OxmlElement("w:t"); t.text = "1"
        f3 = OxmlElement("w:fldChar"); f3.set(qn("w:fldCharType"), "end")
        for e in (f1, it, f2, t, f3):
            r.append(e)
        p._p.append(r)

    X.add_text_run(p, T.FOOTER_PREFIX + "  •  صفحة ", font=T.FONT_BODY,
                   size=T.SZ_FOOTER, color=T.C_RULE)
    field(" PAGE ")
    X.add_text_run(p, " من ", font=T.FONT_BODY, size=T.SZ_FOOTER, color=T.C_RULE)
    field(" NUMPAGES ")


def cell_shade(cell, fill):
    X.cell_shade(cell, fill)


def _cell_frame(cell, pad=57, color=None, sz="12"):
    X.cell_borders(cell, top=(sz, color or T.C_RULE), bottom=(sz, color or T.C_RULE),
                   left=(sz, color or T.C_RULE), right=(sz, color or T.C_RULE))
    X.cell_margins(cell, pad, 85, pad, 85)


# --------------------------------------------------------------------------- #
def build_meta_cards(doc, model):
    """( معلومات )( الصف )( الدرس ) -- RTL: index 0 renders on the right."""
    lab = [model.get("meta", {}).get("label_%d" % i, "") for i in range(3)]
    tbl = doc.add_table(rows=1, cols=3)
    X.tbl_pr_ordered(tbl, T.TEXT_W_TWIPS)
    tbl.autofit = False
    w = [int(T.TEXT_W_TWIPS * 0.28), int(T.TEXT_W_TWIPS * 0.17)]
    w.append(T.TEXT_W_TWIPS - sum(w))
    X.table_set_grid(tbl, w)

    for i, cell in enumerate(tbl.rows[0].cells):
        X.cell_shade(cell, T.C_META_FILL)
        X.cell_valign(cell, "center")
        _cell_frame(cell, pad=45)
        p = cell.paragraphs[0]
        X.para_props(p, rtl=True, align="center", space_before=45, space_after=45, line=250)
        X.add_text_run(p, lab[i], font=T.FONT_HEADING, size=T.SZ_META,
                       bold=True, color=T.C_HEAD_TEXT)
    return tbl


# --------------------------------------------------------------------------- #
def split_for_layout(text, limit=None):
    """
    Partition a long cell value into consecutive chunks that each fit a row.

    This is a pure partition: "".join(result) == text, so no character is
    added, removed or reordered. Chunk boundaries prefer an existing newline,
    then an existing bullet, then a sentence end, then a space.
    """
    limit = limit or T.CHARS_PER_BODY_ROW
    text = text or ""
    if len(text) <= limit:
        return [text]
    out, rest = [], text
    while len(rest) > limit:
        window = rest[:limit]
        cut = -1
        for sep in ("\n", "•", ". ", "، ", " "):
            cut = window.rfind(sep)
            if cut > limit * 0.45:
                cut += len(sep) if sep != " " else 1
                break
        if cut <= limit * 0.45:
            cut = limit
        out.append(rest[:cut])
        rest = rest[cut:]
    if rest:
        out.append(rest)
    assert "".join(out) == text, "partition changed the text"
    return out


def build_plan_table(doc, model, page_num):
    rows = []
    for r in model["content_rows"]:
        chunks = split_for_layout(r["value"])
        for k, chunk in enumerate(chunks):
            rows.append({
                "label": r["label"] if k == 0 else "",
                "value": chunk,
                "render": r.get("render", "heading") if k == 0 else "heading",
                "continued": k > 0,
            })
    nav = [r for r in model["nav_rows"] if r["type"] == "nav"]
    cards = {r["type"]: r["value"] for r in model["nav_rows"]
             if r["type"] in ("guide_pages", "lesson_identity")}

    n = 1 + len(nav) + len(rows)
    tbl = doc.add_table(rows=n, cols=4)
    X.tbl_pr_ordered(tbl, T.TEXT_W_TWIPS)
    tbl.autofit = False
    widths = T.col_widths()
    X.table_set_grid(tbl, widths)

    # ---- header row -------------------------------------------------------
    hdr = tbl.rows[0]
    X.row_props(hdr, height=T.ROW_MIN_H_TWIPS, header=True, cant_split=True)
    for i, cell in enumerate(hdr.cells):
        X.cell_shade(cell, T.C_HEAD_FILL)
        X.cell_valign(cell, "center")
        _cell_frame(cell, pad=57, sz="16")
        p = cell.paragraphs[0]
        X.para_props(p, rtl=True, align="center", space_before=20, space_after=20, line=250)
        X.add_text_run(p, T.COL_TITLES[i], font=T.FONT_HEADING,
                       size=T.SZ_HEADER, bold=True, color=T.C_HEAD_TEXT)

    # ---- body -------------------------------------------------------------
    ri = 1
    for item in nav:
        row = tbl.rows[ri]
        X.row_props(row, height=T.ROW_MIN_H_TWIPS, cant_split=True)
        _fill_row(row, n, ri, label=item["label"], value=item["value"], kind="nav")
        ri += 1
    for item in rows:
        row = tbl.rows[ri]
        X.row_props(row, height=T.ROW_MIN_H_TWIPS, cant_split=False)
        _fill_row(row, n, ri, label=item["label"], value=item["value"],
                  kind=item.get("render", "heading"))
        ri += 1

    # ---- merged right-hand cards -----------------------------------------
    # The source packs the lesson title AND the guide page range into ONE cell
    # (row 2, c3).  The artwork has two cards, so the cell's own lines are
    # distributed across them.  Every line is emitted verbatim -- this is a
    # placement change, not a text change.
    lesson_txt, info_txt = _split_identity(cards)
    _merge_column(tbl, 0, lesson_txt)
    _merge_column(tbl, 1, info_txt)
    return tbl


def _split_identity(cards):
    lesson = cards.get("lesson_identity", "")
    pages = cards.get("guide_pages", "")
    if lesson:
        return lesson, pages
    lines = [ln.strip() for ln in str(pages).split("\n") if ln.strip()]
    if len(lines) >= 2:
        head = [ln for ln in lines if not ln.startswith("الصفحات")]
        tail = [ln for ln in lines if ln.startswith("الصفحات")]
        if head and tail:
            return "\n".join(head), "\n".join(tail)
    return "", pages


def _merge_column(tbl, ci, text):
    top = tbl.rows[1].cells[ci]
    X.cell_vmerge(top, restart=True)
    for rr in tbl.rows[2:]:
        X.cell_vmerge(rr.cells[ci], restart=False)
    X.cell_valign(top, "top")
    X.cell_margins(top, 120, 85, 120, 85)
    X.cell_shade(top, T.C_CELL if ci == 0 else T.C_LABEL_FILL)
    first = True
    if text:
        for chunk in str(text).split("\n"):
            if not chunk.strip():
                continue
            p = top.paragraphs[0] if first else top.add_paragraph()
            first = False
            X.para_props(p, rtl=True, align="center", space_before=0,
                         space_after=60, line=260)
            X.add_text_run(p, chunk.strip(), font=T.FONT_BODY,
                           size=T.SZ_BODY, color=T.C_TEXT)
    if first:
        X.para_props(top.paragraphs[0], rtl=True, align="center",
                     space_before=0, space_after=0, line=240)


def _fill_row(row, total, ri, *, label, value, kind):
    cells = row.cells
    # logical 0 = rightmost card, 1 = second card, 2 = الموضوع, 3 = content
    content, lab = cells[3], cells[2]
    X.cell_margins(content, 57, 85, 57, 85)
    X.cell_margins(lab, 57, 60, 57, 60)
    X.cell_valign(content, "top")
    X.cell_valign(lab, "center")
    X.cell_shade(content, T.C_CELL)
    X.cell_shade(lab, T.C_LABEL_FILL)

    if kind == "nav":
        blocks = [(value or label, "p")]
        lab_blocks = [(label, "h")]
    elif kind == "fragment":
        # The source split a sentence across the two cells.  Rejoin it in the
        # content column and leave the label column empty -- echoing the label in
        # both places would duplicate the opening words (it would also break the
        # character audit, which is what caught it).
        blocks = [((label + " " + value).strip(), "p")]
        lab_blocks = []
    else:
        blocks = []
        if label:
            blocks.append((label, "h"))
        if value:
            blocks.append((value, "p"))
        # short labels also identify the row in the الموضوع column
        lab_blocks = [((label if len(label) <= 34 else ""), "h")]
    _write(blocks, content)
    _write(lab_blocks, lab, align="center")

    X.cell_gradient(cells[1], ri, total, T.C_TALL1_TOP, T.C_TALL1_BOT)
    X.cell_shade(cells[0], T.C_CELL)
    for c in cells:
        X.cell_borders(c, top=("4", T.C_RULE), bottom=("4", T.C_RULE),
                       left=("12", T.C_RULE), right=("12", T.C_RULE))


def _write(blocks, cell, align="both"):
    first = True
    for item in blocks:
        if not item:
            continue
        text, kind = item
        if not text:
            continue
        p = cell.paragraphs[0] if first else cell.add_paragraph()
        first = False
        head = kind == "h"
        X.para_props(p, rtl=True, align=("center" if align == "center" else
                                         ("right" if head else "both")),
                     space_before=0, space_after=(40 if head else 60),
                     line=(260 if head else 290))
        X.add_text_run(p, text,
                       font=T.FONT_HEADING if head else T.FONT_BODY,
                       size=(T.SZ_LABEL + 1 if head else T.SZ_BODY),
                       bold=head, color=T.C_HEAD_TEXT if head else T.C_TEXT)
    if first:
        X.para_props(cell.paragraphs[0], rtl=True, align="center",
                     space_before=0, space_after=0, line=240)


# --------------------------------------------------------------------------- #
def build_appendix(doc, model):
    items = [a for a in model["appendix"] if a.get("text")]
    if not items:
        return
    sep = doc.add_paragraph()
    X.para_props(sep, rtl=True, align="center", space_before=0, space_after=0, line=240)
    # the خلاصة/أسئلة block starts a fresh page so it never fights the plan table
    pPr = sep._p.find(qn("w:pPr"))
    pPr.append(X.el("w:pageBreakBefore", val="1"))

    for i, a in enumerate(items):
        text = a["text"]
        head = (i == 0 or text.startswith(("أولاً", "ثانياً", "ثالثاً",
                                           "مفتاح الإجابة", "لوحة توضيحية",
                                           "المصدر")))
        p = doc.add_paragraph()
        X.para_props(p, rtl=True, align="right" if head else "both",
                     space_before=(160 if head else 0), space_after=40, line=280)
        X.add_text_run(p, text, font=T.FONT_HEADING if head else T.FONT_BODY,
                       size=(T.SZ_APPX_H if head else T.SZ_BODY),
                       bold=head, color=(T.C_ACCENT_BLUE if head else T.C_TEXT))


# --------------------------------------------------------------------------- #
def render(model, out_path):
    doc = Document()
    _rtl_defaults(doc)
    section = setup_section(doc)

    body = doc.element.body
    for p in list(body.findall(qn("w:p"))):
        body.remove(p)

    build_headers(section, model)
    build_footers(section, model)
    build_meta_cards(doc, model)
    build_plan_table(doc, model, 1)
    build_appendix(doc, model)

    spacer = doc.add_paragraph()
    X.para_props(spacer, rtl=True, align="center", space_before=0, space_after=0, line=240)

    cp = doc.core_properties
    cp.title = model.get("title", "")
    cp.subject = model.get("subject", "التربية الفنية")
    cp.author = "techtouchAI / Rebo pipeline"
    cp.comments = "Generated deterministically from %s" % os.path.basename(model.get("source", ""))
    doc.save(out_path)
    return out_path
