"""
Stage 1 — EXTRACTION (read-only).

Reads a source .docx and produces a structure that contains *every* character
present in the document, tagged with where it came from.  Nothing is cleaned,
dropped or reordered here; that is stage 2's job and is fully auditable.

Source layout (verified on all 13 lesson files):

    body
      tbl[0] 1x1  -> title text ("الخطة الأسبوعية لمادة التربية الفنية")
      p   (blank)
      tbl[1] 1x3  -> meta cards: معلومات | الصف | الدرس
      p   (blank)
      tbl[2] Nx4  -> the actual plan
                     c0 : 'معلومات' header then 'صفحات الدليل'/''  (mostly empty)
                     c1 : grade, repeated on every row
                     c2 : row label ('الأهداف العامة', 'المقدمة', or a fragment)
                     c3 : row content
      p ...       -> appendix: lesson summary, questions, answer key, caption
      sectPr
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field, asdict
from typing import Any

import docx
from docx.table import Table
from docx.text.paragraph import Paragraph


@dataclass
class ExtRow:
    kind: str                 # 'header' | 'data'
    c0: str
    c1: str
    c2: str
    c3: str
    cells_raw: list = field(default_factory=list)


@dataclass
class ExtParagraph:
    text: str
    has_drawing: bool
    style: str
    index: int


@dataclass
class ExtDocument:
    source_path: str
    title: str
    meta_labels: list           # 3 strings from tbl[1]
    headers: list               # 4 strings from tbl[2] header row
    rows: list                  # list[ExtRow]  (data rows only)
    appendix: list              # list[ExtParagraph] after tbl[2]
    media: list                 # list of (partname, bytes)
    section: dict
    # source cells that are intentionally NOT re-emitted verbatim; recorded so
    # the lossless contract can prove they are accounted for, not lost.
    absorbed: list = field(default_factory=list)

    def to_dict(self):
        d = asdict(self)
        d["media"] = [(n, len(b)) for n, b in self.media]
        return d


def extract(path: str) -> ExtDocument:
    d = docx.Document(path)
    body = d.element.body

    tables, paras = [], []
    for child in body.iterchildren():
        tag = child.tag.split("}")[1]
        if tag == "tbl":
            tables.append(Table(child, d))
        elif tag == "p":
            paras.append(Paragraph(child, d))

    if len(tables) < 3:
        raise ValueError("%s: expected 3 tables, found %d" % (path, len(tables)))

    # ---- title -------------------------------------------------------------
    title_cell = tables[0].rows[0].cells[0]
    title = title_cell.text.strip()

    # ---- meta cards --------------------------------------------------------
    meta_labels = [c.text.strip() for c in tables[1].rows[0].cells]

    # ---- main plan table ---------------------------------------------------
    plan = tables[2]
    headers = [c.text.strip() for c in plan.rows[0].cells]
    rows = []
    for ri, r in enumerate(plan.rows):
        cells = list(r.cells)
        vals = [c.text for c in cells]
        rows.append(ExtRow(
            kind="header" if ri == 0 else "data",
            c0=vals[0].strip(),
            c1=vals[1].strip(),
            c2=vals[2].strip(),
            c3=vals[3].strip(),
            cells_raw=[[p.text for p in c.paragraphs] for c in cells],
        ))
    data_rows = [r for r in rows if r.kind == "data"]

    # ---- appendix ----------------------------------------------------------
    appendix = []
    seen_third_table = 0
    for i, child in enumerate(body.iterchildren()):
        tag = child.tag.split("}")[1]
        if tag == "tbl":
            seen_third_table += 1
            continue
        if tag != "p" or seen_third_table < 3:
            continue
        p = Paragraph(child, d)
        has_drawing = "<w:drawing>" in child.xml
        if p.text.strip() or has_drawing:
            appendix.append(ExtParagraph(
                text=p.text,
                has_drawing=has_drawing,
                style=(p.style.name if p.style is not None else "Normal"),
                index=i,
            ))

    # ---- media -------------------------------------------------------------
    media = []
    for part in d.part.package.iter_parts():
        if "/media/" in str(part.partname):
            media.append((str(part.partname), part.blob))

    # ---- section -----------------------------------------------------------
    s = d.sections[0]
    section = {
        "page_w": s.page_width, "page_h": s.page_height,
        "top": s.top_margin, "bottom": s.bottom_margin,
        "left": s.left_margin, "right": s.right_margin,
    }

    return ExtDocument(
        source_path=path,
        title=title,
        meta_labels=meta_labels,
        headers=headers,
        rows=data_rows,
        appendix=appendix,
        media=media,
        section=section,
    )


def full_text(ext: ExtDocument) -> str:
    """Every character of the document, in reading order, for diffing."""
    parts = [ext.title, " ".join(ext.meta_labels), " ".join(ext.headers)]
    for r in ext.rows:
        parts.extend([r.c0, r.c1, r.c2, r.c3])
    for p in ext.appendix:
        parts.append(p.text)
    return "\n".join(parts)


def normalize_for_diff(text: str) -> str:
    """
    Whitespace/zero-width-insensitive form used by the lossless contract.
    Deliberately does NOT touch Arabic letters, digits, or punctuation.
    """
    text = text.replace("\u200f", "").replace("\u200e", "")
    text = text.replace("\u00a0", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s*\n\s*", "\n", text)
    return text.strip()
