"""Shared helpers for reading the Arabic DOCX sources of this project.

The module intentionally has no third-party dependency except ``python-docx``
so that both the content builder and the CI fidelity check can use it.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Iterable, Iterator, List, Optional

import docx
from docx.table import Table
from docx.text.paragraph import Paragraph

INVISIBLE = "\u200b\u200c\u200d\u200e\u200f\u2060\ufeff"
TATWEEL = "\u0640"

_ARABIC_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
_PUNCT = "،؛:,؟?!.…«»()[]{}\"'–—-|/\\*"


def normalize_ws(text: str) -> str:
    """Collapse whitespace and drop invisible bidi marks."""
    if text is None:
        return ""
    for ch in INVISIBLE:
        text = text.replace(ch, "")
    text = text.replace("\r", "\n")
    text = re.sub(r"[ \t\u00a0]+", " ", text)
    text = "\n".join(line.strip() for line in text.split("\n"))
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def polish(text: str) -> str:
    """Fix obvious DOCX layout artefacts without changing the wording."""
    text = normalize_ws(text)
    text = re.sub(r"[ \t]+([،؛:.؟!])", r"\1", text)
    text = re.sub(r"([،؛:.؟!])(?=[^\s،؛:.؟!])", r"\1 ", text)
    text = re.sub(r"([،؛:.؟!])\s+\1", r"\1", text)
    text = re.sub(r"\(\s+", "(", text)
    text = re.sub(r"\s+\)", ")", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    return text.strip()


def canon(text: str) -> str:
    """Canonical form used for source-fidelity comparison.

    Whitespace, punctuation, diacritics and letter variants are removed so
    that the check answers the question "is this wording present in the
    source" rather than "is it byte-identical".
    """
    text = unicodedata.normalize("NFKC", text or "")
    text = text.translate(_ARABIC_DIGITS)
    text = re.sub(r"[\u064b-\u0652\u0670\u06d6-\u06ed" + TATWEEL + "]", "", text)
    text = text.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    text = text.replace("ٱ", "ا").replace("ى", "ي").replace("ئ", "ي").replace("ؤ", "و")
    text = text.lower()
    out = []
    for ch in text:
        if ch.isspace():
            continue
        if ch in _PUNCT:
            continue
        if unicodedata.category(ch).startswith("P"):
            continue
        out.append(ch)
    return "".join(out)


def iter_body(document) -> Iterator[tuple]:
    """Yield ``("p", Paragraph)`` / ``("tbl", Table)`` in real body order."""
    for child in document.element.body.iterchildren():
        if child.tag.endswith("}p"):
            yield "p", Paragraph(child, document)
        elif child.tag.endswith("}tbl"):
            yield "tbl", Table(child, document)


def docx_text(document) -> str:
    """All text of a document (paragraphs + tables, body order)."""
    chunks: List[str] = []
    for kind, item in iter_body(document):
        if kind == "p":
            if item.text.strip():
                chunks.append(item.text)
        else:
            for row in item.rows:
                for cell in row.cells:
                    if cell.text.strip():
                        chunks.append(cell.text)
    return "\n".join(chunks)


# ---------------------------------------------------------------- topics ----

@dataclass
class Topic:
    title: str
    bullets: List[str] = field(default_factory=list)
    list_title: Optional[str] = None
    list_items: List[str] = field(default_factory=list)

    def as_dict(self) -> dict:
        return {
            "title": self.title,
            "bullets": self.bullets,
            "listTitle": self.list_title,
            "listItems": self.list_items,
        }


_TITLE_LIST_RE = re.compile(r"^(?:تعداد|عدد|اذكر)\s*[:：]\s*(.+)$")
_NUMBERED_RE = re.compile(r"^([0-9]+)\s*[-.)]\s*(.+)$")


def parse_topics(cell_text: str) -> List[Topic]:
    """Parse one summary-table cell into an ordered list of topics.

    The source cells follow a stable shape::

        عنوان الموضوع
        • نقطة
        • نقطة
        تعداد: عنوان القائمة
        1- عنصر
    """
    topics: List[Topic] = []
    current: Optional[Topic] = None
    in_list = False
    for raw in normalize_ws(cell_text).split("\n"):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("•"):
            body = polish(line.lstrip("•").strip())
            if current is None:
                current = Topic(title="")
                topics.append(current)
            if in_list:
                if body:
                    current.list_items.append(body)
            elif body:
                current.bullets.append(body)
            continue
        m = _TITLE_LIST_RE.match(line)
        if m and current is not None:
            current.list_title = polish(m.group(1))
            in_list = True
            continue
        m = _NUMBERED_RE.match(line)
        if m and current is not None:
            item = polish(m.group(2))
            if in_list:
                current.list_items.append(item)
            else:
                current.bullets.append(" ".join(part for part in (m.group(1) + "-", item) if part))
            continue
        # A plain line starts a new topic (or a wrapped continuation).
        if current is None or in_list:
            current = Topic(title=polish(line))
            topics.append(current)
            in_list = False
        elif not current.bullets and current.title:
            current.title = polish(current.title + " " + line)
        else:
            current = Topic(title=polish(line))
            topics.append(current)
            in_list = False
    return [t for t in topics if t.title or t.bullets]


# ------------------------------------------------------------- questions ----

_ANSWER_MARK = "الإجابة:"
_TF_RE = re.compile(r"^(?:[0-9]+\s*-\s*)?(.+?)\s*" + _ANSWER_MARK + r"\s*(صح|خطأ|صح\.|خطأ\.)")


def parse_questions(lines: Iterable[str]) -> List[dict]:
    """Parse the unit question bank paragraphs of the summary document."""
    result: List[dict] = []
    mode: Optional[str] = None
    pending_open: Optional[dict] = None
    index = 0
    for raw in lines:
        line = polish(raw)
        if not line:
            continue
        if line in ("صح وخطأ", "الاختيارات", "التعداد"):
            mode = {"صح وخطأ": "tf", "الاختيارات": "choice", "التعداد": "open"}[line]
            pending_open = None
            continue
        if mode == "tf":
            m = _TF_RE.match(line)
            if m:
                index += 1
                result.append({
                    "id": f"q{index}",
                    "kind": "trueFalse",
                    "prompt": polish(m.group(1)),
                    "answer": m.group(2).startswith("صح"),
                })
            continue
        if mode == "choice":
            if "|" not in line:
                continue
            parts = [polish(p) for p in line.split("|")]
            head = parts[0]
            prompt, first_option = _split_prompt_option(head)
            if prompt is None:
                continue
            index += 1
            result.append({
                "id": f"q{index}",
                "kind": "choice",
                "prompt": prompt,
                "options": [first_option] + parts[1:],
            })
            continue
        if mode == "open":
            if line.startswith(_ANSWER_MARK):
                if pending_open is not None:
                    pending_open["answer"] = polish(line[len(_ANSWER_MARK):])
                    pending_open = None
                continue
            m = _NUMBERED_RE.match(line)
            prompt = polish(m.group(2) if m else line)
            index += 1
            pending_open = {
                "id": f"q{index}",
                "kind": "open",
                "prompt": prompt,
                "answer": "",
            }
            result.append(pending_open)
            continue
    return result


def _split_prompt_option(head: str):
    """Split ``"1- ما الألوان الأساسية؟  الأصفر والأزرق والأحمر"``."""
    m = _NUMBERED_RE.match(head)
    body = m.group(2) if m else head
    q = body.find("؟")
    if q == -1:
        q = body.find("?")
    if q == -1:
        return None, None
    prompt = polish(body[: q + 1])
    option = polish(body[q + 1:]).lstrip("-. ")
    if not option:
        return None, None
    return prompt, option


def find_support(unit_text: str, option: str) -> Optional[str]:
    """Return the sentence of the unit text that supports ``option``."""
    target = canon(option)
    if not target:
        return None
    for sentence in re.split(r"[.؟!\n]", unit_text):
        if target in canon(sentence):
            return polish(sentence)
    return None
