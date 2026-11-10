"""
Stage 3.6 -- DIDACTIC CONDENSATION (selection, never rewriting).

Why this stage exists
---------------------
The verbatim path (stage 2 -> render) is a facsimile contract: every character
of the teacher's guide reaches the page.  A weekly plan a *student* reads needs
the other contract: topic + the essential information, organised.  Both are
kept.  This module builds the second reading from the SAME neutral model:

    model['content_rows']  ->  model['teaching']['sections']

Rules that make the result provable
-----------------------------------
1.  SELECTION ONLY.  Every displayed string is a verbatim slice of the source
    cell(s) it came from.  No synonym, no paraphrase, no reordering.
    (asserted here; re-proved independently by tools/check_didactic.py)
2.  CONTINUITY.  The source cut single sentences across table cells
    («... على جميع اجزاء | التمثال الطيني وبعد أن | يتصلب الجبس ...»).  Consecutive
    cells that continue one another are rejoined before anything is classified,
    so no sentence is ever truncated and no fragment is ever shown as a title.
3.  CLOSED-SET EXCLUSION.  A unit leaves the plan only for one of four stated
    reasons (procedure / duplicate / meta / empty) and every exclusion is
    logged with its text and reason.  Nothing is "shortened".
4.  FLOOR RULE.  An axis that would collapse to a bare title re-admits the
    best discarded units, in source order, so «لا يتحول الموضوع إلى اسم».
5.  NO FILE-SPECIFIC LOGIC.  The rules are Arabic teaching-genre rules.
"""
from __future__ import annotations

import re
import unicodedata

# --------------------------------------------------------------------------- #
# 1. sentence units
# --------------------------------------------------------------------------- #
_ENDS = (".", "؟", "!", "\u2026")


def units(text):
    """
    Split a cell value into sentence units.

    Partition guarantee: "".join(units(t)) == t
    """
    text = "" if text is None else str(text)
    if not text:
        return []
    out, buf = [], []
    n = len(text)
    for i, ch in enumerate(text):
        buf.append(ch)
        if ch == "\n":
            out.append("".join(buf)); buf = []
        elif ch in _ENDS and i + 1 < n and text[i + 1] in " \n":
            out.append("".join(buf)); buf = []
    if buf:
        out.append("".join(buf))
    # a stump («.» or a lone word) is glued forward, never shown alone
    merged = []
    for u in out:
        if merged and len(merged[-1].strip()) < 28:
            merged[-1] = merged[-1] + u
        else:
            merged.append(u)
    assert "".join(merged) == text, "unit split altered the source text"
    return merged


# --------------------------------------------------------------------------- #
# 2. continuity across source cells
# --------------------------------------------------------------------------- #
ORDINALS = ("أولاً", "أولًا", "ثانياً", "ثانيًا", "ثالثاً", "ثالثًا",
            "رابعاً", "رابعًا", "خامساً", "خامسًا", "سادساً", "سادسًا",
            "سابعاً", "سابعًا", "ثامناً", "ثامنًا", "ًسادسا", "ًثالثا",
            "ًرابعا", "ًخامسا", "ًسابعا")
SECTION_WORDS = ("اشغال", "أشغال", "الأشغال", "أعمال", "اعمال")


def _flat(t):
    return " ".join((t or "").split())


def ends_unit(t):
    """Does this text end a sentence / conclude an enumeration?"""
    s = _flat(t)
    if not s:
        return False
    return s[-1] in ".\u2026؟!"


def ends_open(t):
    """A dash or a dangling connector: the next cell continues this sentence."""
    s = _flat(t).rstrip()
    if not s:
        return False
    if s.endswith(("-", "\u2013", "\u2014")):
        return True
    return s.rsplit(" ", 1)[-1] in ("أن", "ان", "من", "في", "على", "إلى",
                                    "الى", "مع", "و", "أو", "او", "التي",
                                    "الذي", "ثم", "حتى")


def is_title(label, prev_text=""):
    """
    True only when the SOURCE marks this cell as a teaching title.

    Positive evidence (any one): the cell opens with an ordinal or a section
    word, or it is short, has no terminal punctuation and no dangling
    connector at either end.
    """
    t = _flat(label)
    if not t:
        return False
    first = t.split()[0].lstrip("\u064b\u064c\u064d\u064e\u064f\u0650\u0651\u0652")
    if first in ORDINALS or first in SECTION_WORDS:
        return True
    if any(o in t for o in ORDINALS):
        return True
    if t[-1] in ".\u2026؟!:،؛-\u2013":
        return False
    if ends_open(t):
        return False
    if prev_text and ends_open(prev_text):
        return False          # previous cell left the sentence hanging
    return len(t) <= 48 and len(t.split()) <= 6


INLINE_HEADS = (
    "الأدوات", "الادوات", "المواد", "الخامات", "الهدف الخاص",
    "الاهداف السلوكية", "الأهداف السلوكية", "الأنموذج الأول",
    "الانموذج الاول", "الأنموذج الثاني", "الانموذج الثاني",
    "الأنموذج الثالث", "الانموذج الثالث", "عملية التسدية", "اللحمة",
)


_LEAD_ORD = re.compile(
    r"^(\s*(?:أولاً|أولًا|ثانياً|ثانيًا|ثالثاً|ثالثًا|رابعاً|رابعًا|خامساً|خامسًا"
    r"|سادساً|سادسًا|سابعاً|سابعًا|ثامناً|ثامنًا)\s*:?\s*[\u0621-\u064A \-]{0,34}?)\s"
    r"(?=(?:تختلف|تتم|هذه|هناك|يعتبر|تعد|يعد|سبق|تحدثنا|دراسة|دراسة|عمل|يمكن|تسمى)\b)")


def split_inline(text):
    """
    Cut one cell at the source's OWN sub-headings, which the author wrote
    inline. Nothing is edited: every returned piece is a slice, in order.
    """
    m = _LEAD_ORD.match(text)
    if m:
        head, rest = text[:m.end(1)], text[m.end(1):]
        if len(head) < 60:
            return [head] + split_inline(rest)
    marks = []
    for h in INLINE_HEADS + ORDINALS:
        k = 0
        while True:
            k = text.find(h, k)
            if k < 0:
                break
            if k == 0 or text[k - 1] in " .:.\n-":
                marks.append(k)
            k += len(h)
    marks = sorted(set(m for m in marks if m > 0))
    if not marks:
        return [text]
    out, prev = [], 0
    for m in marks:
        if m - prev < 40:
            continue
        out.append(text[prev:m])
        prev = m
    out.append(text[prev:])
    assert "".join(out) == text
    return [o for o in out if o.strip()]


def streams(rows):
    """
    Split the plan into teaching axes.

    A new axis starts only where the source provably starts something new:
    its label is a real title AND the previous cell closed its sentence.
    Anything else is a continuation and is joined to the axis before it, which
    is what removes the truncated half-sentences the earlier version printed
    as headings.

    Returns [{'title','parts','rows','text'}].
    """
    out = []
    for i, r in enumerate(rows):
        label = r.get("label") or ""
        value = r.get("value") or ""
        prev = out[-1] if out else None
        joins = bool(prev) and not is_title(label, prev["tail"])
        if joins:
            prev["parts"].append(label)
            prev["parts"].append(value)
            prev["rows"].append(i)
            prev["tail"] = value or prev["tail"]
        else:
            out.append({"title": label if is_title(label, prev["tail"] if prev else "") else "",
                        "parts": [label, value],
                        "rows": [i],
                        "tail": value})
    for s in out:
        s["text"] = " ".join(p for p in s["parts"] if p)
    return out


# --------------------------------------------------------------------------- #
# 3. classification (closed sets, first-match priority)
# --------------------------------------------------------------------------- #
PROCEDURE_STARTS = (
    "نبدأ", "نقوم", "نضع", "نأخذ", "نحضر", "نقطع", "نلصق", "نربط", "نثقب",
    "نغمس", "نستخدم", "نثبت", "نرسم", "ننقل", "نطلي", "نمسح", "نصب", "نمزج",
    "نحدث", "نفصل", "ندهن", "نعيد", "نشكل", "نمرر", "نلف", "نصنع", "نترك",
    "نزيل", "نشد", "نسكب", "خذ", "اربط", "اضف", "أضف", "استخدم", "ضع",
    "املأ", "املا", "قص", "الصق", "افرك", "احضر", "أحضر", "ادخل", "أدخل",
)
PROCEDURE_MARKS = ("خطوات العمل", "الخطوات الآتية", "طريقة العمل",
                   "طريقة الصب", "خطوات التصنيع")
DEFINITION_MARKS = ("هو ", "هي ", "يعني", "تعني", "عبارة عن", "يُعرف", "تعريف",
                    "مفهوم", "يسمى", "تسمى", "يطلق", "وهو ", "وهي ")
MATERIAL_MARKS = ("الخامات", "خامات", "الأدوات", "الادوات", "أدوات", "المواد",
                  "الخامة", "منشار", "مثقاب", "مسند")
ENUM_MARKS = ("أنواع", "انواع", "أقسام", "اقسام", "منها", "تنقسم", "يشمل",
              "تشمل", "أشكال", "صنوف", "ينقسم", "عدة", "منها")
HISTORY_MARKS = ("جمعية", "جماعة", "مدرسة", "الفنان", "الرسام", "النحات",
                 "أكاديمية", "معهد", "معرض", "الطلبة", "الموفودين", "تأسست",
                 "تأسس", "ظهرت")
PROPERTY_MARKS = ("يتميز", "تمتاز", "يتصف", "تتصف", "خصائص", "صفات", "يعد",
                  "تعد", "الأهداف", "الهدف", "قادراً", "أن يتعرف", "أن يعرف",
                  "مهارة", "مهارات")
META_MARKS = ("يرجى", "رجاءً", "ملاحظة", "المرجو", "يقوم المدرس",
              "المدرس بالعمل", "خاصة بالطالبات")

REASON_PROCEDURE = "تفاصيل تنفيذية/خطوات صناعة"


def is_part_heading(t):
    """«ثانياً : اشغال القصب» -- a part of the plan, written by the author."""
    s = _flat(t)
    if len(s) > 60:
        return False
    first = s.split()[0].rstrip(":،")
    return first in ORDINALS
REASON_DUPLICATE = "تكرار لفظي لمعلومة معروضة"
REASON_META = "توجيه للمعلم لا يخدم فهم الطالب"
REASON_EMPTY = "وحدة فارغة"


_STEP_NO = re.compile(r"^\s*[\(\[]?[\u0660-\u0669\d]{1,2}\s*[\)\].\-:]?\s*\S")


def classify(u):
    """(kind, score, drop_reason_or_None)."""
    t = _flat(u)
    if _STEP_NO.match(t) and len(t) > 24:
        return "procedure", 0, REASON_PROCEDURE
    if not t:
        return "empty", 0, REASON_EMPTY
    head = t[:24]
    for m in META_MARKS:
        if head.startswith(m) or (" " + m + " :") in head:
            return "meta", 0, REASON_META
    body = t[2:] if t.startswith("\u0648 ") else t
    starts_proc = any(body.startswith(m) for m in PROCEDURE_STARTS)
    n_proc = sum(1 for m in PROCEDURE_STARTS if t.startswith(m)) or \
        int(starts_proc)
    if is_part_heading(t):
        return "part", 5, None
    if any(m in t for m in PROCEDURE_MARKS):
        return "procedure", 0, REASON_PROCEDURE
    if any(m in t for m in DEFINITION_MARKS) and not starts_proc:
        return "definition", 3, None
    if any(m in t for m in HISTORY_MARKS) and len(t) >= 40 and not starts_proc:
        return "history", 3, None
    if any(m in t for m in MATERIAL_MARKS) and not starts_proc:
        return "material", 2, None
    if any(m in t for m in ENUM_MARKS) and not starts_proc:
        return "enum", 2, None
    if any(m in t for m in PROPERTY_MARKS) and not starts_proc:
        return "property", 2, None
    if starts_proc or (n_proc and len(t) < 40):
        return "procedure", 0, REASON_PROCEDURE
    if len(t) >= 45:
        return "prose", 1, None
    return "procedure", 0, REASON_PROCEDURE


# --------------------------------------------------------------------------- #
# 4. near-duplicate detection
# --------------------------------------------------------------------------- #
_STOP = {"في", "من", "على", "الى", "إلى", "عن", "أن", "ان", "التي", "الذي",
         "هو", "هي", "هذا", "هذه", "ذلك", "مع", "او", "أو", "و", "ثم", "قد",
         "كان", "كانت", "ما", "لا", "به", "بها", "له", "لها", "كل", "بين"}


def _tokens(t):
    t = "".join(c for c in t if not unicodedata.combining(c))
    return {w for w in re.findall(r"[\u0621-\u064A]{2,}", t) if w not in _STOP}


def _similar(a, b):
    A, B = _tokens(a), _tokens(b)
    if not A or not B:
        return 0.0
    return len(A & B) / float(len(A | B))


# --------------------------------------------------------------------------- #
# 5. axis building
# --------------------------------------------------------------------------- #
AXIS_MIN_UNITS = 2
AXIS_MIN_CHARS = 140


def build_axis(stream, number):
    title = stream["title"]
    text = stream["text"]

    us = []
    _us_all = []
    for piece in split_inline(text):
        us.extend(units(piece))
    scored = []
    for u in us:
        kind, score, reason = classify(u)
        scored.append({"text": u, "kind": kind, "score": score,
                       "reason": reason})

    kept, dropped = [], []
    for s in scored:
        if s["reason"]:
            dropped.append({"text": s["text"], "reason": s["reason"]})
            continue
        if any(_similar(s["text"], k["text"]) > 0.82 for k in kept):
            dropped.append({"text": s["text"], "reason": REASON_DUPLICATE})
            continue
        kept.append(s)

    # ---- floor rule: never reduce an axis to a bare title -------------------
    def body_chars(ks):
        return sum(len(k["text"]) for k in ks if k["text"].strip() != title)

    if len(kept) < AXIS_MIN_UNITS or body_chars(kept) < AXIS_MIN_CHARS:
        pool = [d for d in dropped if d["reason"] == REASON_PROCEDURE]
        pool.sort(key=lambda d: -len(d["text"]))
        for cand in pool:
            if len(kept) >= AXIS_MIN_UNITS and body_chars(kept) >= AXIS_MIN_CHARS:
                break
            kept.append({"text": cand["text"], "kind": "procedure",
                         "score": 0, "floor": True})
            dropped = [d for d in dropped if d is not cand]
        order = {id(s): i for i, s in enumerate(scored)}
        kept.sort(key=lambda k: order[id(text_and_id(scored, k))] if False
                  else text_order(scored, k))

    # An axis the source never titled still needs a topic line.  Its own first
    # sentence becomes the heading (verbatim) and leaves the body, so nothing is
    # said twice and nothing is invented.
    if not title and kept:
        cand = kept[0]["text"].strip()
        # only a genuinely short opening can serve as the topic line: the label
        # column holds ~34 characters, and a title that does not fit would have
        # to be truncated -- which is forbidden.
        if len(cand) <= 44 and cand[-1:] in ".\u2026":
            title = cand
            kept = kept[1:]
        elif len(cand) <= 34:
            title = cand
            kept = kept[1:]

    # ---- a part heading inside the axis (the author's own «ثانياً : ...») ---
    part_idx = [i for i, k in enumerate(kept) if k.get("kind") == "part"]
    part = ""
    if part_idx:
        part = _flat(kept[part_idx[0]]["text"])
        kept = [k for i, k in enumerate(kept) if i not in set(part_idx)]

    blocks = []
    for k in kept:
        t = k["text"].strip()
        if not t:
            continue
        if t == title or t == part:
            continue                      # the title is the block heading
        bullet = t.startswith(("\u2022", "-", "\u2013"))
        blocks.append({"kind": "bullet" if bullet else "para", "text": t})

    return {
        "n": number,
        "title": title,
        "part": part,
        "is_part": bool(part),
        "blocks": blocks,
        "dropped": dropped,
        "kept_chars": sum(len(b["text"]) for b in blocks),
        "source_chars": len(text),
        "rows": stream["rows"],
    }


def text_order(scored, k):
    for i, s in enumerate(scored):
        if s is k:
            return i
        if s["text"] == k["text"]:
            return i
    return 0


def text_and_id(scored, k):     # pragma: no cover - kept for clarity
    return k


def condense(model):
    """
    Build the teaching view.  `model['content_rows']` is left untouched.
    """
    sts = streams(model.get("content_rows", []))
    axes = []
    for i, s in enumerate(sts, start=1):
        a = build_axis(s, i)
        axes.append(a)

    sections, cur = [], None
    for a in axes:
        if a.get("is_part"):
            # the author's part heading is shown once, as the section band
            cur = {"title": a["part"], "axes": []}
            sections.append(cur)
            if _flat(a["title"]) == _flat(a["part"]):
                a["title"] = ""
            a["part"] = ""
        if cur is None:
            cur = {"title": "", "axes": []}
            sections.append(cur)
        cur["axes"].append(a)

    teaching = {
        "sections": sections,
        "stats": _stats(axes, sections),
    }
    model["teaching"] = teaching
    return teaching


def _stats(axes, sections):
    from collections import Counter
    by = Counter()
    dropped = 0
    for a in axes:
        for d in a["dropped"]:
            by[d["reason"]] += 1
            dropped += 1
    keeper = sum(a["kept_chars"] for a in axes)
    src = sum(a["source_chars"] for a in axes) or 1
    return {
        "sections": len(sections),
        "axes": sum(len(s["axes"]) for s in sections),
        "axes_with_body": sum(1 for a in axes if a["blocks"]),
        "kept_chars": keeper,
        "source_chars": src,
        "ratio": round(keeper / float(src), 3),
        "dropped_units": dropped,
        "by_reason": dict(by),
    }


# --------------------------------------------------------------------------- #
# 6. timeline extraction (never invented: parsed from the lesson text)
# --------------------------------------------------------------------------- #
# The source writes Hijri/Gregorian years with the Arabic-Indic digits in
# reversed order («٩٣٩١ م» = 1939).  Parsing here does not "correct" the file:
# it only orders the events the text already states.
_YEAR = re.compile(r"([\u0660-\u0669]{4})\s*م")


def _y4(digits):
    """Arabic-Indic 4-digit string as the text writes it -> int (reversed)."""
    d = [str("٠١٢٣٤٥٦٧٨٩".index(c)) for c in digits]
    return int("".join(reversed(d)))


def extract_timeline(text):
    """
    Pull «<year> م» anchors out of the lesson text, in text order, keeping the
    clause that states each one.  Returns [] when the text has no dates.
    """
    out = []
    for m in _YEAR.finditer(text):
        try:
            y = _y4(m.group(1))
        except ValueError:
            continue
        if not (1900 <= y <= 2025):
            continue
        # the sentence this date belongs to
        start = max(text.rfind(".", 0, m.start()), text.rfind("،", 0, m.start()))
        clause = text[start + 1:m.end()].strip(" .،-")
        out.append({"year": y, "digits": m.group(1), "clause": clause})
    # de-duplicate on the year, keep first occurrence
    seen, uniq = set(), []
    for e in out:
        if e["year"] in seen:
            continue
        seen.add(e["year"])
        uniq.append(e)
    return uniq


_NAME = re.compile(
    r"(جماعة\s+[\u0621-\u064A]{3,20}(?:\s+[\u0621-\u064A]{2,20}){0,3}"
    r"|جمعية\s+[\u0621-\u064A]{3,20}(?:\s+[\u0621-\u064A]{2,20}){0,3}"
    r"|معهد\s+[\u0621-\u064A]{3,20}(?:\s+[\u0621-\u064A]{2,20}){0,3}"
    r"|أكاديمية\s+[\u0621-\u064A]{3,20}(?:\s+[\u0621-\u064A]{2,20}){0,3}"
    r"|الفنان\s+[\u0621-\u064A]{3,18}(?:\s+[\u0621-\u064A]{3,18})?)")


def timeline_events(text, window=150):
    """
    Ordered timeline built ONLY from dates the lesson text states.

    Each point keeps the date exactly as the source writes it («٩٣٩١ م»), the
    clause that carries it, and any proper name found in that clause.  Sorted by
    the parsed year — that is an axis of time, not an edit of the text.
    """
    m_all = list(_YEAR.finditer(text))
    out = []
    for k, m in enumerate(m_all):
        try:
            y = _y4(m.group(1))
        except ValueError:
            continue
        if not (1900 <= y <= 2025):
            continue
        # the clause: back to the previous sentence end, forward to a window
        start = max(text.rfind(". ", 0, m.start()),
                    text.rfind("\n", 0, m.start())) + 1
        seg = text[start:m.start() + window]
        seg = seg.split(". ")[0].strip(" .،-:")
        name = ""
        nm = _NAME.search(seg)
        if nm:
            name = nm.group(1).strip()
        digits = m.group(1)
        what = seg
        for pre in ("وفي عام ", "ويعود", "عام ", "سنة ", "وفي ", "و "):
            if what.startswith(pre):
                what = what[len(pre):]
        what = what.replace(digits + " م", "").strip(" .،-:")
        out.append({"date": digits + " م", "year": y,
                    "what": what[:72], "who": name})
    out.sort(key=lambda d: d["year"])
    return out


TIMELINE = []
