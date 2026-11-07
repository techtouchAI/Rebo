"""
Low-level OOXML helpers.

python-docx does not expose everything needed for correct Arabic RTL output
(no `w:bidi` on pPr, no `w:bidiVisual` on tblPr, no gradient shading, no
character-level bidi protection).  Everything here writes the raw elements in
schema-correct order, because Word silently drops elements that are out of
order inside `pPr`/`tcPr`/`rPr`.
"""
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

from .design_tokens import C_RULE

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


# --------------------------------------------------------------------------- #
# element construction
# --------------------------------------------------------------------------- #
def el(tag, **attrs):
    e = OxmlElement(tag)
    for k, v in attrs.items():
        e.set(qn("w:" + k), str(v))
    return e


# --------------------------------------------------------------------------- #
# runs
# --------------------------------------------------------------------------- #
def make_run_props(rpr_parent, *, font=None, size=None, bold=None, color=None,
                   rtl=True, cs_font=None, italic=None, sz_cs=None):
    """Fill an rPr element in schema order (rFonts, b, i, color, sz, szCs, rtl)."""
    rPr = rpr_parent
    if font or cs_font:
        rFonts = el("w:rFonts")
        f = font or cs_font
        rFonts.set(qn("w:ascii"), f)
        rFonts.set(qn("w:hAnsi"), f)
        rFonts.set(qn("w:cs"), cs_font or f)
        rFonts.set(qn("w:eastAsia"), f)
        rPr.append(rFonts)
    if bold is not None:
        rPr.append(el("w:b", val="1" if bold else "0"))
        rPr.append(el("w:bCs", val="1" if bold else "0"))
    if italic is not None:
        rPr.append(el("w:i", val="1" if italic else "0"))
        rPr.append(el("w:iCs", val="1" if italic else "0"))
    if color:
        rPr.append(el("w:color", val=color))
    if size:
        rPr.append(el("w:sz", val=size))
        rPr.append(el("w:szCs", val=sz_cs or size))
    if rtl:
        rPr.append(el("w:rtl", val="1"))
    return rPr


def add_text_run(paragraph, text, **props):
    """
    Append text as runs with correct RTL properties.

    A literal newline inside a cell value is DATA (the source uses it to
    separate quiz options).  In OOXML a "\n" inside <w:t> is not a line break,
    so it must be emitted as <w:br/> -- otherwise Word renders the lines joined.
    """
    first = None
    for i, chunk in enumerate(str(text).split("\n")):
        r = OxmlElement("w:r")
        rPr = OxmlElement("w:rPr")
        make_run_props(rPr, **props)
        r.append(rPr)
        if i:
            r.append(OxmlElement("w:br"))
        t = OxmlElement("w:t")
        t.set(qn("xml:space"), "preserve")
        t.text = chunk
        r.append(t)
        paragraph._p.append(r)
        if first is None:
            first = r
    if first is None:
        r = OxmlElement("w:r")
        rPr = OxmlElement("w:rPr")
        make_run_props(rPr, **props)
        r.append(rPr)
        paragraph._p.append(r)
        first = r
    return first


# --------------------------------------------------------------------------- #
# paragraphs
# --------------------------------------------------------------------------- #
def para_props(paragraph, *, rtl=True, align="both", space_before=0,
               space_after=0, line=None, keep_next=False, contextual=False):
    """
    Build pPr in schema order:
    keepNext, spacing, bidi, jc, rPr
    `align`: 'both' -> w:jc both, 'center', 'right', 'left'
    For RTL paragraphs `w:jc` values right/left are physical, both/center are neutral.
    """
    p = paragraph._p
    pPr = p.find(qn("w:pPr"))
    if pPr is None:
        pPr = OxmlElement("w:pPr")
        p.insert(0, pPr)

    if keep_next:
        pPr.append(el("w:keepNext", val="1"))

    spacing = el("w:spacing")
    spacing.set(qn("w:before"), str(space_before))
    spacing.set(qn("w:after"), str(space_after))
    if line:
        spacing.set(qn("w:line"), str(line))
        spacing.set(qn("w:lineRule"), "auto")
    pPr.append(spacing)

    if rtl:
        pPr.append(el("w:bidi", val="1"))
        if contextual:
            pPr.append(el("w:contextualSpacing", val="1"))

    jc = el("w:jc", val=align)
    pPr.append(jc)
    return pPr


def add_paragraph(container, text="", **props):
    """Add a paragraph with RTL props and optional text."""
    from docx.text.paragraph import Paragraph
    p = OxmlElement("w:p")
    container._insert_p_before_self if False else None
    container.append(p) if hasattr(container, "append") and not hasattr(container, "add_paragraph") else None
    para = Paragraph(p, container)
    para_props(para, **props)
    if text:
        add_text_run(para, text, **{k: v for k, v in props.items()
                                    if k in ("font", "size", "bold", "color", "rtl", "cs_font")})
    return para


# --------------------------------------------------------------------------- #
# table
# --------------------------------------------------------------------------- #
def table_set_rtl(table):
    """w:bidiVisual -> columns flow right-to-left.  Must sit in tblPr."""
    tblPr = table._tbl.tblPr
    if tblPr.find(qn("w:bidiVisual")) is None:
        bv = el("w:bidiVisual", val="1")
        tblPr.append(bv)


def table_fixed_layout(table):
    tblPr = table._tbl.tblPr
    if tblPr.find(qn("w:tblLayout")) is None:
        tblPr.append(el("w:tblLayout", type="fixed"))


def table_set_grid(table, widths):
    """
    Rewrite tblGrid AND every tc's tcW so grid and cells agree exactly.
    The source files disagree (grid 2594x4 vs cells 1446/1247/1587/6038),
    which is what makes them render unpredictably.
    """
    tbl = table._tbl
    grid = tbl.find(qn("w:tblGrid"))
    if grid is not None:
        tbl.remove(grid)
    grid = OxmlElement("w:tblGrid")
    for w in widths:
        grid.append(el("w:gridCol", w=int(w)))
    tblPr = tbl.tblPr
    tblPr.addnext(grid)
    for row in table.rows:
        for cell, w in zip(row.cells, widths):
            tcPr = cell._tc.get_or_add_tcPr()
            tcW = tcPr.find(qn("w:tcW"))
            if tcW is None:
                tcW = el("w:tcW")
                tcPr.insert(0, tcW)
            tcW.set(qn("w:w"), str(int(w)))
            tcW.set(qn("w:type"), "dxa")


def cell_clear_borders(cell):
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:tcBorders"))
    if old is not None:
        tcPr.remove(old)


def cell_borders(cell, *, top=None, bottom=None, left=None, right=None,
                 inside_h=None, color=None):
    """Set individual borders. None = inherit (do not write)."""
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:tcBorders"))
    if old is not None:
        tcPr.remove(old)
    tb = OxmlElement("w:tcBorders")
    for side, spec in (("top", top), ("left", left),
                       ("bottom", bottom), ("right", right),
                       ("insideH", inside_h)):
        if spec is None:
            continue
        sz, col = spec
        e = el("w:" + side, val="single", sz=sz, space="0", color=col or color)
        tb.append(e)
    if len(tb):
        # tcBorders must precede shd / vAlign
        ref = tcPr.find(qn("w:shd"))
        if ref is not None:
            ref.addprevious(tb)
        else:
            tcPr.append(tb)


def cell_no_borders(cell):
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:tcBorders"))
    if old is not None:
        tcPr.remove(old)
    tb = OxmlElement("w:tcBorders")
    for side in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tb.append(el("w:" + side, val="nil"))
    tcPr.insert(0, tb)


def cell_shade(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:shd"))
    if old is not None:
        tcPr.remove(old)
    shd = el("w:shd", val="clear", color="auto", fill=fill)
    # order: tcBorders, shd, noWrap, tcMar, textDirection, tcFitText, vAlign
    tb = tcPr.find(qn("w:tcBorders"))
    if tb is not None:
        tb.addnext(shd)
    else:
        tcPr.insert(0, shd)


def cell_gradient(cell, row_index, total_rows, top_hex, bottom_hex):
    """
    Approximate the design's vertical gradient on a table column.

    Word's w:shd is a FLAT fill -- OOXML has no gradient inside tcPr.  Drawing a
    shape behind every cell would break text flow and accessibility, so we
    quantise the gradient into `total_rows` flat steps, one per row: the result
    is visually a smooth column-level gradient, still a real table, still
    selectable, still one row per content item.  This is the documented,
    deterministic approximation of the reference art.
    """
    t = row_index / max(1, total_rows - 1)
    fill = _mix(top_hex, bottom_hex, t)
    cell_shade(cell, fill)
    return fill


def _mix(a, b, t):
    """Linear interpolation between two RRGGBB hex strings."""
    t = max(0.0, min(1.0, t))
    ca = [int(a[i:i+2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i+2], 16) for i in (0, 2, 4)]
    out = [int(round(ca[i] + (cb[i] - ca[i]) * t)) for i in range(3)]
    return "".join("%02X" % v for v in out)


def tbl_pr_ordered(table, width_twips, jc="center"):
    """
    Rebuild w:tblPr in the OOXML-required order:
    tblStyle, tblpPr, tblOverlap, bidiVisual, tblStyleRowBandSize,
    tblStyleColBandSize, tblW, jc, tblCellSpacing, tblInd, tblBorders,
    shd, tblLayout, tblCellMar, tblLook
    python-docx appends tblW then tblLook, so we normalise afterwards.
    """
    tbl = table._tbl
    tblPr = tbl.tblPr
    for child in list(tblPr):
        tblPr.remove(child)

    tblPr.append(el("w:tblStyle", val="TableNormal"))
    tblPr.append(el("w:bidiVisual", val="1"))
    tblPr.append(el("w:tblW", w=int(width_twips), type="dxa"))
    tblPr.append(el("w:jc", val=jc))
    b = OxmlElement("w:tblBorders")
    for side in ("top", "left", "bottom", "right", "insideH", "insideV"):
        b.append(el("w:" + side, val="single", sz="12", space="0", color=C_RULE))
    tblPr.append(b)
    tblPr.append(el("w:tblLayout", type="fixed"))
    m = OxmlElement("w:tblCellMar")
    for side, v in (("top", 57), ("start", 85), ("bottom", 57), ("end", 85)):
        e = OxmlElement("w:" + side)
        e.set(qn("w:w"), str(v)); e.set(qn("w:type"), "dxa")
        m.append(e)
    tblPr.append(m)
    tblPr.append(el("w:tblLook", val="0000", firstRow="0", lastRow="0",
                    firstColumn="0", lastColumn="0", noHBand="1", noVBand="1"))


def cell_valign(cell, val="center"):
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:vAlign"))
    if old is not None:
        tcPr.remove(old)
    tcPr.append(el("w:vAlign", val=val))


def cell_margins(cell, top=57, start=85, bottom=57, end=85):
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:tcMar"))
    if old is not None:
        tcPr.remove(old)
    m = OxmlElement("w:tcMar")
    for side, v in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        e = OxmlElement("w:" + side)
        e.set(qn("w:w"), str(v))
        e.set(qn("w:type"), "dxa")
        m.append(e)
    tcPr.append(m)


def cell_vmerge(cell, restart=False):
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:vMerge"))
    if old is not None:
        tcPr.remove(old)
    if restart:
        tcPr.append(el("w:vMerge", val="restart"))
    else:
        tcPr.append(el("w:vMerge"))


def row_props(row, *, height=None, exact=False, header=False, cant_split=True):
    trPr = row._tr.get_or_add_trPr()
    if cant_split:
        trPr.append(el("w:cantSplit"))
    if header:
        trPr.append(el("w:tblHeader", val="true"))
    if height is not None:
        h = el("w:trHeight", val=int(height))
        h.set(qn("w:hRule"), "exact" if exact else "atLeast")
        trPr.append(h)


def row_is_header(row):
    trPr = row._tr.find(qn("w:trPr"))
    return trPr is not None and trPr.find(qn("w:tblHeader")) is not None
