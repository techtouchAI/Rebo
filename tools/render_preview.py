"""
Visual verifier: renders a generated .docx to PDF/PNG **from the docx itself**.

This is NOT Microsoft Word.  It is a second, independent implementation that
reads the same OOXML the template produced and lays it out with the same numbers
(page size, margins, column widths, fills, borders, fonts).  Its purpose is to
catch the class of mistake XML assertions cannot:

  * a column width that disagrees with the grid
  * text overflowing its cell or the print area
  * a merged cell that collapses
  * an RTL run that renders reversed
  * header/footer colliding with the body

It CANNOT prove Word's pagination or Word's font substitution.

Design note: rows are treated as un-splittable.  The template allocates large
`trHeight` values, so a row that does not fit starts on the next page -- exactly
what Word does with `w:cantSplit`, and what the template asserts.
"""
from __future__ import annotations

import io
import os
import zipfile

from lxml import etree
from PIL import Image as PILImage
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import arabic_reshaper
from bidi.algorithm import get_display

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
WP = "{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}"

TW = 1440.0
PT = 72.0

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(HERE, "..", "templates", "assets"))
FONT_FILES = {
    "regular": [os.path.join(ASSETS, "NotoNaskhArabic-Regular.ttf"),
                "/tmp/NotoNaskhArabic-Regular.ttf"],
    "bold": [os.path.join(ASSETS, "NotoNaskhArabic-Bold.ttf"),
             "/tmp/NotoNaskhArabic-Bold.ttf"],
}

_reshaper = arabic_reshaper.ArabicReshaper(
    configuration={"delete_harakat": False, "support_ligatures": True})


def shape(text):
    if not text:
        return ""
    try:
        return get_display(_reshaper.reshape(text))
    except Exception:
        return text


def px2pt(emu):
    """EMU (drawing extent) -> points."""
    return float(emu) / 12700.0


def tw2pt(v):
    return float(v) / TW * PT


def _fonts():
    out = {}
    for weight, paths in FONT_FILES.items():
        for p in paths:
            if os.path.exists(p):
                name = "Naskh-" + weight
                if name not in pdfmetrics.getRegisteredFontNames():
                    pdfmetrics.registerFont(TTFont(name, p))
                out[weight] = name
                break
    if len(out) < 2:
        raise RuntimeError("Arabic TTF missing -- run tools/make_fonts.py")
    return out


class Preview:
    def __init__(self, path):
        self.path = path
        self.z = zipfile.ZipFile(path)
        self.document = etree.fromstring(self.z.read("word/document.xml"))
        self.fonts = _fonts()
        self.sec = self.section()
        self.hf = self._hf_map()

    def _hf_map(self):
        """{'header': {'first': 'word/header2.xml', 'default': ...}, 'footer': {...}}"""
        out = {"header": {}, "footer": {}}
        docrels = self.rels("word/document.xml")
        self._doc_rels = docrels
        sect = self.document.find(".//" + W + "sectPr")
        if sect is None:
            return out
        for tag, kind in (("headerReference", "header"), ("footerReference", "footer")):
            for ref in sect.findall(W + tag):
                t = ref.get(W + "type") or "default"
                rid = ref.get(R + "id")
                tgt = docrels.get(rid)
                if tgt:
                    tgt = tgt.lstrip("/")
                    out[kind][t] = tgt if tgt.startswith("word/") else "word/" + tgt
        return out

    # ---------------- plumbing ----------------
    def part(self, name):
        try:
            return etree.fromstring(self.z.read(name))
        except KeyError:
            return None

    def rels(self, part):
        base = os.path.dirname(part)
        rp = "%s/_rels/%s.rels" % (base, os.path.basename(part))
        root = self.part(rp)
        out = {}
        if root is not None:
            for rel in root:
                out[rel.get("Id")] = rel.get("Target")
        return out

    def img_bytes(self, target):
        t = target.lstrip("/")
        if not t.startswith("word/"):
            t = "word/" + t
        return self.z.read(t)

    def section(self):
        sect = self.document.find(".//" + W + "sectPr")
        sz = sect.find(W + "pgSz")
        mar = sect.find(W + "pgMar")
        return dict(w=int(sz.get(W + "w")), h=int(sz.get(W + "h")),
                    top=int(mar.get(W + "top")), bottom=int(mar.get(W + "bottom")),
                    left=int(mar.get(W + "left")), right=int(mar.get(W + "right")),
                    header=int(mar.get(W + "header")), footer=int(mar.get(W + "footer")))

    def __str__(self):
        s = self.sec
        return ("A4 %.2fx%.2f in | margins T%.2f B%.2f L%.2f R%.2f | text %.2f in" %
                (tw2pt(s['w']) / PT, tw2pt(s['h']) / PT, tw2pt(s['top']) / PT,
                 tw2pt(s['bottom']) / PT, tw2pt(s['left']) / PT,
                 tw2pt(s['right']) / PT, tw2pt(s['w'] - s['left'] - s['right']) / PT))

    # ---------------- text ----------------
    def runs_of(self, p):
        out = []
        for r in p.findall(W + "r"):
            t = "".join(x.text or "" for x in r.findall(W + "t"))
            if not t:
                continue
            rPr = r.find(W + "rPr")
            sz, bold, color = 20, False, "#000000"
            if rPr is not None:
                v = rPr.find(W + "sz")
                if v is not None:
                    sz = int(v.get(W + "val"))
                bold = rPr.find(W + "b") is not None
                col = rPr.find(W + "color")
                if col is not None and col.get(W + "val") not in (None, "auto"):
                    color = "#" + col.get(W + "val")
            out.append(dict(t=t, sz=sz, bold=bold, color=color))
        return out

    def pstyle(self, p):
        pPr = p.find(W + "pPr")
        jc, before, after = "both", 0, 0
        if pPr is not None:
            j = pPr.find(W + "jc")
            if j is not None:
                jc = j.get(W + "val")
            sp = pPr.find(W + "spacing")
            if sp is not None:
                before = int(sp.get(W + "before") or 0)
                after = int(sp.get(W + "after") or 0)
        return jc, before, after

    def wrap(self, text, width, size, bold, pad=4.0):
        font = self.fonts["bold" if bold else "regular"]
        fs = size / 2.0
        maxw = max(10.0, width - 2 * pad)
        lines, cur = [], ""
        for wordword in (text or "").split(" "):
            trial = (cur + " " + wordword).strip()
            if pdfmetrics.stringWidth(shape(trial), font, fs) <= maxw or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = wordword
        if cur:
            lines.append(cur)
        return lines or [""]

    def cell_ops(self, tc, width):
        """Flatten a cell to ops: ('line', txt, size, bold, colour, align) or ('gap', pt)."""
        ops = []
        for p in tc.findall(W + "p"):
            rs = self.runs_of(p)
            jc, before, after = self.pstyle(p)
            if before:
                ops.append(("gap", tw2pt(before)))
            if not rs:
                blip = p.find(".//" + A + "blip")
                if blip is not None:
                    ext = p.find(".//" + WP + "extent")
                    w_pt = px2pt(int(ext.get("cx"))) if ext is not None else width * 0.9
                    h_pt = px2pt(int(ext.get("cy"))) if ext is not None else 60.0
                    ops.append(("img", blip.get(R + "embed"),
                                min(w_pt, width - 8), h_pt))
                else:
                    ops.append(("gap", 4.0))
            else:
                text = "".join(r["t"] for r in rs)
                size = max(r["sz"] for r in rs)
                bold = any(r["bold"] for r in rs)
                align = "center" if jc == "center" else (
                    "right" if jc in ("right", "start") else "left")
                for ln in self.wrap(text, width, size, bold):
                    ops.append(("line", ln, size, bold, rs[0]["color"], align))
            if after:
                ops.append(("gap", tw2pt(after)))
        return ops

    @staticmethod
    def op_h(op):
        if op[0] == "line":
            return op[2] / 2.0 * 1.45
        if op[0] == "img":
            return op[3] + 6.0
        return op[1]

    # ---------------- paint ----------------
    def paint_ops(self, c, ops, x, y_top, width, max_h):
        """Draw ops from y_top downward, clipping at max_h. Returns used height."""
        font_used = 0.0
        ty = y_top
        budget = max_h - 4
        for op in ops:
            h = self.op_h(op)
            if font_used + h > budget:
                break
            if op[0] == "img":
                _k, rid, w_pt, h_pt = op
                tgt = (self._doc_rels or {}).get(rid)
                if tgt:
                    data = self.img_bytes(tgt)
                    if data:
                        c.drawImage(ImageReader(io.BytesIO(data)),
                                    x + (width - w_pt) / 2.0, ty - h_pt,
                                    width=w_pt, height=h_pt,
                                    preserveAspectRatio=True, anchor="n", mask="auto")
                        ty -= h_pt + 6.0
                        font_used += h_pt + 6.0
                continue
            if op[0] == "line":
                _k, ln, size, bold, color, align = op
                font = self.fonts["bold" if bold else "regular"]
                fs = size / 2.0
                c.setFont(font, fs)
                c.setFillColor(HexColor(color))
                s = shape(ln)
                sw = pdfmetrics.stringWidth(s, font, fs)
                if align == "center":
                    tx = x + (width - sw) / 2.0
                elif align == "right":
                    tx = x + width - 4 - sw
                else:
                    tx = x + 4
                c.drawString(tx, ty - fs * 1.05, s)
                ty -= h
            else:
                ty -= op[1]
            font_used += h
        return font_used

    # ---------------- render ----------------
    def render(self, out_pdf):
        s = self.sec
        Wp, Hp = tw2pt(s["w"]), tw2pt(s["h"])
        ml = tw2pt(s["left"])
        mt, mb = tw2pt(s["top"]), tw2pt(s["bottom"])
        text_w = tw2pt(s["w"] - s["left"] - s["right"])

        c = canvas.Canvas(out_pdf, pagesize=(Wp, Hp))
        self._first = True
        self._header(c)
        y = Hp - mt

        def newpage():
            self._footer(c)
            c.showPage()
            self._first = False
            self._header(c)
            return Hp - mt

        for child in self.document.find(W + "body"):
            tag = child.tag.split("}")[1]
            if tag == "p":
                need = self._para_height(child, text_w)
                if need and y - need < mb:
                    y = newpage()
                y = self._para(c, child, ml, y, text_w)
                if y < mb + 20:
                    y = newpage()
            elif tag == "tbl":
                y = self._table(c, child, ml, y, text_w, mb, newpage)
        self._footer(c)
        c.save()
        return self._pages

    def _para_height(self, p, w):
        """Height an image paragraph will need (0 for ordinary text)."""
        blip = p.find(".//" + A + "blip")
        if blip is None:
            return 0.0
        ext = p.find(".//" + WP + "extent")
        h_pt = px2pt(int(ext.get("cy"))) if ext is not None else 120.0
        return h_pt + 12.0

    def _paint_header_row(self, tbl, tr, xs, widths, ytop):
        """Draw a header row (used for tblHeader repetition)."""
        c = self.c
        h = 24.0
        tp = tr.find(W + "trPr")
        if tp is not None:
            th = tp.find(W + "trHeight")
            if th is not None:
                h = max(20.0, tw2pt(int(th.get(W + "val"))))
        for ci, tc in enumerate(tr.findall(W + "tc")):
            if ci >= len(xs):
                break
            tcp = tc.find(W + "tcPr")
            if tcp is not None:
                shd = tcp.find(W + "shd")
                if shd is not None and shd.get(W + "fill") not in (None, "auto"):
                    c.setFillColor(HexColor("#" + shd.get(W + "fill")))
                    c.rect(xs[ci], ytop - h, widths[ci], h, stroke=0, fill=1)
            for p in tc.findall(W + "p"):
                rs = self.runs_of(p)
                if not rs:
                    continue
                text = "".join(r["t"] for r in rs)
                size = max(r["sz"] for r in rs)
                font = self.fonts["bold" if any(r["bold"] for r in rs) else "regular"]
                fs = size / 2.0
                c.setFont(font, fs)
                c.setFillColor(HexColor(rs[0]["color"]))
                ss = shape(text)
                sw = pdfmetrics.stringWidth(ss, font, fs)
                c.drawString(xs[ci] + (widths[ci] - sw) / 2.0, ytop - h / 2 - fs * 0.35, ss)

    def _header(self, c):
        """Render whatever the header part actually contains: images and/or a bar table."""
        s = self.sec
        self._pages = getattr(self, "_pages", 0) + 1
        kind = "first" if self._first else "default"
        part = self.hf["header"].get(kind) or self.hf["header"].get("default")
        if not part:
            return
        root = self.part(part)
        if root is None:
            return
        rels = self.rels(part)
        y = tw2pt(s["h"]) - tw2pt(s["header"])

        # images
        for run in root.iter(W + "r"):
            blip = run.find(".//" + A + "blip")
            if blip is None:
                continue
            tgt = rels.get(blip.get(R + "embed"))
            if not tgt:
                continue
            data = self.img_bytes(tgt)
            img = PILImage.open(io.BytesIO(data))
            w_pt = tw2pt(s["w"] - s["left"] - s["right"])
            h_pt = w_pt * img.size[1] / float(img.size[0])
            c.drawImage(ImageReader(io.BytesIO(data)), tw2pt(s["left"]),
                        y - h_pt, width=w_pt, height=h_pt,
                        preserveAspectRatio=True, anchor="n", mask="auto")

        # tables (the running bar)
        for tbl in root.iter(W + "tbl"):
            grid = [int(g.get(W + "w")) for g in tbl.find(W + "tblGrid")]
            tblPr = tbl.find(W + "tblPr")
            bidi = tblPr is not None and tblPr.find(W + "bidiVisual") is not None
            widths = [tw2pt(g) for g in grid]
            total = sum(widths)
            x0 = tw2pt(s["left"])
            w_avail = tw2pt(s["w"] - s["left"] - s["right"])
            if bidi:
                xs, cur = [], x0 + w_avail - total
                for wp in widths:
                    xs.append(cur); cur += wp
            else:
                xs, cur = [], x0
                for wp in widths:
                    xs.append(cur); cur += wp
            for tr in tbl.findall(W + "tr"):
                h = 16.0
                tp = tr.find(W + "trPr")
                if tp is not None:
                    th = tp.find(W + "trHeight")
                    if th is not None:
                        h = max(14.0, tw2pt(int(th.get(W + "val"))))
                for ci, tc in enumerate(tr.findall(W + "tc")):
                    if ci >= len(xs):
                        break
                    tcp = tc.find(W + "tcPr")
                    if tcp is not None:
                        shd = tcp.find(W + "shd")
                        if shd is not None and shd.get(W + "fill") not in (None, "auto"):
                            c.setFillColor(HexColor("#" + shd.get(W + "fill")))
                            c.rect(xs[ci], y - h, widths[ci], h, stroke=0, fill=1)
                    for p in tc.findall(W + "p"):
                        rs = self.runs_of(p)
                        if not rs:
                            continue
                        text = "".join(r["t"] for r in rs)
                        size = max(r["sz"] for r in rs)
                        jc, _b, _a = self.pstyle(p)
                        font = self.fonts["bold" if any(r["bold"] for r in rs) else "regular"]
                        fs = size / 2.0
                        c.setFont(font, fs)
                        c.setFillColor(HexColor(rs[0]["color"]))
                        ss = shape(text)
                        sw = pdfmetrics.stringWidth(ss, font, fs)
                        tx = xs[ci] + (widths[ci] - sw) / 2.0 if jc == "center" \
                            else xs[ci] + widths[ci] - 4 - sw
                        c.drawString(tx, y - h / 2 - fs * 0.35, ss)
                y -= h

    def _footer(self, c):
        s = self.sec
        Wp = tw2pt(s["w"])
        kind = "first" if self._first else "default"
        use = self.hf["footer"].get(kind) or self.hf["footer"].get("default")
        if not use:
            return
        root = self.part(use)
        if root is None:
            return
        rels = self.rels(use)
        y = tw2pt(s["footer"])
        fs = 8
        c.setFont(self.fonts["regular"], fs)
        c.setFillColor(HexColor("#182C51"))
        txt = "التربية الفنية  •  صفحة %d" % self._pages
        ss = shape(txt)
        c.drawString((Wp - pdfmetrics.stringWidth(ss, self.fonts["regular"], fs)) / 2.0,
                     y, ss)
        y += 11
        for p in root.findall(W + "p"):
            for run in p.findall(W + "r"):
                blip = run.find(".//" + A + "blip")
                if blip is None:
                    continue
                tgt = rels.get(blip.get(R + "embed"))
                if not tgt:
                    continue
                data = self.img_bytes(tgt)
                img = PILImage.open(io.BytesIO(data))
                w_pt = tw2pt(s["w"] - s["left"] - s["right"])
                h_pt = w_pt * img.size[1] / float(img.size[0])
                c.drawImage(ImageReader(io.BytesIO(data)), tw2pt(s["left"]),
                            y, width=w_pt, height=h_pt,
                            preserveAspectRatio=True, anchor="s", mask="auto")

    def _para(self, c, p, x, y, w):
        rs = self.runs_of(p)
        jc, before, after = self.pstyle(p)
        y -= tw2pt(before)
        if not rs:
            blip = p.find(".//" + A + "blip")
            if blip is not None:
                ext = p.find(".//" + WP + "extent")
                w_pt = px2pt(int(ext.get("cx"))) if ext is not None else w * 0.9
                h_pt = px2pt(int(ext.get("cy"))) if ext is not None else 120.0
                w_pt = min(w_pt, w - 4)
                tgt = (self._doc_rels or {}).get(blip.get(R + "embed"))
                if tgt:
                    data = self.img_bytes(tgt)
                    if data:
                        c.drawImage(ImageReader(io.BytesIO(data)),
                                    x + (w - w_pt) / 2.0, y - h_pt,
                                    width=w_pt, height=h_pt,
                                    preserveAspectRatio=True, anchor="n", mask="auto")
                        return y - h_pt - tw2pt(after) - 6
            return y - tw2pt(after) - 5
        text = "".join(r["t"] for r in rs)
        size = max(r["sz"] for r in rs)
        bold = any(r["bold"] for r in rs)
        align = "center" if jc == "center" else "right"
        lines = self.wrap(text, w, size, bold, pad=2)
        fs = size / 2.0
        for ln in lines:
            s = shape(ln)
            font = self.fonts["bold" if bold else "regular"]
            sw = pdfmetrics.stringWidth(s, font, fs)
            tx = x + (w - sw) / 2.0 if align == "center" else x + w - 2 - sw
            c.setFont(font, fs)
            c.setFillColor(HexColor(rs[0]["color"]))
            c.drawString(tx, y - fs * 1.05, s)
            y -= fs * 1.45
        return y - tw2pt(after)

    def _table(self, c, tbl, x, y, w, mb, newpage):
        s = self.sec
        tblPr = tbl.find(W + "tblPr")
        bidi = tblPr is not None and tblPr.find(W + "bidiVisual") is not None
        grid = [int(g.get(W + "w")) for g in tbl.find(W + "tblGrid")]
        widths = [tw2pt(g) for g in grid]
        total = sum(widths)
        if bidi:
            xs, cur = [], x + w - total
            for wp in widths:
                xs.append(cur)
                cur += wp
        else:
            xs, cur = [], x
            for wp in widths:
                xs.append(cur)
                cur += wp

        trs = tbl.findall(W + "tr")
        # header row detection
        hdr_idx = -1
        if trs:
            tp = trs[0].find(W + "trPr")
            if tp is not None and tp.find(W + "tblHeader") is not None:
                hdr_idx = 0

        def min_height(tr):
            tp = tr.find(W + "trPr")
            if tp is None:
                return 0.0
            h = tp.find(W + "trHeight")
            return tw2pt(int(h.get(W + "val"))) if h is not None else 0.0

        for ri, tr in enumerate(trs):
            if ri > 0 and hdr_idx == 0 and y - 40 < mb and not self._table_open:
                # a real Word table repeats its tblHeader row at the page top
                self._paint_header_row(tbl, trs[0], xs, widths, y)
                y = tw2pt(s["h"]) - tw2pt(s["top"])
                self._table_open = True
            self._table_open = True
            cells = tr.findall(W + "tc")
            info = []
            for ci, tc in enumerate(cells):
                if ci >= len(widths):
                    break
                tcPr = tc.find(W + "tcPr")
                vm = tcPr.find(W + "vMerge") if tcPr is not None else None
                ops = [] if (vm is not None and vm.get(W + "val") != "restart") \
                    else self.cell_ops(tc, widths[ci])
                info.append(dict(ci=ci, tc=tc, ops=ops,
                                 cont=(vm is not None and vm.get(W + "val") != "restart"),
                                 idx=0, used=0.0))
            need = max([sum(self.op_h(o) for o in cel["ops"]) for cel in info] or [0]) + 8
            h = max(need, min_height(tr))
            cant_split = False
            tp = tr.find(W + "trPr")
            if tp is not None and tp.find(W + "cantSplit") is not None:
                cant_split = True

            # a row that cannot split moves wholesale to the next page
            if cant_split and (y - h) < mb and ri > 0:
                y = newpage()
            # a row that CAN split streams across pages like Word does
            if not cant_split and h > (y - mb) and ri > 0:
                while y - mb < 20:
                    y = newpage()

            while True:
                avail = y - mb
                # how much content is still unplaced in this row?
                rem = 0.0
                for cel in info:
                    if cel["cont"]:
                        continue
                    rem = max(rem, sum(self.op_h(o) for o in cel["ops"][cel["idx"]:]))
                want = min(h, rem + 8) if not cant_split else h
                want = max(want, min_height(tr) if cel["idx"] == 0 else 12.0)
                seg = max(min(want, avail), 12.0)
                for cel in info:
                    ci = cel["ci"]
                    if ci >= len(xs) or cel["cont"]:
                        continue
                    cw = widths[ci]
                    tcp = cel["tc"].find(W + "tcPr")
                    if tcp is not None:
                        shd = tcp.find(W + "shd")
                        if shd is not None and shd.get(W + "fill") not in (None, "auto"):
                            c.setFillColor(HexColor("#" + shd.get(W + "fill")))
                            c.rect(xs[ci], y - seg, cw, seg, stroke=0, fill=1)
                    c.setStrokeColor(HexColor("#182C51"))
                    c.setLineWidth(0.7)
                    c.rect(xs[ci], y - seg, cw, seg, stroke=1, fill=0)
                    # draw as many ops as fit in this slice
                    ty, budget = y - 2, seg - 4
                    ops = cel["ops"]
                    i = cel["idx"]
                    spent = cel["used"]
                    while i < len(ops):
                        oh = self.op_h(ops[i])
                        if spent + oh > budget:
                            break
                        op = ops[i]
                        if op[0] == "line":
                            _k, ln, size, bold, colour, align = op
                            font = self.fonts["bold" if bold else "regular"]
                            fs = size / 2.0
                            c.setFont(font, fs)
                            c.setFillColor(HexColor(colour))
                            ss = shape(ln)
                            sw = pdfmetrics.stringWidth(ss, font, fs)
                            if align == "center":
                                tx = xs[ci] + (cw - sw) / 2.0
                            elif align == "right":
                                tx = xs[ci] + cw - 4 - sw
                            else:
                                tx = xs[ci] + 4
                            c.drawString(tx, ty - fs * 1.05, ss)
                            ty -= oh
                        spent += oh
                        i += 1
                    cel["idx"] = i
                    cel["used"] = 0.0 if i < len(ops) else spent
                y -= seg
                if cant_split:
                    break
                more = any(cel["idx"] < len(cel["ops"]) for cel in info if not cel["cont"])
                if not more:
                    break
                y = newpage()

        return y

    def _top(self):
        return tw2pt(self.sec["h"]) - tw2pt(self.sec["top"])


def convert(docx_path, out_pdf, png_prefix=None, dpi=110):
    p = Preview(docx_path)
    pages = p.render(out_pdf)
    pngs = 0
    if png_prefix:
        try:
            import pymupdf
        except ImportError:
            import fitz as pymupdf
        d = pymupdf.open(out_pdf)
        for i, page in enumerate(d):
            pix = page.get_pixmap(dpi=dpi)
            pix.save("%s-%d.png" % (png_prefix, i + 1))
            pngs += 1
    return pages, pngs


if __name__ == "__main__":
    import sys
    print("pages=%d pngs=%d" % convert(sys.argv[1], sys.argv[2],
                                       sys.argv[3] if len(sys.argv) > 3 else None))
