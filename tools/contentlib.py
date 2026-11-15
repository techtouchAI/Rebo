"""Shared helpers for reading the Arabic DOCX sources of this project.

The module has zero third-party dependencies (using Python's standard
``zipfile`` and ``xml.etree.ElementTree``) so both ``tools/build_content.py``
and ``tools/verify_content.py`` run identically in minimal environments and CI.
"""

from __future__ import annotations

import re
import unicodedata
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Optional, Tuple

INVISIBLE = "\u200b\u200c\u200d\u200e\u200f\u2060\ufeff"
TATWEEL = "\u0640"

_ARABIC_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
_PUNCT = "،؛:,؟?!.…«»()[]{}\"'–—-|/\\*"

_W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
_R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
_NS = {"w": _W_NS, "r": _R_NS}


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


def to_ascii_digits(text: str) -> str:
    return (text or "").translate(_ARABIC_DIGITS)


# ------------------------------------------------------ lightweight DOCX ----


@dataclass
class DocxRun:
    text: str
    underline: Optional[str] = None
    size: Optional[str] = None
    bold: Optional[bool] = None
    color: Optional[str] = None


@dataclass
class DocxParagraph:
    text: str
    runs: List[DocxRun] = field(default_factory=list)
    images: List[str] = field(default_factory=list)
    has_spacing_before: bool = False


def read_docx_paragraphs_and_tables(path: Path) -> List[tuple]:
    """Read paragraphs and tables from a DOCX in body order using stdlib XML."""
    blocks: List[tuple] = []
    with zipfile.ZipFile(path) as archive:
        rels: Dict[str, str] = {}
        if "word/_rels/document.xml.rels" in archive.namelist():
            rels_xml = ET.fromstring(archive.read("word/_rels/document.xml.rels"))
            for rel in rels_xml:
                rels[rel.attrib["Id"]] = rel.attrib["Target"]
        doc_xml = ET.fromstring(archive.read("word/document.xml"))
        body = doc_xml.find("w:body", _NS)
        if body is None:
            return blocks

        def parse_p(p_elem) -> DocxParagraph:
            pPr = p_elem.find("w:pPr", _NS)
            has_before = False
            if pPr is not None:
                sp = pPr.find("w:spacing", _NS)
                if sp is not None and f"{{{_W_NS}}}before" in sp.attrib:
                    has_before = True
            runs: List[DocxRun] = []
            images: List[str] = []
            parts: List[str] = []
            for r in p_elem.findall("w:r", _NS):
                rPr = r.find("w:rPr", _NS)
                u = None
                sz = None
                b = None
                col = None
                if rPr is not None:
                    u_el = rPr.find("w:u", _NS)
                    if u_el is not None:
                        u = u_el.attrib.get(f"{{{_W_NS}}}val")
                    sz_el = rPr.find("w:sz", _NS)
                    if sz_el is not None:
                        sz = sz_el.attrib.get(f"{{{_W_NS}}}val")
                    b_el = rPr.find("w:b", _NS)
                    if b_el is not None:
                        b = b_el.attrib.get(f"{{{_W_NS}}}val", "1") != "0"
                    col_el = rPr.find("w:color", _NS)
                    if col_el is not None:
                        col = col_el.attrib.get(f"{{{_W_NS}}}val")
                r_parts: List[str] = []
                for elem in r.iter():
                    tag = elem.tag.split("}")[-1]
                    if tag == "t" and elem.text:
                        r_parts.append(elem.text)
                    elif tag == "br":
                        r_parts.append("\n")
                    elif tag == "tab":
                        r_parts.append("\t")
                    elif tag == "blip":
                        rid = elem.attrib.get(f"{{{_R_NS}}}embed")
                        if rid:
                            images.append(rels.get(rid, rid))
                    elif tag == "imagedata":
                        rid = elem.attrib.get(f"{{{_R_NS}}}id")
                        if rid:
                            images.append(rels.get(rid, rid))
                r_text = "".join(r_parts)
                if r_text:
                    runs.append(DocxRun(text=r_text, underline=u, size=sz, bold=b, color=col))
                    parts.append(r_text)
            return DocxParagraph(
                text="".join(parts).strip(),
                runs=runs,
                images=images,
                has_spacing_before=has_before,
            )

        for child in body:
            tag = child.tag.split("}")[-1]
            if tag == "p":
                blocks.append(("p", parse_p(child)))
            elif tag == "tbl":
                rows: List[List[str]] = []
                for tr in child.findall("w:tr", _NS):
                    cells: List[str] = []
                    for tc in tr.findall("w:tc", _NS):
                        cell_paras = [parse_p(p).text for p in tc.findall(".//w:p", _NS)]
                        cells.append("\n".join(p for p in cell_paras if p))
                    rows.append(cells)
                blocks.append(("tbl", rows))
    return blocks


def read_docx_plain_text(path: Path) -> str:
    chunks: List[str] = []
    for kind, item in read_docx_paragraphs_and_tables(path):
        if kind == "p":
            if item.text:
                chunks.append(item.text)
        else:
            for row in item:
                for cell in row:
                    if cell.strip():
                        chunks.append(cell)
    return "\n".join(chunks)


# Keep python-docx style helpers if a caller passes a python-docx Document.
def iter_body(document) -> Iterator[tuple]:
    """Yield ``("p", Paragraph)`` / ``("tbl", Table)`` in real body order."""
    from docx.table import Table
    from docx.text.paragraph import Paragraph

    for child in document.element.body.iterchildren():
        if child.tag.endswith("}p"):
            yield "p", Paragraph(child, document)
        elif child.tag.endswith("}tbl"):
            yield "tbl", Table(child, document)


def docx_text(document) -> str:
    """All text of a python-docx Document (paragraphs + tables, body order)."""
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


# ---------------------------------------------- unified malzama parser ----

_UNIT_ORDINAL_MAP = {
    "الأولى": 1,
    "الاولى": 1,
    "الثانية": 2,
    "الثالثة": 3,
    "الرابعة": 4,
}

_GRADE_SECTION = {
    "الصف الأول المتوسط": "g1",
    "الصف الثاني المتوسط": "g2",
    "الصف الثالث المتوسط": "g3",
}

_LEADING_NUM_RE = re.compile(r"^[٠-٩0-9]+\s*[-–.)]\s*(.+)$")
_TF_LINE_RE = re.compile(
    r"^[٠-٩0-9]+\s*[-–]\s*(.+?)\s*\((صح|خطأ)\)(?:\s*[-–]\s*السبب:\s*(.+))?$"
)
_CHOICE_OPT_RE = re.compile(r"^[أبج]\s*[-–]\s*(.+)$")


def _strip_leading_number(text: str) -> str:
    m = _LEADING_NUM_RE.match(text.strip())
    return polish(m.group(1)) if m else polish(text)


def _unit_order_from_title(title: str) -> int:
    for word, order in _UNIT_ORDINAL_MAP.items():
        if word in title:
            return order
    raise ValueError(f"cannot determine unit order from title: {title!r}")


def parse_malzama_docx(path: Path) -> Tuple[List[dict], Dict[str, bytes]]:
    """Parse ``ملزمة_التربية_الفنية_بنموذج_إجابة_موحد.docx`` accurately.

    Returns ``(units, media_bytes)`` where each unit contains its grade,
    order, title, displayTitle, topics, images (with archive target and
    exact caption), and questions (true/false with reasons, choice with
    underlined answerIndex, and open enumeration questions with answers).
    """
    blocks = read_docx_paragraphs_and_tables(path)
    media: Dict[str, bytes] = {}
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if name.startswith("word/media/"):
                media[name[len("word/"):]] = archive.read(name)

    units: List[dict] = []
    cur_grade: Optional[str] = None
    cur_unit: Optional[dict] = None
    cur_topic: Optional[dict] = None
    mode: Optional[str] = None  # None, "q", "tf", "choice", "open"
    pending_choice_prompt: Optional[str] = None
    pending_open: Optional[dict] = None
    pending_image: Optional[str] = None

    def flush_open() -> None:
        nonlocal pending_open
        if pending_open is not None and cur_unit is not None:
            items = pending_open.pop("_items")
            pending_open["answer"] = "\n".join(items)
            cur_unit["questions"].append(pending_open)
            pending_open = None

    for kind, item in blocks:
        if kind != "p":
            continue
        p: DocxParagraph = item
        text = polish(p.text)
        szs = {r.size for r in p.runs if r.size}
        cols = {r.color for r in p.runs if r.color}

        if p.images:
            pending_image = p.images[0]
            continue

        if pending_image is not None:
            if cur_unit is None:
                raise ValueError(f"image {pending_image} appeared outside a unit")
            caption = text or ""
            cur_unit["images"].append({"media": pending_image, "caption": caption})
            pending_image = None
            continue

        if not text:
            continue

        if "38" in szs and "9B2C2C" in cols and text in _GRADE_SECTION:
            flush_open()
            cur_grade = text
            mode = None
            continue

        if "42" in szs and "292929" in cols and text.startswith("الوحدة"):
            flush_open()
            if cur_grade is None:
                raise ValueError(f"unit {text!r} appeared before any grade heading")
            grade_key = _GRADE_SECTION[cur_grade]
            order = _unit_order_from_title(text)
            short = polish(text.split(":", 1)[1]) if ":" in text else text
            cur_unit = {
                "id": f"{grade_key}-u{order}",
                "sectionId": grade_key,
                "grade": cur_grade,
                "gradeKey": grade_key,
                "order": order,
                "title": text,
                "displayTitle": short,
                "topics": [],
                "images": [],
                "questions": [],
            }
            units.append(cur_unit)
            cur_topic = None
            mode = None
            continue

        if cur_unit is None:
            continue

        if text == "أسئلة الوحدة":
            mode = "q"
            cur_topic = None
            continue

        if mode is None:
            if "32" in szs and "8C3434" in cols:
                cur_topic = {
                    "id": f"t{len(cur_unit['topics']) + 1}",
                    "title": text,
                    "bullets": [],
                    "listTitle": None,
                    "listItems": [],
                }
                cur_unit["topics"].append(cur_topic)
                continue
            if cur_topic is not None:
                cur_topic["bullets"].append(_strip_leading_number(text))
                continue

        if mode is not None:
            if text in ("صح أم خطأ", "صح وخطأ"):
                flush_open()
                mode = "tf"
                continue
            if text in ("اختر الإجابة الصحيحة", "الاختيارات"):
                flush_open()
                mode = "choice"
                pending_choice_prompt = None
                continue
            if text == "التعداد":
                flush_open()
                mode = "open"
                continue

            if mode == "tf":
                m = _TF_LINE_RE.match(text)
                if not m:
                    raise ValueError(f"unexpected true/false format: {text!r}")
                qid = f"q{len(cur_unit['questions']) + 1}"
                q = {
                    "id": qid,
                    "kind": "trueFalse",
                    "prompt": polish(m.group(1)),
                    "answer": m.group(2) == "صح",
                }
                if m.group(3):
                    q["answerSupport"] = polish(m.group(3))
                cur_unit["questions"].append(q)
                continue

            if mode == "choice":
                if pending_choice_prompt is None:
                    pending_choice_prompt = _strip_leading_number(text)
                else:
                    options: List[str] = []
                    answer_index: Optional[int] = None
                    for run in p.runs:
                        for part in re.split(r"\s{2,}|\t+", run.text.strip()):
                            part = polish(part)
                            if not part:
                                continue
                            m_opt = _CHOICE_OPT_RE.match(part)
                            if not m_opt:
                                raise ValueError(
                                    f"unexpected choice option {part!r} in {p.text!r}"
                                )
                            if run.underline == "single":
                                answer_index = len(options)
                            options.append(polish(m_opt.group(1)))
                    if answer_index is None or len(options) < 2:
                        raise ValueError(
                            f"missing underlined answer or options in {p.text!r}"
                        )
                    qid = f"q{len(cur_unit['questions']) + 1}"
                    cur_unit["questions"].append({
                        "id": qid,
                        "kind": "choice",
                        "prompt": pending_choice_prompt,
                        "options": options,
                        "answerIndex": answer_index,
                    })
                    pending_choice_prompt = None
                continue

            if mode == "open":
                # Open prompt paragraphs carry spacing w:before="0" and begin
                # with a prompt verb like "عدد" / "اذكر", whereas answer items
                # do not have w:before.
                is_prompt = p.has_spacing_before or bool(
                    re.match(r"^[٠-٩0-9]+\s*[-–]\s*(?:عدد|اذكر|ما\s)", text)
                )
                if is_prompt and (
                    pending_open is None or len(pending_open["_items"]) > 0
                ):
                    flush_open()
                    qid = f"q{len(cur_unit['questions']) + 1}"
                    pending_open = {
                        "id": qid,
                        "kind": "open",
                        "prompt": _strip_leading_number(text),
                        "_items": [],
                    }
                elif pending_open is not None:
                    pending_open["_items"].append(text)
                else:
                    raise ValueError(f"orphan open answer line: {text!r}")

    flush_open()
    return units, media


# ------------------------------------------------------- legacy helpers -----

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


_ANSWER_MARK = "الإجابة:"
_TF_RE = re.compile(r"^(?:[0-9]+\s*-\s*)?(.+?)\s*" + _ANSWER_MARK + r"\s*(صح|خطأ|صح\.|خطأ\.)")


def parse_questions(lines: Iterable[str]) -> List[dict]:
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
