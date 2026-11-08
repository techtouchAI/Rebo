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
import tempfile

from docx import Document
from docx.shared import Inches
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

from . import design_tokens as T
from . import ooxml as X
from . import structure as S

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


_DRAW_ID = [1000]


def _next_id():
    _DRAW_ID[0] += 1
    return _DRAW_ID[0]


def _reid(container):
    """
    Give every drawing in this part a unique docPr id.

    python-docx restarts ids at 1 in every part, but Word requires them to be
    unique document-wide; duplicates make pictures silently disappear -- the
    «figure does not appear» bug.
    """
    for pr in container._element.iter(qn("wp:docPr")):
        pr.set("id", str(_next_id()))


def _pic_para(container, png, width_in, max_h=None):
    """Place artwork at the text width, optionally capped in height."""
    p = container.add_paragraph()
    X.para_props(p, rtl=True, align="center", space_before=0, space_after=0, line=240)
    run = p.add_run()
    if max_h:
        run.add_picture(png, width=Inches(width_in),
                        height=Inches(min(max_h / 1440.0,
                                          width_in * 1.0)))
    else:
        run.add_picture(png, width=Inches(width_in))
    _reid(container)
    return p


# --------------------------------------------------------------------------- #
def build_headers(section, model):
    """
    One visual identity on EVERY page.

    Page 1        : full banner artwork (it already carries the title).
    Pages 2+      : a slimmer crop of the SAME artwork.  Losing the illustration
                    entirely would turn continuation pages into blank sheets with
                    a grey rule, which is exactly the defect this replaces.  The
                    slim band costs ~11mm, not the 25mm of the full banner.
    """
    section.different_first_page_header_footer = True
    text_w = T.TEXT_W_TWIPS / 1440

    hdr = section.header
    hdr.is_linked_to_previous = False
    for p in list(hdr.paragraphs):
        p._p.getparent().remove(p._p)
    _pic_para(hdr, os.path.join(ASSET_DIR, "banner_slim.png"), text_w)

    fp = section.first_page_header
    fp.is_linked_to_previous = False
    for q in list(fp.paragraphs):
        q._p.getparent().remove(q._p)
    _pic_para(fp, os.path.join(ASSET_DIR, "banner.png"), text_w)


def build_footers(section, model):
    """
    The wave footer sits on every page, page 1 included, so the frame closes
    consistently.  The page number line rides underneath it.
    """
    section.different_first_page_header_footer = True
    text_w = T.TEXT_W_TWIPS / 1440
    wave = os.path.join(ASSET_DIR, "footer_wave.png")

    ftr = section.footer
    ftr.is_linked_to_previous = False
    for p in list(ftr.paragraphs):
        p._p.getparent().remove(p._p)
    _pic_para(ftr, wave, text_w, max_h=T.FOOTER_MAX_H_TWIPS)
    _page_line(ftr, 1, getattr(section, "_rebo_pages", None))

    ff = section.first_page_footer
    ff.is_linked_to_previous = False
    for q in list(ff.paragraphs):
        q._p.getparent().remove(q._p)
    _pic_para(ff, wave, text_w, max_h=T.FOOTER_MAX_H_TWIPS)
    _page_line(ff, 1, getattr(section, "_rebo_pages", None))


def _rule_para(container):
    p = container.add_paragraph()
    X.para_props(p, rtl=True, align="center", space_before=0, space_after=0, line=240)
    pPr = p._p.find(qn("w:pPr"))
    bdr = OxmlElement("w:pBdr")
    bdr.append(X.el("w:bottom", val="single", sz="8", space="1", color=T.C_RULE))
    pPr.append(bdr)
    return p


def _page_line(container, page_no=None, total=None):
    """
    «التربية الفنية  •  صفحة X من Y» with real PAGE/NUMPAGES fields.

    A field's cached result is what Word shows until it recalculates.  Writing
    "1" for every page showed a stale number, and a field Word cannot evaluate
    is what renders as its error glyphs (the "XX" reported in review).  The
    cache therefore holds the real value, and settings.xml asks Word to refresh
    fields on open.
    """
    p = container.add_paragraph()
    X.para_props(p, rtl=True, align="center", space_before=20, space_after=0, line=240)

    def field(instr, cached):
        r = OxmlElement("w:r")
        rPr = OxmlElement("w:rPr")
        X.make_run_props(rPr, font=T.FONT_BODY, size=T.SZ_FOOTER, color=T.C_RULE)
        r.append(rPr)
        f1 = OxmlElement("w:fldChar"); f1.set(qn("w:fldCharType"), "begin")
        it = OxmlElement("w:instrText"); it.set(qn("xml:space"), "preserve"); it.text = instr
        f2 = OxmlElement("w:fldChar"); f2.set(qn("w:fldCharType"), "separate")
        t = OxmlElement("w:t"); t.text = str(cached)
        f3 = OxmlElement("w:fldChar"); f3.set(qn("w:fldCharType"), "end")
        for e in (f1, it, f2, t, f3):
            r.append(e)
        p._p.append(r)

    X.add_text_run(p, T.FOOTER_PREFIX + "  •  صفحة ", font=T.FONT_BODY,
                   size=T.SZ_FOOTER, color=T.C_RULE)
    field(" PAGE ", page_no if page_no else 1)
    X.add_text_run(p, " من ", font=T.FONT_BODY, size=T.SZ_FOOTER, color=T.C_RULE)
    field(" NUMPAGES ", total if total else 1)


def enable_field_update(doc):
    """Tell Word to recalculate fields when the file is opened."""
    settings = doc.settings.element
    if settings.find(qn("w:updateFields")) is None:
        uf = OxmlElement("w:updateFields")
        uf.set(qn("w:val"), "true")
        settings.append(uf)


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
def split_for_layout(text, limit=None):  # kept for callers/tests
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
        segs = S.segments(r["value"])
        for k, packed in enumerate(S.pack_rows(segs, T.CHARS_PER_BODY_ROW)):
            rows.append({
                "label": r["label"] if k == 0 else "",
                "paras": packed,
                "render": r.get("render", "heading"),
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
        _fill_row(row, n, ri, label=item["label"], paras=[item["value"]], kind="nav")
        ri += 1
    for item in rows:
        row = tbl.rows[ri]
        X.row_props(row, height=T.ROW_MIN_H_TWIPS, cant_split=False)
        _fill_row(row, n, ri, label=item["label"], paras=item["paras"],
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


def _fill_row(row, total, ri, *, label, paras, kind):
    """
    Fill one table row.

    The label is printed exactly ONCE.  Which column holds it depends on the
    source's own structure:
      * nav rows    -> short label in الموضوع, prose in the content column
      * fragment    -> the source cut one sentence across the two cells, so it
                       is rejoined in the content column and الموضوع stays empty
      * heading     -> the label is the row's title, so it heads the content
                       column and الموضوع stays empty (as in the design mock)
    """
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
        blocks = [("\n".join(paras) or label, "p")]
        lab_blocks = [(label, "h")]
    elif kind == "fragment":
        # The source split a sentence across the two cells.  Rejoin it in the
        # content column and leave the label column empty -- echoing the label in
        # both places would duplicate the opening words (it would also break the
        # character audit, which is what caught it).
        blocks = [((label + " " + "\n".join(paras)).strip(), "p")]
        lab_blocks = []
    else:
        # ONE source of truth per cell: the heading.  A label longer than the
        # column can hold is a sentence fragment in the source, so it is set as
        # prose instead of as a heading.
        blocks = []
        if label:
            head = len(label) <= T.LABEL_COL_MAX_CHARS
            blocks.append((label, "h" if head else "p"))
        if paras:
            blocks.append(("\n".join(paras), "p"))
        lab_blocks = []

    _write(blocks, content)
    _write(lab_blocks, lab, align="center")

    X.cell_gradient(cells[1], ri, total, T.C_TALL1_TOP, T.C_TALL1_BOT)
    X.cell_shade(cells[0], T.C_CELL)
    for c in cells:
        X.cell_borders(c, top=("4", T.C_RULE), bottom=("4", T.C_RULE),
                       left=("12", T.C_RULE), right=("12", T.C_RULE))


def _write(blocks, cell, align="both"):
    """
    Emit blocks into a cell.  A block whose text contains newlines becomes one
    PARAGRAPH PER LINE: that is display rhythm only, the characters are the
    source's own and stay in their original order.
    """
    first = True
    for item in blocks:
        if not item:
            continue
        text, kind = item
        if not text:
            continue
        head = kind == "h"
        for piece in text.split("\n"):
            if not piece.strip():
                continue
            p = cell.paragraphs[0] if first else cell.add_paragraph()
            first = False
            if head:
                X.para_props(p, rtl=True,
                             align=("center" if align == "center" else "right"),
                             space_before=0, space_after=40, line=260,
                             keep_next=True)
                X.add_text_run(p, piece, font=T.FONT_HEADING,
                               size=T.SZ_LABEL + 1, bold=True, color=T.C_HEAD_TEXT)
            else:
                X.para_props(p, rtl=True,
                             align=("center" if align == "center" else "both"),
                             space_before=0,
                             space_after=(60 if align == "center" else 90),
                             line=290,
                             ind_first=(0 if align == "center" else 240))
                X.add_text_run(p, piece, font=T.FONT_BODY,
                               size=T.SZ_BODY, color=T.C_TEXT)
    if first:
        X.para_props(cell.paragraphs[0], rtl=True, align="center",
                     space_before=0, space_after=0, line=240)


# --------------------------------------------------------------------------- #
def build_appendix(doc, model):
    """
    Render the summary / questions / answer-key block.

    The source carries a figure (the «لوحة توضيحية») as a drawing paragraph
    between the caption and the source line.  It is placed back at that exact
    point: dropping it would lose teaching material that the caption refers to.

    The ellipses and fragments in this block are the AUTHOR'S OWN: they are
    stored in the source .docx as "\u2026".  This module reproduces them
    character for character and never writes one itself (test 7 proves it).
    """
    items = [a for a in model["appendix"] if a.get("text") or a.get("has_drawing")]
    if not items:
        return
    sep = doc.add_paragraph()
    X.para_props(sep, rtl=True, align="center", space_before=0, space_after=0, line=240)
    # the خلاصة/أسئلة block starts a fresh page so it never fights the plan table
    pPr = sep._p.find(qn("w:pPr"))
    pPr.append(X.el("w:pageBreakBefore", val="1"))

    media = _media_parts(model)
    fig_no = 0
    last = len(items) - 1
    for i, a in enumerate(items):
        if a.get("has_drawing"):
            _place_figure(doc, media, fig_no)
            fig_no += 1
            continue
        for j, text in enumerate(S.segments(a["text"])):
            if not text.strip():
                continue
            head = (j == 0 and (i == 0 or text.startswith(
                ("أولاً", "ثانياً", "ثالثاً", "مفتاح الإجابة", "لوحة توضيحية",
                 "المصدر"))))
            p = doc.add_paragraph()
            X.para_props(p, rtl=True,
                         align=("center" if text.strip().startswith("المصدر") else
                                ("right" if head else "both")),
                         space_before=(220 if head else 0),
                         space_after=(60 if head else 90),
                         line=290,
                         keep_next=head,
                         ind_first=(0 if head else 240))
            X.add_text_run(p, text.strip(),
                           font=T.FONT_HEADING if head else T.FONT_BODY,
                           size=(T.SZ_APPX_H if head else T.SZ_BODY),
                           bold=head,
                           color=(T.C_ACCENT_BLUE if head else T.C_TEXT))


def _media_parts(model):
    """Source images carried on the model, decoded from base64."""
    import base64
    out = []
    for item in model.get("media", []):
        try:
            out.append((item["part"], base64.b64decode(item["b64"])))
        except Exception:
            continue
    return out


def _crop_white(path, tol=246):
    """
    Trim the blank page margin from a source scan.

    The لوحة توضيحية arrives as a full-page scan: two small paintings floating
    on ~85% white.  Placing that scan whole makes the artwork a thumbnail.  This
    crops to the ink bounding box and returns a NEW temporary file -- the source
    image in the .docx is never touched.
    """
    try:
        from PIL import Image as _Img, ImageChops
        im = _Img.open(path).convert("RGB")
        bg = _Img.new("RGB", im.size, (255, 255, 255))
        diff = ImageChops.difference(im, bg).convert("L")
        mask = diff.point(lambda v: 255 if v > (255 - tol) else 0)
        box = mask.getbbox()
        if not box:
            return path
        pad = 8
        box = (max(0, box[0] - pad), max(0, box[1] - pad),
               min(im.size[0], box[2] + pad), min(im.size[1], box[3] + pad))
        out = path.replace(".", "_crop.", 1)
        im.crop(box).save(out, "JPEG", quality=92)
        return out
    except Exception:
        return path


def _figure_compose(path):
    """
    Lay the source's paintings out side by side.

    The scan is a full page: two paintings stacked vertically with a wide blank
    gap between them, which crops to a 1:2.4 sliver -- unreadable at any width
    that fits the page.  This splits the scan at its blank bands and packs the
    bands horizontally (first band rightmost, keeping reading order), then
    writes a NEW temporary file.

    Every pixel of artwork is preserved; only the blank gap between the two
    paintings is reduced.  The image inside the source .docx is never modified.
    """
    try:
        from PIL import Image as _Img
        im = _Img.open(path).convert("RGB")
    except Exception:
        return path
    w, h = im.size
    px = im.load()

    def row_has_ink(y):
        step = max(1, w // 200)
        for x in range(0, w, step):
            r, g, b = px[x, y]
            if r < 246 or g < 246 or b < 246:
                return True
        return False

    bands, start = [], None
    blank = 0
    gap_min = max(6, h // 60)
    for y in range(h):
        if row_has_ink(y):
            if start is None:
                start = y
            blank = 0
        else:
            if start is not None:
                blank += 1
                if blank >= gap_min:
                    bands.append((start, y - blank))
                    start = None
    if start is not None:
        bands.append((start, h - 1))
    bands = [(a, b) for a, b in bands if b - a > h * 0.05]
    if len(bands) < 2:
        return path

    crops = [im.crop((0, a, w, b + 1)) for a, b in bands]
    pad = max(6, w // 80)
    total_w = sum(c.size[0] for c in crops) + pad * (len(crops) - 1)
    max_h = max(c.size[1] for c in crops)
    canvas = _Img.new("RGB", (total_w, max_h), (255, 255, 255))
    x = 0
    for c in reversed(crops):          # first band goes to the right (RTL)
        canvas.paste(c, (x, (max_h - c.size[1]) // 2))
        x += c.size[0] + pad
    out = path.replace(".", "_wide.", 1)
    canvas.save(out, "JPEG", quality=92)
    return out


def _place_figure(doc, media, index):
    """
    Insert the source's own illustration, centred and legible.

    Composition (blank-gap removal) happens in _figure_compose; sizing is fitted
    to the content column so the «المصدر» line that follows stays with it.
    """
    if not media:
        return
    name, blob = media[min(index, len(media) - 1)]
    ext = os.path.splitext(name)[1].lower() or ".jpg"
    raw = os.path.join(tempfile.gettempdir(), "rebo_fig_%d%s" % (index, ext))
    with open(raw, "wb") as fh:
        fh.write(blob)
    path = _figure_compose(_crop_white(raw))

    max_h_in = T.FIGURE_MAX_H_TWIPS / 1440.0
    max_w_in = T.FIGURE_MAX_W_TWIPS / 1440.0
    try:
        from PIL import Image as _Img
        with _Img.open(path) as im:
            w_px, h_px = im.size
        aspect = w_px / float(h_px)
    except Exception:
        aspect = 1.0
    width = min(max_w_in, max_h_in * aspect)
    height = width / aspect if aspect else max_h_in
    if height > max_h_in:
        height = max_h_in
        width = height * aspect

    p = doc.add_paragraph()
    X.para_props(p, rtl=True, align="center", space_before=140, space_after=180,
                 line=240, keep_next=True)
    p.add_run().add_picture(path, width=Inches(width), height=Inches(height))
    for pr in p._p.iter(qn("wp:docPr")):
        pr.set("id", str(_next_id()))


# --------------------------------------------------------------------------- #
def render(model, out_path, total_pages=None):
    """
    Build the DOCX.

    `total_pages` fills the cached NUMPAGES result so a reader that does not
    recalculate fields still shows the right number.
    """
    _DRAW_ID[0] = 1000          # ids must be reproducible run to run
    doc = Document()
    _rtl_defaults(doc)
    section = setup_section(doc)

    body = doc.element.body
    for p in list(body.findall(qn("w:p"))):
        body.remove(p)

    build_headers(section, model)
    section._rebo_pages = total_pages
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
    enable_field_update(doc)
    doc.save(out_path)
    return out_path
