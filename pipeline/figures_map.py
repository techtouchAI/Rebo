"""
Stage 4.1 -- WHICH AXIS NEEDS WHICH PLATE.

This is the only place where a plate is bound to a topic.  The binding is a
rule, not a filename: an axis is matched by the teaching concepts its text
actually names, and the plate whose recipe draws exactly those concepts wins.

If nothing matches, the axis gets NO plate and the omission is recorded with a
reason (brief: «إذا تعذر إنتاج رسم دقيق، سجل ذلك»).  A failed or missing plate
never removes text: the axis is rendered without it.
"""
from __future__ import annotations

import os

from . import figurelib

# (plate name, concepts that must all be named by the axis, priority)
RULES = (
    ("clay_sculpt", ("طين",), 9),
    ("plaster_mould", ("قالب", "جبس"), 10),
    ("orange_mould", ("برتقال",), 9),
    ("cane_joints", ("قصب",), 8),
    ("paper_nets", ("ورق المقوى",), 7),
    ("paper_nets", ("انفراد",), 7),
    ("leather_bag", ("جلود",), 7),
    ("scroll_saw", ("منشار", "تخريم"), 9),
    ("vice_drill", ("مسند",), 8),
    ("vice_drill", ("مثقاب",), 8),
    ("piercing", ("تفريغ",), 6),
    ("piercing", ("تخريم",), 6),
    ("wood_finish", ("صقل",), 5),
    ("wood_finish", ("طلاء",), 5),
    ("wood_burn", ("حرق",), 6),
    ("potato_print", ("بطاطا",), 7),
    ("potato_print", ("طباعة",), 5),
    ("loom", ("نول",), 7),
    ("loom", ("نسيج",), 6),
    ("loom", ("تسدية",), 6),
)

# a plate is placed at most once per plan unless the topic really recurs
MAX_PER_PLATE = 2

CAPTION_TEMPLATE = "شكل توضيحي: %s"


def choose(axes):
    """
    Map axis number -> plate name.

    Deterministic: axes are visited in order, each takes its highest-priority
    rule that has not exhausted MAX_PER_PLATE.
    """
    used = {}
    out = {}
    for a in axes:
        text = " ".join(b["text"] for b in a["blocks"])
        text += " " + (a.get("title") or "")
        best = None
        for name, concepts, prio in RULES:
            if not all(c in text for c in concepts):
                continue
            if used.get(name, 0) >= MAX_PER_PLATE:
                continue
            # how central is this concept to the axis? the topic a passage is
            # actually about is named many times, a passing mention once.
            hits = sum(text.count(c) for c in concepts)
            title = a.get("title") or ""
            in_title = any(c in title for c in concepts)
            score = (int(in_title), hits, prio)
            if best is None or score > best[1]:
                best = (name, score)
        if best:
            out[a["n"]] = best[0]
            used[best[0]] = used.get(best[0], 0) + 1
    return out


def timeline_axis(axes, events):
    """The axis whose text carries the dates gets the timeline plate."""
    if len(events) < 3:
        return None
    for a in axes:
        text = " ".join(b["text"] for b in a["blocks"])
        hits = sum(1 for e in events if e["date"] in text)
        if hits >= max(2, len(events) - 2):
            return a["n"]
    return None


def resolve(teaching, timeline, out_dir=None):
    """
    Attach plate paths to the teaching view.

    Returns (attachments, log):
        attachments : {axis_no: [{'name','path','caption','kind'}]}
        log         : [{'axis','plate','status'}]  ('drawn' | 'failed' | 'cached')
    """
    axes = [a for s in teaching["sections"] for a in s["axes"]
            if a["n"] <= 40]
    mapping = choose(axes)
    tl_axis = timeline_axis(axes, timeline or [])
    if tl_axis is not None:
        mapping[tl_axis] = "history_timeline"

    attachments, log = {}, []
    for a in axes:
        name = mapping.get(a["n"])
        if not name:
            log.append({"axis": a["n"], "plate": None,
                        "status": "skipped", "reason": "no matching plate"})
            continue
        try:
            ev = timeline if name == "history_timeline" else None
            path, title = figurelib.make(name, out_dir=out_dir, events=ev)
        except Exception as exc:                       # never lose the text
            log.append({"axis": a["n"], "plate": name, "status": "failed",
                        "error": repr(exc)})
            continue
        if not os.path.exists(path) or os.path.getsize(path) < 1000:
            log.append({"axis": a["n"], "plate": name, "status": "failed",
                        "error": "empty plate"})
            continue
        attachments.setdefault(a["n"], []).append({
            "name": name,
            "path": path,
            "caption": CAPTION_TEMPLATE % title,
            "kind": "generated",
        })
        log.append({"axis": a["n"], "plate": name, "status": "drawn"})
    return attachments, log, mapping
