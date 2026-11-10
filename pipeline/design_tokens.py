"""
Design tokens for the weekly-plan template.

Every numeric value is DERIVED from a measurement, not chosen by taste;
provenance is recorded next to each block.

Design reference : تصميم الخطة.jpg   (1110 x 1417 px)
Page            : A4 portrait, 11906 x 16838 twips
Text area       : 10376 twips = 11906 - 2*765
Px -> twip      : 10376 / (1077-35 px) = 9.9577
"""

PAGE_W_TWIPS = 11906
PAGE_H_TWIPS = 16838
# A single top margin is required because OOXML margins are per-section, not
# per-page. The banner artwork lives in the FIRST-page header (690tw tall,
# anchored at the physical page edge), so the body must start below it.
MARGIN_TOP_TWIPS = 1560      # 1.08in  = banner 690 + gap 90 + header dist 0
MARGIN_BOTTOM_TWIPS = 1100   # 0.76in  = footer wave 659 + page line + gap
MARGIN_LEFT_TWIPS = 765      # 0.53in  (identical to the source files)
MARGIN_RIGHT_TWIPS = 765     # 0.53in
HEADER_DIST_TWIPS = 0
FOOTER_DIST_TWIPS = 57

TEXT_W_TWIPS = PAGE_W_TWIPS - MARGIN_LEFT_TWIPS - MARGIN_RIGHT_TWIPS   # 10376

# ---------------------------------------------------------------------------
# COLUMNS -- measured vertical rules in the design, y = 700..1200:
#     left edge 35 | 591 | 719 | 846 | right edge 1075      (width 1040 px)
#     content 556px | الموضوع 128px | gradient 127px | white 229px
# Reading the artwork right-to-left (RTL) the logical order is therefore:
#     0 white card 22.0% | 1 gradient card 12.2% | 2 الموضوع 12.3% | 3 content 53.5%
# `w:bidiVisual` makes index 0 render at the RIGHT edge, so this list is the
# LOGICAL order and the content column correctly lands on the physical left.
# ---------------------------------------------------------------------------
COL_RATIOS = [0.2202, 0.1221, 0.1231, 0.5346]      # logical order, RTL
COL_TITLES = ["الدرس", "معلومات", "الموضوع", ""]     # source strings only


def col_widths():
    out, used = [], 0
    for r in COL_RATIOS[:-1]:
        w = int(round(TEXT_W_TWIPS * r))
        out.append(w)
        used += w
    out.append(TEXT_W_TWIPS - used)
    assert sum(out) == TEXT_W_TWIPS, out
    return out


# COLOUR -- all sampled from تصميم الخطة.jpg
C_BANNER_NAVY = "001951"
C_RULE        = "182C51"
C_HEAD_FILL   = "CCE0FB"
C_HEAD_TEXT   = "102A56"
C_LABEL_FILL  = "DCEBFA"
C_TALL1_TOP   = "E3EBFE"
C_TALL1_BOT   = "F8FAFF"
C_CELL        = "FDFDFD"
C_TEXT        = "15243D"
C_META_FILL   = "E0EDFD"
C_GOLD        = "D1AD73"
C_ACCENT_BLUE = "1D4E89"

# TYPE
FONT_BODY    = "Noto Naskh Arabic"
FONT_HEADING = "Noto Naskh Arabic"
SZ_TITLE   = 32
SZ_META    = 22
SZ_HEADER  = 20
SZ_LABEL   = 20
SZ_BODY    = 20
SZ_APPX_H  = 22
SZ_FOOTER  = 16
SZ_RUNNING = 18

# The wave footer is decorative: it may not eat the writing area.  The band is
# capped at ~9mm on every page, page 1 included, so the frame closes the same
# way throughout the document.
FOOTER_MAX_H_TWIPS = 510
# The لوحة توضيحية figure is a portrait scan; 2.6in keeps it beside its caption
# instead of orphaning it onto a page of its own.
FIGURE_MAX_H_TWIPS = 2450
# the artwork is fitted to this width: wide enough to be legible, narrow enough
# that the caption and the source line stay with it on the same page
FIGURE_MAX_W_TWIPS = 6200
ROW_MIN_H_TWIPS  = 900
CELL_PAD_V_TWIPS = 57
CELL_PAD_H_TWIPS = 85

NAV_LABELS = {
    "الأهداف العامة", "الأهداف الخاصة", "الوسائل التعليمية",
    "المقدمـــــــة", "المقدمــــــة", "المقدمة",
}
LABEL_TOPIC = "الموضوع"
# The label column is 1277 twips wide (~0.89in). At 10pt Naskh it holds about
# 34 characters on two lines; anything longer is a sentence fragment in the
# source, not a heading, and is rendered as flowing text instead.
LABEL_COL_MAX_CHARS = 45

# The content column is 5547 twips (3.85in / 277pt). At 10pt Naskh with 1.2
# leading that is ~60 characters per line and ~45 lines of usable page. A single
# source row can hold 2,200+ characters, which no row can display at once, so
# long values are PARTITIONED (never rewritten) into consecutive rows that each
# fit a comfortable screen. Boundaries are chosen at existing bullets/newlines.
CHARS_PER_BODY_ROW = 1150
TITLE_TEXT = "الخطة الأسبوعية لمادة التربية الفنية"
FOOTER_PREFIX = "التربية الفنية"


# --------------------------------------------------------------------------- #
# TEACHING VIEW (condensed + illustrated plan)
# --------------------------------------------------------------------------- #
# The teaching view is generated, not copied, so no reference measurement exists
# for it.  These are derived the same way the rest of this file is: from the
# content column (5547tw), the body size (10pt) and the A4 print area.
C_PLATE_FILL = "F7FAFE"      # figure wells read as a quiet, recessed panel
C_AXIS_FILL = "E8F0FB"       # axis heading band
C_SECTION_FILL = "D5E5FA"    # part heading band (ثانياً / ثالثاً ...)
C_MUTED = "5A6B85"           # source/ekphrasis note under a plate
C_BANNER_NAVY = "001951"

SZ_AXIS = 23                 # axis heading, 11.5pt: one step over the body
SZ_SECTION = 26              # part heading, 13pt

# A plate is a full-width row: 10376tw minus the cell padding = 10206tw of art.
FIGURE_W_IN = 6.9            # 7.09in available inside the merged row
FIGURE_MAX_H_IN = 3.05       # a portrait-heavy plate still keeps its caption
FIGURE_ROW_MIN_TWIPS = 1400
SECTION_MIN_TWIPS = 760
PLATE_NOTE = ("رسم تعليمي مولّد لشرح الموضوع — ليس عملاً فنياً تاريخياً "
              "ولا يُنسب إلى فنان.")

# A table row taller than the print area cannot be laid out by Word, so long
# axis bodies are emitted as consecutive rows cut at the author's own sentence
# ends.  ~1100 characters fills roughly 20 lines of the content column.
ROW_TEXT_LIMIT = 1100
