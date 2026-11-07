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
      - space before Arabic punctuation removed
      - space after Arabic punctuation ensured
      - trailing/leading whitespace trimmed
    """
    t = text.replace("\u00a0", " ")
    t = re.sub(r"[ \t]{2,}", " ", t)
    t = re.sub(r"\s+([،؛؟!»،:])", r"\1", t)       # no space before punctuation
    t = re.sub(r"([،؛؟!»:])(?=[^\s،؛؟!»:])", r"\1 ", t)  # one space after
    t = re.sub(r"[ \t]+\n", "\n", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def classify_label(label: str, content: str) -> tuple[str, str, str | None]:
    """
    Decide how a row's label should be RENDERED, without touching the text.

    The source table splits many sentences across the label and content cells
    (110 of 200 rows): the "label" is really the opening fragment of the
    content paragraph.  We cannot repair that without inventing punctuation,
    so we keep every character exactly as extracted and only record a layout
    hint:

        'heading'  -> render the label as a bold sub-heading above the content
        'fragment' -> render label+content as ONE flowing paragraph

    Returns (label, content, hint).
    """
    if not label:
        return label, content, None
    shown = label if len(label) <= LABEL_COL_MAX_CHARS else label
    if len(label) <= LABEL_COL_MAX_CHARS:
        return label, content, "heading"
    return label, content, "fragment"


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
    for i, p in enumerate(ext.appendix):
        t = clean_field(p.text, i, "appendix")
        appendix.append({
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
        "media": [{"part": n, "size": len(b)} for n, b in ext.media],
        "absorbed": absorbed,
        "header_labels": header_labels,
    }
    return model, changes
