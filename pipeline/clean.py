"""
Stage 2 — CLEANUP (logged, reversible, text-preserving).

Design rule enforced here
-------------------------
**We never delete content.**  Every transformation is either
  (a) whitespace normalisation, or
  (b) moving characters from one field to another.

The only *character-level* removals permitted are the six zero-width /
directional control characters that OOXML/Word inject during an RTL round
trip; they carry no glyph and their removal cannot lose information.

Each change emits a Change record so the final report can show before/after for
every single edit.
"""
from __future__ import annotations

import base64

import re
from dataclasses import dataclass, asdict
from typing import Iterable

from .design_tokens import NAV_LABELS, LABEL_COL_MAX_CHARS

# Characters that render as nothing but break text metrics, bidi runs, or diffs.
INVISIBLES = {
    "\u200b",  # zero width space
    "\u200c",  # zero width non-joiner
    "\u200d",  # zero width joiner
    "\u200e",  # left-to-right mark
    "\u200f",  # right-to-left mark
    "\ufeff",  # byte order mark
}


@dataclass
class Change:
    row: int
    field: str
    rule: str
    before: str
    after: str

    def to_dict(self):
        return asdict(self)


def strip_invisibles(text: str) -> tuple[str, list[str]]:
    found = [c for c in text if c in INVISIBLES]
    return "".join(c for c in text if c not in INVISIBLES), found


def normalise_arabic(text: str) -> str:
    """
    Normalise ONLY presentation-level noise.  Letters are never substituted,
    so the reader sees the same words the author wrote.
      - Arabic thousands/date separators kept as-is
      - 'ـ' tatweel kept (it is a deliberate authoring choice: المقدمــــــة)
      - multiple spaces collapsed
      - trailing/leading whitespace trimmed

    WHAT IS REMOVED (whitespace only, never letters, never punctuation):
      - NBSP  -> ordinary space   (two visually identical characters, one intent)
      - runs of spaces/tabs inside a line -> one space
      - trailing spaces at the end of a line
      - the cell's own leading/trailing whitespace

    WHAT IS NOT TOUCHED (the previous version got this wrong and *inserted*
    punctuation spacing -- e.g. ".»." became ".» ." , which is a content change):
      - spacing before/after punctuation is left exactly as the author wrote it.
    """
    t = text.replace("\u00a0", " ")
    t = re.sub(r"[ \t]{2,}", " ", t)
    t = re.sub(r"[ \t]+\n", "\n", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


ORDINAL_STARTS = ("أولاً", "أولًا", "ثانياً", "ثانيًا", "ثالثاً", "ثالثًا",
                  "رابعاً", "رابعًا", "خامساً", "خامسًا", "سادساً", "سادسًا")
SECTION_WORDS = ("اشغال", "أشغال", "الأشغال", "أعمال", "اعمال")
HEADING_MAX_WORDS = 6
HEADING_MAX_CHARS = 45


def looks_like_heading(label: str) -> bool:
    """
    True only for a title the SOURCE marks as a section heading.

    Evidence (all from the source, none invented): short (<=6 words / 45 chars,
    no mid-sentence full stop) OR starting with an ordinal or a section word.
    Length alone is NOT evidence -- that is what mislabelled «الأهداف» and
    «المحاور» as headings.
    """
    t = " ".join((label or "").split())
    if not t:
        return False
    if len(t) <= HEADING_MAX_CHARS and len(t.split()) <= HEADING_MAX_WORDS:
        if t.rstrip(".").find(".", 1) == -1:
            return True
    return t.split()[0] in ORDINAL_STARTS or t.split()[0] in SECTION_WORDS


def complete_truncated_bullets(appendix, body_text):
    """
    Finish a summary bullet the SOURCE cut with «…» -- from the source.

    The bullet stops mid-sentence because the author pasted only the first N
    characters of a sentence that exists, in full, in the same file.  We drop
    the «…» and append the next characters up to the source's own end of that
    sentence.  Nothing is paraphrased: every appended character is copied from
    the body where the bullet's own last words occur.

    Returns (new_text, appended).  appended == "" means no exact continuation
    was found, so the bullet is left EXACTLY as the source has it.
    """
    t = appendix or ""
    if not t.rstrip().endswith("\u2026"):
        return t, ""
    head = t.rstrip()[:-1]
    pos, key = -1, ""
    for n in (40, 32, 24, 18, 14, 10):
        cand = head[-n:]
        if not cand.strip():
            continue
        k = body_text.find(cand)
        if k >= 0:
            pos, key = k, cand
            break
    if pos < 0:
        return t, ""
    tail = body_text[pos + len(key):]
    stops = [i for i in (tail.find(". "), tail.find(" - "), tail.find("؛ "),
                         tail.find(":")) if i >= 0]
    if not stops:
        return t, ""
    addition = tail[:min(stops) + 1]
    if not addition.strip() or len(addition) > 200:
        return t, ""
    return head + addition, addition


def classify_label(label: str, content: str) -> tuple[str, str, str | None]:
    """
    Decide how a row's label should be RENDERED, without touching the text.

        'heading'  -> a title the source marks as a heading
        'fragment' -> prose split across the label and content cells: re-flow
                      both into ONE paragraph so the sentence reads as written
    """
    if not label:
        return label, content, None
    return label, content, ("heading" if looks_like_heading(label) else "fragment")


def _looks_like_nav(label: str) -> bool:
    return label.strip() in NAV_LABELS


def clean_document(ext, doc_id: str) -> tuple[dict, list[Change]]:
    """
    Turn an ExtDocument into the neutral intermediate model (stage 3).
    Returns (model, changes).
    """
    changes: list[Change] = []

    def clean_field(value, row_idx, field):
        original = value
        value, invisible = strip_invisibles(value)
        if invisible:
            changes.append(Change(row_idx, field, "strip-invisible-controls",
                                  original, value))
        n = normalise_arabic(value)
        if n != value:
            changes.append(Change(row_idx, field, "normalise-whitespace", value, n))
        return n

    # ---------------- meta cards ----------------
    meta = {}
    for i, lbl in enumerate(ext.meta_labels):
        meta["label_%d" % i] = clean_field(lbl, -1, "meta[%d]" % i)

    # ---------------- rows ----------------
    nav_rows, content_rows = [], []
    for idx, r in enumerate(ext.rows):
        c0 = clean_field(r.c0, idx, "c0")
        c1 = clean_field(r.c1, idx, "c1")
        c2 = clean_field(r.c2, idx, "c2")
        c3 = clean_field(r.c3, idx, "c3")

        if not c2 and not c3:
            # fully empty row: keep a record so row count is provably preserved
            changes.append(Change(idx, "row", "empty-row-retained", "", ""))
            nav_rows.append({"type": "empty", "label": "", "value": ""})
            continue

        # Rows that repeat the header label are not plan rows: they carry the
        # lesson identity.  The source already tells us which one is which via
        # c0 ('صفحات الدليل' vs empty), so we reuse the source's own strings and
        # invent nothing.
        if c2 == "الموضوع":
            kind = "guide_pages" if c0 else "lesson_identity"
            rule = "guide-pages-card" if c0 else "lesson-identity-card"
            changes.append(Change(idx, "c2", rule, c2 + "\x00" + c3, ""))
            nav_rows.append({"type": kind,
                             "label": c0 if c0 else c2,   # source string, not invented
                             "value": c3})
            continue

        if _looks_like_nav(c2):
            nav_rows.append({"type": "nav", "label": c2, "value": c3})
            continue

        # content row: label may be a heading OR a sentence fragment
        label, content, hint = classify_label(c2, c3)
        content_rows.append({
            "type": "content",
            "label": label,
            "value": content,
            "render": hint or "heading",
            "label_chars": len(label),
            "value_chars": len(content),
        })

    # ---------------- appendix ----------------
    appendix = []
    # the lesson body, used only to FINISH a bullet the source left with «…»
    body_text = " ".join("%s %s" % (r.c2, r.c3) for r in ext.rows)
    for i, p in enumerate(ext.appendix):
        t = clean_field(p.text, i, "appendix")
        if not t.strip() and not p.has_drawing:
            continue          # empty spacer paragraphs carry no content
        finished, added = complete_truncated_bullets(t, body_text)
        if added:
            changes.append(Change(i, "appendix", "complete-from-source", t, finished))
            t = finished
        appendix.append({
            "completed_from_source": bool(added),
            "text": t,
            "has_drawing": p.has_drawing,
            "style": p.style,
        })

    # ---------------- absorbed (proven, not lost) ----------------
    # 1. the raw header row of the plan table: it IS emitted, as the rendered
    #    table header -- recorded here so the diff can pair it.
    absorbed = [{"what": "table header row", "cells": list(ext.headers)}]
    # header labels that appear again as row labels ('الموضوع') are rendered
    # once, in the table header.
    header_labels = [ext.headers[2]] if len(ext.headers) > 2 else []
    # 2. the grade repeated on every data row: emitted once in the meta cards.
    absorbed.append({"what": "repeated grade column",
                     "cells": sorted({r.c1 for r in ext.rows if r.c1})})

    # ---------------- identity (verbatim source values only) ----------------
    header_grade = clean_field(ext.headers[1], -1, "headers[1]") if len(ext.headers) > 1 else ""
    grade = ""
    for r in ext.rows:
        g = clean_field(r.c1, -1, "c1")
        if g and g != header_grade:
            grade = g
            break

    # NOTE: the lesson/pages card texts live ONLY in nav_rows (single source of
    # truth).  The renderer promotes them to the header cards.  Duplicating
    # them here would double-count characters against the lossless contract.

    model = {
        "doc_id": doc_id,
        "source": ext.source_path,
        "title": clean_field(ext.title, -1, "title"),
        "subject": "التربية الفنية",
        "grade": grade,
        "meta": meta,
        "columns": ext.headers,
        "nav_rows": nav_rows,
        "content_rows": content_rows,
        "appendix": appendix,
        # The source images travel with the model so stage 5 can place them
        # back at the exact point the source had them (the لوحة توضيحية).
        # base64 keeps the model a single portable JSON file.
        "media": [{"part": n, "size": len(b),
                   "b64": base64.b64encode(b).decode("ascii")}
                  for n, b in ext.media],
        "absorbed": absorbed,
        "header_labels": header_labels,
    }
    return model, changes
