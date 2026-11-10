"""
Stage 4.2 -- ILLUSTRATION LIBRARY.

Every teaching plate is drawn here from a *named, deterministic* recipe:
same inputs -> byte-identical PNG, cached on (name, size, digest).

Rules encoded in the drawing layer
----------------------------------
* Arabic labels are shaped (arabic_reshaper + bidi) and drawn with the same
  Noto Naskh font the document uses, so a label can never become tofu.
* A plate carries a caption and a source line; the caption is the source's own
  wording when it has one, otherwise the plate is marked as a generated
  *educational re-representation* -- never attributed to a real artist or a
  historical work.
* No plate invents a fact.  Callouts name parts that the lesson text names.
* Nothing is stretched: plates are drawn at the target aspect ratio.
"""
from __future__ import annotations

import hashlib
import io
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(os.path.dirname(HERE), "templates", "assets")
CACHE = os.path.join(os.path.dirname(HERE), "build", "figures")

# ---- palette (aligned with design_tokens) ----------------------------------
INK = (21, 36, 61)
NAVY = (0, 25, 81)
BLUE = (29, 78, 137)
STEEL = (120, 148, 184)
PALE = (224, 237, 253)
PAPER = (253, 253, 253)
GOLD = (209, 173, 115)
CLAY = (196, 142, 108)
CLAY_D = (150, 100, 72)
GYP = (238, 236, 229)
GYP_D = (206, 202, 191)
WOOD = (198, 158, 106)
WOOD_D = (150, 112, 68)
CANE = (214, 186, 122)
CANE_D = (168, 138, 78)
LEATH = (150, 104, 70)
GREY = (150, 150, 150)

FONT_R = os.path.join(ASSETS, "NotoNaskhArabic-Regular.ttf")
FONT_B = os.path.join(ASSETS, "NotoNaskhArabic-Bold.ttf")

_reshaper = None


def _shape(t):
    """Arabic shaping + bidi for PIL (which draws glyphs in visual order)."""
    global _reshaper
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display
        if _reshaper is None:
            _reshaper = arabic_reshaper.ArabicReshaper(
                configuration={"delete_harakat": False,
                               "support_ligatures": True})
        return get_display(_reshaper.reshape(t))
    except Exception:                                   # pragma: no cover
        return t


def _font(size, bold=False):
    from PIL import ImageFont
    return ImageFont.truetype(FONT_B if bold else FONT_R, size)


# --------------------------------------------------------------------------- #
class Plate:
    """A drawing surface with RTL-aware text helpers."""

    def __init__(self, w, h, bg=PAPER):
        self.w, self.h = w, h
        self.im = Image.new("RGB", (w, h), bg)
        self.d = ImageDraw.Draw(self.im)

    # ---- primitives -------------------------------------------------------
    def rect(self, box, fill=None, outline=INK, width=3, radius=0):
        if radius:
            self.d.rounded_rectangle(box, radius=radius, fill=fill,
                                     outline=outline, width=width)
        else:
            self.d.rectangle(box, fill=fill, outline=outline, width=width)

    def line(self, pts, color=INK, width=3):
        self.d.line(pts, fill=color, width=width, joint="curve")

    def ellipse(self, box, fill=None, outline=INK, width=3):
        self.d.ellipse(box, fill=fill, outline=outline, width=width)

    def poly(self, pts, fill=None, outline=INK, width=3):
        self.d.polygon(pts, fill=fill)
        if outline:
            self.d.line(list(pts) + [pts[0]], fill=outline, width=width,
                        joint="curve")

    def arrow(self, a, b, color=BLUE, width=5, head=16):
        import math
        self.d.line([a, b], fill=color, width=width)
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        p1 = (b[0] - head * math.cos(ang - 0.42),
              b[1] - head * math.sin(ang - 0.42))
        p2 = (b[0] - head * math.cos(ang + 0.42),
              b[1] - head * math.sin(ang + 0.42))
        self.d.polygon([b, p1, p2], fill=color)

    # ---- text -------------------------------------------------------------
    def text(self, xy, s, size=34, bold=False, color=INK, anchor="ra",
             max_w=None):
        """Draw Arabic text. anchor: ra|la|ma|mm|rm|lm."""
        f = _font(size, bold)
        t = _shape(s)
        if max_w:
            while pdf_w(self, t, f) > max_w and size > 12:
                size -= 2
                f = _font(size, bold)
        self.d.text(xy, t, font=f, fill=color, anchor=anchor)

    def wrap(self, s, size, max_w, bold=False):
        """Greedy word wrap in the shaped form, so widths are exact."""
        f = _font(size, bold)
        words = (s or "").split()
        lines, cur = [], ""
        for w in words:
            trial = (cur + " " + w).strip()
            if pdf_w(self, _shape(trial), f) <= max_w or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        return lines

    def text_block(self, cx, y, s, size, max_w, color=INK, bold=False,
                   line_h=None, anchor="ma"):
        lines = self.wrap(s, size, max_w, bold)[:3]
        line_h = line_h or int(size * 1.35)
        for i, ln in enumerate(lines):
            self.text((cx, y + i * line_h), ln, size, bold, color, anchor)
        return y + len(lines) * line_h

    def label(self, xy, s, size=30, fill=PALE, color=NAVY, pad=14, bold=True):
        """A boxed Arabic callout that sits on top of the artwork."""
        f = _font(size, bold)
        t = _shape(s)
        w = pdf_w(self, t, f)
        x, y = xy
        box = [x - w - pad, y - size * 0.85 - pad * 0.4,
               x + pad, y + size * 0.55 + pad * 0.4]
        self.d.rounded_rectangle(box, radius=10, fill=fill, outline=color,
                                 width=2)
        self.d.text((x - pad / 2, y), t, font=f, fill=color, anchor="rm")
        return box

    def caption(self, s, size=30, color=INK, y=None):
        self.text((self.w - 24, y if y is not None else self.h - 34), s,
                  size=size, bold=True, color=color, anchor="rs")

    def frame(self, color=STEEL, width=3):
        self.d.rectangle([1, 1, self.w - 2, self.h - 2], outline=color,
                         width=width)

    def save(self, path):
        self.im.save(path, "PNG", optimize=True)
        return path


def pdf_w(plate, text, font):
    try:
        return plate.d.textlength(text, font=font)
    except Exception:                                   # pragma: no cover
        return font.getlength(text)


# --------------------------------------------------------------------------- #
# geometry helpers
# --------------------------------------------------------------------------- #
def cylinder(p, box, fill=CLAY, outline=CLAY_D, w=4):
    """An upright cylinder: pot / perch / cane / drum."""
    x0, y0, x1, y1 = box
    ry = max(6, int((x1 - x0) * 0.16))
    p.ellipse([x0, y1 - ry, x1, y1 + ry], fill=fill, outline=outline, width=w)
    p.rect([x0, y0, x1, y1], fill=fill, outline=None, width=0)
    p.ellipse([x0, y0 - ry, x1, y0 + ry], fill=fill, outline=outline, width=w)
    p.line([(x0, y0), (x0, y1)], color=outline, width=w)
    p.line([(x1, y0), (x1, y1)], color=outline, width=w)


def pot(p, cx, cy, rw, rh, fill=CLAY, outline=CLAY_D, w=4):
    """A thrown vessel silhouette."""
    p.poly([(cx - rw * 0.42, cy - rh), (cx + rw * 0.42, cy - rh),
            (cx + rw * 0.30, cy - rh * 0.55), (cx + rw, cy - rh * 0.10),
            (cx + rw * 0.86, cy + rh * 0.78), (cx + rw * 0.34, cy + rh),
            (cx - rw * 0.34, cy + rh), (cx - rw * 0.86, cy + rh * 0.78),
            (cx - rw, cy - rh * 0.10), (cx - rw * 0.30, cy - rh * 0.55)],
           fill=fill, outline=outline, width=w)
    p.ellipse([cx - rw * 0.42, cy - rh - rh * 0.14,
               cx + rw * 0.42, cy - rh + rh * 0.14],
              fill=(255, 255, 255), outline=outline, width=w)


def hatch(p, box, step=18, color=STEEL):
    x0, y0, x1, y1 = box
    for x in range(int(x0) - int(y1 - y0), int(x1), step):
        p.line([(max(x0, x), max(y0, y0 + (x0 - x))),
                (min(x1, x + (y1 - y0)), min(y1, y1))], color=color, width=1)


def ticks(p, a, b, n, color=INK, w=3, size=14):
    """Dimension ticks between two points."""
    for pt in (a, b):
        p.line([(pt[0] - size, pt[1] - size), (pt[0] + size, pt[1] + size)],
               color=color, width=w)
    p.line([a, b], color=color, width=w)


# --------------------------------------------------------------------------- #
# PLATES
# --------------------------------------------------------------------------- #
def plate_plaster_mould(p):
    """قالب جبسي من قطعتين: النصفان، طبقة الفصل، وصورة سالبة مجوّفة."""
    p.text((p.w // 2, 30), "القالب الجبسي من قطعتين", 40, True, NAVY, "ma")
    p.text((p.w // 2, 88), "الرسم يوضح أجزاء القالب كما وردت في الدرس",
           26, False, STEEL, "ma")

    # ---- left: the two halves separated ----
    base_y = p.h - 150
    for k, dx in ((0, -1), (1, 1)):
        x = p.w * 0.28 + dx * 190
        p.poly([(x - 90, base_y), (x - 74, base_y - 300),
                (x + 74, base_y - 300), (x + 90, base_y)],
               fill=GYP, outline=GYP_D, width=4)
        # the negative cavity
        p.poly([(x + dx * -18, base_y - 24), (x - dx * 28, base_y - 150),
                (x + dx * 28, base_y - 214), (x + dx * 18 + 26, base_y - 24)],
               fill=(255, 255, 255), outline=GYP_D, width=3)
        p.text((x, base_y - 320), "النصف " + ("الأول" if k else "الثاني"),
               30, True, NAVY, "ma")

    # ---- middle: separating film ----
    p.line([(p.w * 0.28 - 6, base_y + 26), (p.w * 0.28 + 6, base_y + 46)],
           color=STEEL, width=4)
    for y in range(base_y - 290, base_y + 40, 26):
        p.line([(p.w * 0.28 - 6, y), (p.w * 0.28 + 6, y + 18)],
               color=STEEL, width=2)
    p.label((p.w * 0.28 + 140, base_y + 30), "طبقة عازلة / صفائح معدنية",
            26, PALE, BLUE)

    # ---- right: assembled mould with the pouring channel ----
    ax = p.w * 0.72
    p.poly([(ax - 110, base_y), (ax - 88, base_y - 320),
            (ax + 88, base_y - 320), (ax + 110, base_y)],
           fill=GYP, outline=GYP_D, width=5)
    p.poly([(ax - 26, base_y - 320), (ax - 14, base_y - 372),
            (ax + 14, base_y - 372), (ax + 26, base_y - 320)],
           fill=GYP, outline=GYP_D, width=5)
    p.line([(ax, base_y - 300), (ax, base_y - 30)], color=GYP_D, width=3)
    # tie cords
    for yy in (base_y - 260, base_y - 150, base_y - 60):
        p.line([(ax - 118, yy), (ax + 118, yy)], color=LEATH, width=5)
    p.label((ax + 190, base_y - 356), "فتحة الصب", 26, PALE, BLUE)
    p.label((ax + 210, base_y - 150), "الخيوط", 26, PALE, BLUE)
    p.arrow((ax + 60, base_y - 430), (ax + 8, base_y - 380), BLUE, 5)
    p.text((ax + 74, base_y - 436), "الجبس السائل", 26, False, BLUE, "lm")

    p.text((p.w - 40, p.h - 30),
           "إعادة تمثيل تعليمية مولّدة — ليست صورة أثرية",
           22, False, GREY, "rs")
    p.frame()


def plate_orange_mould(p):
    """مراحل عمل قالب البرتقالة (٣ مراحل) — كما وردت في الدرس."""
    p.text((p.w // 2, 26), "مراحل عمل قالب البرتقالة", 40, True, NAVY, "ma")
    p.text((p.w // 2, 84), "نصفان ثم فتح القالب — ثلاث مراحل", 26, False, STEEL, "ma")
    w3 = p.w // 3
    for i, (t, sub) in enumerate((("١", "الصب على النصف"),
                                  ("٢", "دهن الحافة"),
                                  ("٣", "فتح القالب"))):
        x = p.w - w3 * (i + 1) + w3 // 2
        cy = p.h * 0.58
        p.ellipse([x - 92, cy - 92, x + 92, cy + 92], fill=(240, 150, 60),
                  outline=(170, 96, 24), width=4)
        if i == 0:
            p.poly([(x - 92, cy), (x - 60, cy - 120), (x + 60, cy - 120),
                    (x + 92, cy)], fill=GYP, outline=GYP_D, width=4)
        elif i == 1:
            p.poly([(x - 92, cy), (x - 60, cy - 120), (x + 60, cy - 120),
                    (x + 92, cy)], fill=GYP, outline=GYP_D, width=4)
            p.line([(x + 92, cy - 4), (x + 150, cy - 90)], color=BLUE, width=5)
        else:
            p.poly([(x - 132, cy + 40), (x - 108, cy - 120),
                    (x - 8, cy - 120), (x - 14, cy + 40)],
                   fill=GYP, outline=GYP_D, width=4)
            p.poly([(x + 14, cy + 40), (x + 8, cy - 120),
                    (x + 108, cy - 120), (x + 132, cy + 40)],
                   fill=GYP, outline=GYP_D, width=4)
        p.text((x, cy + 150), "%s — %s" % (t, sub), 30, True, NAVY, "ma")
    for i in range(2):
        x0 = p.w - w3 * (i + 1)
        p.line([(x0, 120), (x0, p.h - 120)], color=STEEL, width=2)
    p.text((p.w - 40, p.h - 26),
           "إعادة تمثيل تعليمية مولّدة", 22, False, GREY, "rs")
    p.frame()


def plate_cane_joints(p):
    """أنواع الربط في القصب: حلقة، تبادلي، خرز."""
    p.text((p.w // 2, 24), "أساليب ربط القصب", 40, True, NAVY, "ma")
    p.text((p.w // 2, 82), "ثلاثة أنماط كما وصفها الدرس", 26, False, STEEL, "ma")
    w3 = p.w // 3
    specs = ("حلقة دائرية", "ربط تبادلي", "ربط بالخرز")
    for i, name in enumerate(specs):
        cx = w3 * (2 - i) + w3 // 2
        cy = p.h * 0.56
        r = 120
        n = 12
        import math
        for k in range(n):
            a = 2 * math.pi * k / n
            x = cx + r * math.cos(a)
            y = cy + r * math.sin(a)
            p.ellipse([x - 15, y - 15, x + 15, y + 15], fill=CANE,
                      outline=INK, width=3)
            if i == 0:
                p.line([(cx + (r - 16) * math.cos(a), cy + (r - 16) * math.sin(a)),
                        (cx + (r - 16) * math.cos(a + 2 * math.pi / n),
                         cy + (r - 16) * math.sin(a + 2 * math.pi / n))],
                       color=LEATH, width=3)
        if i == 1:
            p.line([(cx, cy - r - 26), (cx, cy + r + 26)], color=INK, width=4)
            p.line([(cx - 26, cy - r - 26), (cx + 26, cy - r - 26)],
                   color=INK, width=4)
            p.line([(cx - 26, cy + r + 26), (cx + 26, cy + r + 26)],
                   color=INK, width=4)
        if i == 2:
            for k in range(0, n, 2):
                a = 2 * math.pi * k / n
                p.ellipse([cx + (r - 40) * math.cos(a) - 10,
                           cy + (r - 40) * math.sin(a) - 10,
                           cx + (r - 40) * math.cos(a) + 10,
                           cy + (r - 40) * math.sin(a) + 10],
                          fill=GOLD, outline=(160, 128, 70), width=2)
        p.text((cx, p.h - 96), name, 32, True, NAVY, "ma")
        if i < 2:
            p.line([(w3 * (2 - i), 130), (w3 * (2 - i), p.h - 130)],
                   color=STEEL, width=2)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_paper_nets(p):
    """انفرادات: متوازي المستطيلات، المخروط، الهرم الناقص."""
    p.text((p.w // 2, 24), "انفرادات الأشكال المجسمة", 40, True, NAVY, "ma")
    p.text((p.w // 2, 82), "متوازي المستطيلات — المخروط — الهرم الناقص",
           26, False, STEEL, "ma")
    w3 = p.w // 3
    # ---- box net ----
    cx = w3 * 2 + w3 // 2
    cy = p.h * 0.52
    cw, ch, cd = 150, 96, 96
    p.rect([cx - cw, cy - ch, cx, cy], fill=PALE)
    p.rect([cx, cy - ch, cx + cw, cy], fill=(238, 244, 252))
    p.rect([cx - cw, cy - ch - cd, cx, cy - ch], fill=(232, 240, 250))
    p.rect([cx - cw, cy, cx, cy + cd], fill=(232, 240, 250))
    p.rect([cx - cw - cd, cy - ch, cx - cw, cy], fill=(238, 244, 252))
    p.rect([cx + cw, cy - ch, cx + cw + cd, cy], fill=(238, 244, 252))
    p.text((cx, cy + cd + 34), "متوازي المستطيلات", 30, True, NAVY, "ma")
    # ---- cone net ----
    cx = w3 + w3 // 2
    cy = p.h * 0.52
    p.poly([(cx, cy - 160), (cx - 130, cy + 90), (cx + 130, cy + 90)],
           fill=(240, 236, 228), outline=INK, width=4)
    p.ellipse([cx - 130, cy + 46, cx + 130, cy + 134], fill=(246, 243, 238),
              outline=INK, width=3)
    p.text((cx, cy + 176), "المخروط", 30, True, NAVY, "ma")
    # ---- truncated pyramid (frustum) net ----
    cx = w3 // 2
    cy = p.h * 0.52
    p.poly([(cx - 96, cy - 30), (cx - 44, cy - 30), (cx + 44, cy - 150),
            (cx + 96, cy - 150)], fill=PALE, outline=INK, width=4)
    p.poly([(cx - 96, cy + 40), (cx - 44, cy - 30), (cx + 96, cy - 150),
            (cx + 96, cy + 40)], fill=(238, 242, 250), outline=INK, width=3)
    p.text((cx, cy + 96), "الهرم الناقص", 30, True, NAVY, "ma")
    for i in (1, 2):
        p.line([(w3 * i, 130), (w3 * i, p.h - 110)], color=STEEL, width=2)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_scroll_saw(p):
    """منشار التخريم: الذراع، الفكان، القبضة، النصل والأسنان."""
    p.text((p.w // 2, 24), "منشار التخريم وأجزاؤه", 40, True, NAVY, "ma")
    cy = p.h * 0.54
    # arm (three sides of a rectangle)
    p.line([(p.w * 0.20, cy + 190), (p.w * 0.20, cy - 180),
            (p.w * 0.80, cy - 180), (p.w * 0.80, cy + 190)],
           color=INK, width=10)
    # jaws
    for x in (p.w * 0.20, p.w * 0.80):
        p.rect([x - 26, cy + 150, x + 26, cy + 240], fill=STEEL, outline=INK, width=4)
    # blade with teeth
    p.line([(p.w * 0.20, cy + 200), (p.w * 0.80, cy + 200)], color=STEEL, width=6)
    for x in range(int(p.w * 0.20) + 8, int(p.w * 0.80), 26):
        p.line([(x, cy + 206), (x + 13, cy + 224)], color=STEEL, width=3)
    # grip
    p.rect([p.w * 0.50 - 20, cy - 240, p.w * 0.50 + 20, cy - 170],
           fill=WOOD, outline=WOOD_D, width=4, radius=8)
    p.text((p.w * 0.50, cy - 272), "القبضة الخشبية", 30, True, NAVY, "ma")
    p.arrow((p.w * 0.50 + 90, cy - 210), (p.w * 0.50 + 26, cy - 205), BLUE, 4)
    p.label((p.w * 0.78, cy - 236), "الذراع المعدني", 28, PALE, BLUE)
    p.label((p.w * 0.78, cy + 300), "الفكان والمسماران المحوريان", 28, PALE, BLUE)
    p.label((p.w * 0.22, cy + 300), "النصل والأسنان متجهة إلى أسفل", 28, PALE, BLUE)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_vice_drill(p):
    """المسند والمثقاب: العلاقة بينهما أثناء التفريغ."""
    p.text((p.w // 2, 24), "المسند والمثقاب", 40, True, NAVY, "ma")
    bx, by = p.w * 0.60, p.h * 0.60
    # bench
    p.rect([bx - 320, by, bx + 320, by + 60], fill=WOOD, outline=WOOD_D, width=4)
    # the vice: a platform on a post
    p.rect([bx - 190, by - 30, bx + 30, by + 10], fill=STEEL, outline=INK, width=4)
    p.rect([bx - 92, by - 210, bx - 62, by - 30], fill=STEEL, outline=INK, width=4)
    p.ellipse([bx - 120, by - 250, bx - 34, by - 196], fill=STEEL, outline=INK, width=4)
    p.label((bx - 40, by - 268), "زاوية المسند", 28, PALE, BLUE)
    p.label((bx + 240, by - 60), "ماسكة مثبتة على المنضدة", 28, PALE, BLUE)
    # the drill
    dx = p.w * 0.24
    p.poly([(dx - 12, by - 250), (dx + 12, by - 250), (dx + 8, by - 40),
            (dx - 8, by - 40)], fill=STEEL, outline=INK, width=4)
    p.poly([(dx - 30, by - 40), (dx + 30, by - 40), (dx + 4, by + 10),
            (dx - 4, by + 10)], fill=(180, 190, 205), outline=INK, width=3)
    p.poly([(dx - 30, by - 250), (dx + 30, by - 250), (dx + 20, by - 300),
            (dx - 20, by - 300)], fill=WOOD, outline=WOOD_D, width=4)
    p.label((dx - 60, by - 330), "المثقاب والبرينة", 28, PALE, BLUE)
    p.arrow((dx + 40, by - 20), (bx - 110, by - 20), BLUE, 5)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_piercing(p):
    """الخشب المخرم: الثقب ثم إدخال النصل ثم النشر على الخطوط."""
    p.text((p.w // 2, 24), "التفريغ في الخشب", 40, True, NAVY, "ma")
    p.text((p.w // 2, 82), "ثقب داخلي — إدخال النصل — نشر على الخط", 26,
           False, STEEL, "ma")
    w3 = p.w // 3
    for i, name in enumerate(("ثقب", "إدخال النصل", "النشر")):
        cx = w3 * (2 - i) + w3 // 2
        cy = p.h * 0.54
        p.rect([cx - 130, cy - 90, cx + 130, cy + 90], fill=WOOD,
               outline=WOOD_D, width=5)
        for gx in range(int(cx - 118), int(cx + 120), 26):
            p.line([(gx, cy - 82), (gx + 14, cy - 82 + 4)], color=WOOD_D, width=2)
        p.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=PAPER,
                  outline=INK, width=3)
        if i >= 1:
            p.line([(cx + 12, cy), (cx + 118, cy - 62)], color=INK, width=5)
        if i == 2:
            p.line([(cx - 60, cy - 20), (cx - 10, cy + 26),
                    (cx + 60, cy - 30)], color=BLUE, width=4)
        p.text((cx, cy + 140), name, 32, True, NAVY, "ma")
        if i < 2:
            p.line([(w3 * (2 - i), 130), (w3 * (2 - i), p.h - 120)],
                   color=STEEL, width=2)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_wood_finish(p):
    """الصقل والطلاء: مراحل سطح الخشب."""
    p.text((p.w // 2, 24), "صقل الخشب وطلائه", 40, True, NAVY, "ma")
    p.text((p.w // 2, 82), "من الخشب الخشن إلى السطح اللامع", 26, False,
           STEEL, "ma")
    w3 = p.w // 3
    for i, (name, fill) in enumerate((("قبل الصقل", WOOD),
                                      ("بعد السنبادة", (206, 170, 122)),
                                      ("بعد الورنيش", (168, 128, 78)))):
        cx = w3 * (2 - i) + w3 // 2
        cy = p.h * 0.54
        p.rect([cx - 130, cy - 90, cx + 130, cy + 90], fill=fill,
               outline=WOOD_D, width=5)
        if i == 0:
            for gx in range(int(cx - 116), int(cx + 118), 20):
                p.line([(gx, cy - 76), (gx + 10, cy + 76)], color=WOOD_D,
                       width=3)
        if i == 1:
            for gx in range(int(cx - 116), int(cx + 118), 44):
                p.line([(gx, cy - 74), (gx + 4, cy + 74)], color=(186, 150, 104),
                       width=2)
        if i == 2:
            for k, al in ((0.55, (236, 220, 190)), (0.30, (250, 244, 232))):
                off = int(k * 60)
                p.line([(cx - 110 + off, cy + 78), (cx + 40 + off, cy - 78)],
                       color=al, width=16)
        p.text((cx, cy + 140), name, 32, True, NAVY, "ma")
        if i < 2:
            p.arrow((w3 * (2 - i) + 44, p.h * 0.54),
                    (w3 * (2 - i) - 34, p.h * 0.54), BLUE, 5)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_wood_burn(p):
    """حرق الخشب: المزارف على الجمر ثم تمريرها على الخطوط."""
    p.text((p.w // 2, 24), "حرق الخشب", 40, True, NAVY, "ma")
    # fire
    cx, cy = p.w * 0.30, p.h * 0.70
    for i, (rw, col) in enumerate(((90, (232, 140, 60)), (60, (240, 176, 86)),
                                   (30, (255, 214, 130)))):
        p.ellipse([cx - rw, cy - rw * 0.72, cx + rw, cy + rw * 0.72],
                  fill=col, outline=None, width=0)
    p.text((cx, cy + 130), "الجمر", 30, True, NAVY, "ma")
    # tools
    for i, ang in enumerate((-0.35, 0.0, 0.35)):
        x0, y0 = cx + 40, cy - 120 - i * 30
        x1, y1 = x0 + 260, y0 - 150 + i * 26
        p.line([(x0, y0), (x1, y1)], color=STEEL, width=10)
        p.line([(x1 - 40, y1 + 18), (x1 + 6, y1 - 14)], color=(120, 120, 120),
               width=12)
    p.label((p.w * 0.72, p.h * 0.28), "المزارف ذات المقابض الخشبية",
            28, PALE, BLUE)
    # board with burnt lines
    bx, by = p.w * 0.74, p.h * 0.74
    p.rect([bx - 210, by - 90, bx + 210, by + 90], fill=WOOD,
           outline=WOOD_D, width=5)
    for k in range(4):
        p.line([(bx - 180, by - 50 + k * 34), (bx + 180, by - 62 + k * 34)],
               color=(60, 40, 24), width=4)
    p.text((bx, by + 140), "خطوط محروقة", 30, True, NAVY, "ma")
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_potato_print(p):
    """الطباعة بالبطاطا: رسم معكوس، حفر، تغطية باللون، طبع."""
    p.text((p.w // 2, 24), "الطباعة بالبطاطا", 40, True, NAVY, "ma")
    steps = ("رسم معكوس", "حفر الأجزاء المحيطة", "تغطية باللون", "الطبع")
    w4 = p.w // 4
    for i, name in enumerate(steps):
        cx = w4 * (3 - i) + w4 // 2
        cy = p.h * 0.54
        p.ellipse([cx - 100, cy - 80, cx + 100, cy + 80], fill=(236, 196, 140),
                  outline=(176, 132, 82), width=4)
        if i == 0:
            p.line([(cx - 40, cy - 30), (cx + 40, cy - 30), (cx + 20, cy + 40),
                    (cx - 20, cy + 40), (cx - 40, cy - 30)], color=BLUE, width=4)
        elif i == 1:
            p.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=(236, 196, 140),
                      outline=(176, 132, 82), width=3)
        elif i == 2:
            p.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=BLUE,
                      outline=NAVY, width=3)
        else:
            p.rect([cx - 96, cy - 70, cx + 96, cy + 70], fill=PAPER,
                   outline=STEEL, width=3)
            p.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=BLUE,
                      outline=NAVY, width=3)
        p.text((cx, cy + 130), name, 30, True, NAVY, "ma")
        if i < 3:
            p.arrow((w4 * (3 - i) + 34, p.h * 0.54),
                    (w4 * (3 - i) - 30, p.h * 0.54), BLUE, 4)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_loom(p):
    """نول الكارتون: التسدية واللحمة."""
    p.text((p.w // 2, 24), "النول اليدوي: التسدية واللحمة", 40, True, NAVY, "ma")
    # loom board
    bx, by = p.w * 0.52, p.h * 0.50
    p.rect([bx - 300, by - 170, bx + 300, by + 170], fill=(238, 232, 220),
           outline=WOOD_D, width=5)
    for k in range(13):
        x = bx - 276 + k * 46
        p.line([(x, by - 160), (x, by + 160)], color=(198, 170, 130), width=3)
    # weft
    for k in range(6):
        y = by - 130 + k * 52
        p.line([(bx - 296, y), (bx + 296, y)], color=BLUE, width=5)
    p.label((bx - 330, by - 200), "خيط السدى", 28, PALE, BLUE)
    p.label((bx + 200, by + 210), "خيط اللحمة", 28, PALE, BLUE)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 22, False,
           GREY, "rs")
    p.frame()


def plate_history_timeline(p):
    """
    Horizontal axis of the dated events the lesson states.

    Each point carries the date EXACTLY as the source writes it, the name the
    clause names, and nothing else: an earlier draft printed whole clauses and
    the plate became unreadable.  No date, name or order is invented.
    """
    p.text((p.w // 2, 26), "الحركة التشكيلية في العراق — محطات", 40, True,
           NAVY, "ma")
    p.text((p.w // 2, 86), "التواريخ والأسماء كما وردت في الدرس", 24, False,
           STEEL, "ma")
    evs = getattr(p, "events", []) or []
    if not evs:
        p.text((p.w // 2, p.h // 2), "لا تواريخ في هذا الدرس", 32, True,
               STEEL, "ma")
        p.frame()
        return

    ax_y = int(p.h * 0.54)
    margin = 110
    p.line([(margin, ax_y), (p.w - margin, ax_y)], color=NAVY, width=6)

    n = len(evs)
    span = p.w - 2 * margin
    step = span / float(n - 1) if n > 1 else 0
    col_w = min(280, int(span / max(1, n)) - 12)
    for i, ev in enumerate(evs):
        x = (p.w - margin) - i * step          # RTL: earliest at the right
        up = i % 2 == 0
        p.ellipse([x - 11, ax_y - 11, x + 11, ax_y + 11], fill=GOLD,
                  outline=NAVY, width=4)
        if up:
            p.line([(x, ax_y - 12), (x, ax_y - 54)], color=NAVY, width=4)
            p.text((x, ax_y - 124), ev["date"], 30, True, NAVY, "ma")
            p.text_block(x, ax_y - 92, ev.get("who") or "", 24, col_w,
                         color=INK)
        else:
            p.line([(x, ax_y + 12), (x, ax_y + 54)], color=NAVY, width=4)
            p.text((x, ax_y + 74), ev["date"], 30, True, NAVY, "ma")
            p.text_block(x, ax_y + 106, ev.get("who") or "", 24, col_w,
                         color=INK)
    p.text((p.w - 34, p.h - 24),
           "محطات مستخرجة من نص الدرس — لا تواريخ مضافة",
           20, False, GREY, "rs")
    p.frame()



def plate_leather_bag(p):
    """حقيبة من الجلد: القطعة، التثقيب، الخيوط، والربط."""
    p.text((p.w // 2, 24), "حقيبة من الجلد", 40, True, NAVY, "ma")
    p.text((p.w // 2, 82), "قطعة الجلد ثم التثقيب ثم الربط", 24, False,
           STEEL, "ma")
    w4 = p.w // 4
    for i, name in enumerate(("القطعة", "التثقيب", "الخيوط", "الربط")):
        cx = w4 * (3 - i) + w4 // 2
        cy = p.h * 0.52
        p.poly([(cx - 96, cy - 70), (cx + 96, cy - 70), (cx + 96, cy + 60),
                (cx, cy + 104), (cx - 96, cy + 60)],
               fill=LEATH, outline=(96, 62, 40), width=4)
        if i == 1:
            import math
            for k in range(9):
                a = 2 * math.pi * k / 9
                x = cx + 86 * math.cos(a)
                y = cy + 4 + 70 * math.sin(a)
                p.ellipse([x - 7, y - 7, x + 7, y + 7], fill=PAPER,
                          outline=INK, width=2)
        if i == 2:
            for k in range(-2, 3):
                p.line([(cx + k * 32, cy - 64), (cx + k * 32, cy + 62)],
                       color=(228, 200, 150), width=4)
        if i == 3:
            p.line([(cx - 96, cy - 70), (cx + 96, cy - 70)], color=(228, 200, 150),
                   width=5)
            for k in range(-1, 2):
                p.ellipse([cx + k * 54 - 9, cy - 79, cx + k * 54 + 9, cy - 61],
                          fill=GOLD, outline=INK, width=2)
        p.text((cx, cy + 156), name, 30, True, NAVY, "ma")
        if i < 3:
            p.arrow((w4 * (3 - i) + 40, cy), (w4 * (3 - i) - 36, cy), BLUE, 4)
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 20, False,
           GREY, "rs")
    p.frame()



def plate_clay_sculpt(p):
    """أدوات النحت على الطين: المسند الخشبي، القضيب الحديدي، الأدوات."""
    p.text((p.w // 2, 24), "النحت على الطين", 40, True, NAVY, "ma")
    p.text((p.w // 2, 82), "المسند واللوحة والأدوات كما وردت في الدرس", 24,
           False, STEEL, "ma")
    # ---- left: rotary work on the iron support ----
    bx = p.w * 0.30
    by = p.h * 0.72
    p.rect([bx - 200, by, bx + 200, by + 40], fill=WOOD, outline=WOOD_D, width=4)
    p.line([(bx, by), (bx, by - 210)], color=STEEL, width=12)
    p.poly([(bx - 96, by - 210), (bx + 96, by - 280), (bx + 90, by - 420),
            (bx - 104, by - 360)], fill=CLAY, outline=CLAY_D, width=4)
    p.label((bx - 150, by + 70), "مسند خشبي", 26, PALE, BLUE)
    p.label((bx + 190, by - 240), "قطعة حديدية عمودية", 26, PALE, BLUE)
    p.arrow((bx + 150, by - 250), (bx + 16, by - 230), BLUE, 4)
    # ---- right: relief work on a board ----
    rx = p.w * 0.73
    p.rect([rx - 190, by - 300, rx + 190, by], fill=WOOD, outline=WOOD_D, width=5)
    p.poly([(rx - 120, by - 40), (rx - 60, by - 230), (rx + 90, by - 250),
            (rx + 130, by - 60)], fill=CLAY, outline=CLAY_D, width=4)
    p.label((rx - 96, by + 60), "لوحة خشبية للأعمال البارزة", 26, PALE, BLUE)
    # ---- tools strip ----
    ty = p.h - 150
    p.line([(110, ty), (p.w - 110, ty)], color=STEEL, width=2)
    for i, nm in enumerate(("سكين", "مِلعقة تشكيل", "أسلاك", "فرشاة")):
        x = p.w - 200 - i * 340
        p.line([(x, ty + 60), (x, ty - 60)], color=STEEL, width=8)
        p.ellipse([x - 16, ty - 78, x + 16, ty - 46], fill=STEEL, outline=INK,
                  width=3)
        p.text((x, ty + 96), nm, 26, True, NAVY, "ma")
    p.text((p.w - 34, p.h - 26), "إعادة تمثيل تعليمية مولّدة", 20, False,
           GREY, "rs")
    p.frame()


# --------------------------------------------------------------------------- #
# registry
# --------------------------------------------------------------------------- #
REGISTRY = {
    "plaster_mould": (plate_plaster_mould, 1600, 1000,
                      "القالب الجبسي وأجزاؤه"),
    "orange_mould": (plate_orange_mould, 1600, 860,
                     "مراحل قالب البرتقالة"),
    "cane_joints": (plate_cane_joints, 1600, 880,
                    "أساليب ربط القصب"),
    "paper_nets": (plate_paper_nets, 1600, 880,
                   "انفرادات الأشكال المجسمة"),
    "scroll_saw": (plate_scroll_saw, 1600, 980,
                   "منشار التخريم وأجزاؤه"),
    "vice_drill": (plate_vice_drill, 1600, 980,
                   "المسند والمثقاب"),
    "piercing": (plate_piercing, 1600, 880, "التفريغ في الخشب"),
    "wood_finish": (plate_wood_finish, 1600, 880, "صقل الخشب وطلاؤه"),
    "wood_burn": (plate_wood_burn, 1600, 880, "حرق الخشب"),
    "potato_print": (plate_potato_print, 1600, 860, "الطباعة بالبطاطا"),
    "loom": (plate_loom, 1600, 880, "النول اليدوي"),
    "leather_bag": (plate_leather_bag, 1600, 860, "حقيبة من الجلد"),
    "history_timeline": (plate_history_timeline, 1800, 940,
                         "محطات الحركة التشكيلية"),
}


def make(name, out_dir=None, events=None, title=None):
    """
    Render one plate; cached on (name, size, data) so an unchanged plate is
    never re-drawn while a changed one is never served stale.
    """
    fn, w, h, default_title = REGISTRY[name]
    out_dir = out_dir or CACHE
    os.makedirs(out_dir, exist_ok=True)
    payload = repr(events) if events else ""
    # the drawing code itself is part of the key: edit a plate and the stale
    # file can never be served again
    with open(os.path.abspath(__file__), "rb") as fh:
        code = hashlib.sha256(fh.read()).hexdigest()[:8]
    key = hashlib.sha256(("%s|%d|%d|%s|%s" % (name, w, h, code, payload))
                         .encode()).hexdigest()[:12]
    title = title or default_title
    path = os.path.join(out_dir, "%s_%s.png" % (name, key))
    if os.path.exists(path) and os.path.getsize(path) > 1000:
        return path, title
    p = Plate(w, h)
    p.events = events or []
    fn(p)
    p.save(path)
    return path, title


def build_all(out_dir=None):
    return {n: make(n, out_dir) for n in REGISTRY}
