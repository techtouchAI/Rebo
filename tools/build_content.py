#!/usr/bin/env python3
"""Build the structured app content (JSON + plate images) from the DOCX sources.

Run from the repository root::

    python3 tools/build_content.py

The script is deterministic: running it twice produces identical output.
Sources (read-only):

* ``محتوى مكتمل/ملخص_التربية_الفنية.docx``  -> the 12 curriculum units
* ``محتوى مكتمل/مقدمة.docx``                 -> introduction & teaching methods
* ``محتوى مكتمل/*نظري/عملي*.docx``            -> lesson plans
* ``08..20_*.docx``                          -> scanned plates of the teacher guide
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional

import docx
from docx.table import Table
from docx.text.paragraph import Paragraph
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from contentlib import (  # noqa: E402
    canon,
    docx_text,
    iter_body,
    normalize_ws,
    parse_questions,
    parse_topics,
    polish,
)

ROOT = Path(__file__).resolve().parents[1]
CONTENT_DIR = ROOT / "assets" / "content"
PLATE_DIR = ROOT / "assets" / "images" / "plates"
SUMMARY_DOC = ROOT / "محتوى مكتمل" / "ملخص_التربية_الفنية.docx"
INTRO_DOC = ROOT / "محتوى مكتمل" / "مقدمة.docx"

PALETTE = {
    "primary": "#B4462F",
    "secondary": "#1E5F74",
    "gold": "#D9A34A",
    "green": "#4E7C59",
    "ink": "#3A3A44",
}


def legend(*items) -> List[dict]:
    return [{"label": label, "color": PALETTE[key]} for label, key in items]


def figure(asset: str, caption: str, items=None) -> dict:
    return {
        "asset": f"assets/illustrations/{asset}.svg",
        "caption": caption,
        "legend": items or [],
    }


# Authored design metadata: how each unit is presented and illustrated.
# Keys are "<grade>-u<unit number>"; captions only reuse terminology of the source.
UNIT_META: Dict[str, dict] = {
    "g1-u1": {
        "template": "concept",
        "accent": "primary",
        "figures": [
            figure(
                "perspective",
                "عناصر المنظور: خط الأرض وخط الأفق وخطوط التلاشي.",
                legend(("خط الأرض", "green"), ("خط الأفق", "secondary"), ("نقطة التلاشي", "primary")),
            ),
            figure(
                "color-wheel",
                "الألوان الأساسية والثانوية والحيادية.",
                legend(("أساسية", "primary"), ("ثانوية", "green"), ("حيادية", "ink")),
            ),
        ],
    },
    "g1-u2": {
        "template": "comparison",
        "accent": "secondary",
        "figures": [
            figure(
                "design-fields",
                "ميادين التصميم: الصناعي والطباعي والديكور والأقمشة.",
                legend(("صناعي", "secondary"), ("طباعي", "primary"), ("ديكور", "gold"), ("أقمشة", "green")),
            ),
            figure(
                "ornament-grid",
                "الوحدة الزخرفية وتكرارها وتماثلها داخل المساحة.",
                legend(("الوحدة", "primary"), ("التكرار", "secondary")),
            ),
        ],
    },
    "g1-u3": {
        "template": "materials",
        "accent": "gold",
        "figures": [
            figure(
                "cardboard-net",
                "رسم سطح المجسم «الانفراد» ثم القص والثني واللصق.",
                legend(("سطح المجسم", "gold"), ("خطوط الطي", "secondary")),
            ),
            figure(
                "pottery-wheel",
                "تشكيل الطينة وصنع الأواني الفخارية.",
                legend(("الطينة", "primary"), ("الدولاب", "ink")),
            ),
        ],
    },
    "g1-u4": {
        "template": "concept",
        "accent": "ink",
        "figures": [
            figure(
                "cuneiform",
                "من المظاهر الفنية القديمة: الكتابة المسمارية والنقوش.",
                legend(("النقوش", "ink"), ("الطين", "gold")),
            ),
        ],
    },
    "g2-u1": {
        "template": "concept",
        "accent": "secondary",
        "figures": [
            figure(
                "light-shadow",
                "مصادر الضوء والظل الحقيقي والظل الساقط.",
                legend(("الضوء", "gold"), ("الظل الحقيقي", "secondary"), ("الظل الساقط", "ink")),
            ),
        ],
    },
    "g2-u2": {
        "template": "comparison",
        "accent": "primary",
        "figures": [
            figure(
                "geometry-shapes",
                "الأشكال الهندسية المنتظمة: المربع والمثلث والدائرة.",
                legend(("المربع", "primary"), ("المثلث", "secondary"), ("الدائرة", "gold")),
            ),
        ],
    },
    "g2-u3": {
        "template": "materials",
        "accent": "green",
        "figures": [
            figure(
                "loom-weaving",
                "النول اليدوي البسيط وخيوط السدى واللحمة.",
                legend(("السدى", "secondary"), ("اللحمة", "primary")),
            ),
            figure(
                "reed-basket",
                "أشغال القصب: القياس والقطع والثقب وربط الأجزاء.",
                legend(("القصب", "gold"), ("الربط", "ink")),
            ),
        ],
    },
    "g2-u4": {
        "template": "concept",
        "accent": "gold",
        "figures": [
            figure(
                "islamic-pattern",
                "زخرفة السطوح وملء الفراغات في الفن العربي الإسلامي.",
                legend(("الخطوط", "gold"), ("الفراغات", "secondary")),
            ),
        ],
    },
    "g3-u1": {
        "template": "concept",
        "accent": "primary",
        "figures": [
            figure(
                "still-life",
                "الطبيعة الجامدة: التناسب والعمق وتوزيع الضوء والظل.",
                legend(("الضوء", "gold"), ("الظل", "secondary")),
            ),
        ],
    },
    "g3-u2": {
        "template": "process",
        "accent": "secondary",
        "figures": [
            figure(
                "print-block",
                "حفر التصميم على القالب ثم طباعته.",
                legend(("القالب", "gold"), ("الحفر", "secondary"), ("الطبعة", "primary")),
            ),
            figure(
                "kufi-grid",
                "الخط الكوفي البسيط وأسس حروفه بالأدوات الهندسية.",
                legend(("الشبكة", "secondary"), ("الحروف", "ink")),
            ),
        ],
    },
    "g3-u3": {
        "template": "materials",
        "accent": "gold",
        "figures": [
            figure(
                "macrame-knots",
                "من عقد المكرمية: العقدة المربعة والعقدة الحلزونية.",
                legend(("العقدة", "primary"), ("الخيوط", "gold")),
            ),
            figure(
                "wire-forms",
                "الأسلاك في الأعمال الزخرفية والنافعة.",
                legend(("السلك", "secondary"), ("الحلي", "gold")),
            ),
        ],
    },
    "g3-u4": {
        "template": "timeline",
        "accent": "primary",
        "figures": [
            figure(
                "modern-art",
                "الحركة التشكيلية العراقية الحديثة والجماعات الفنية.",
                legend(("1939", "secondary"), ("1950", "primary"), ("1951", "gold"), ("1952", "green")),
            ),
        ],
    },
}

INTRO_META = {
    "template": "concept",
    "accent": "secondary",
    "figures": [
        figure(
            "studio",
            "التربية الفنية: أدوات وخامات وميادين العمل الفني.",
            legend(("الخامات", "gold"), ("الأدوات", "secondary"), ("اللون", "primary")),
        ),
    ],
}


# Choice answers whose key is stated explicitly in the unit content. Each entry
# is (option index, the sentence of the source that states it); the builder
# refuses to ship an entry whose evidence is missing from the source.
CHOICE_ANSWERS: Dict[tuple, tuple] = {
    ("g1-u1", "q4"): (0, "الألوان الأساسية: الأصفر والأزرق والأحمر، ولا تُستخرج من مزج ألوان أخرى."),
    ("g1-u1", "q5"): (1, "وتختلف أقلام الرصاص بين H للرسم الهندسي وB للرسم والتظليل وHB للكتابة."),
    ("g1-u2", "q5"): (1, "التكرار: إعادة الوحدة الزخرفية؛ والتماثل: نصفي أو كلي."),
    ("g2-u1", "q4"): (0, "رسم موضوعات مستمدة من البيت والمدرسة والبيئة المحيطة بالطالب."),
    ("g2-u1", "q5"): (0, "تمييز الأجسام المعتمة ونصف الشفافة والشفافة، والاستفادة من سلم القيم في التظليل."),
    ("g2-u3", "q5"): (0, "تشكيل الجلود في قطع نافعة وزخرفية وفق تصميم مناسب."),
    ("g3-u1", "q4"): (0, "رسم مجموعة من العناصر الطبيعية الجامدة وتلوينها."),
    ("g3-u2", "q5"): (0, "يُراعى وضوح الموضوع والكتابة وتنظيم العناصر داخل المساحة."),
    ("g3-u4", "q4"): (0, "جماعة الانطباعيين حول حافظ الدروبي سنة 1952، وظهرت جمعية الفنانين العراقيين سنة 1956."),
}

OCR_FIXES = [
    ("بإهتمام", "باهتمام"),
    ("تُعّد", "تُعد"),
    ("بأسلوب", "بأسلوب"),
]

GRADE_ORDER = ["الصف الأول المتوسط", "الصف الثاني المتوسط", "الصف الثالث المتوسط"]
GRADE_SECTION = {
    "الصف الأول المتوسط": "g1",
    "الصف الثاني المتوسط": "g2",
    "الصف الثالث المتوسط": "g3",
}


def _clean_title(text: str) -> tuple[str, str]:
    """Split ``"الوحدة الأولى: التعبير الفني"`` into (full, short)."""
    full = polish(text)
    if ":" in full:
        short = polish(full.split(":", 1)[1])
    else:
        short = full
    return full, short


# ------------------------------------------------------------------ units ---

def build_units() -> List[dict]:
    document = docx.Document(str(SUMMARY_DOC))
    blocks: List[tuple] = []
    for kind, item in iter_body(document):
        if kind == "p":
            if item.text.strip():
                blocks.append(("p", item))
        else:
            blocks.append(("tbl", item))

    units: List[dict] = []
    current: Optional[dict] = None
    question_lines: List[str] = []
    table_text = ""

    def flush():
        nonlocal current, question_lines, table_text
        if current is None:
            return
        current["questions"] = parse_questions(question_lines)
        units.append(current)
        question_lines = []
        table_text = ""

    for kind, item in blocks:
        if kind == "p":
            text = polish(item.text)
            if text in GRADE_ORDER:
                flush()
                current = {
                    "grade": text,
                    "gradeKey": GRADE_SECTION[text],
                    "title": "",
                    "topics": [],
                    "figures": [],
                }
                continue
            if current is None:
                continue
            if text.startswith("الوحدة"):
                full, short = _clean_title(text)
                current["title"] = full
                current["displayTitle"] = short
                continue
            if text == "أسئلة الوحدة":
                continue
            if current.get("title"):
                question_lines.append(item.text)
            continue
        # table
        if current is None or not current.get("title"):
            continue
        if table_text:
            continue
        table_text = "\n".join(cell.text for row in item.rows for cell in row.cells)
        topics: List[dict] = []
        topic_index = 0
        for row in item.rows:
            for cell in row.cells:
                for topic in parse_topics(cell.text):
                    topic_index += 1
                    topics.append({
                        "id": f"t{topic_index}",
                        "title": topic.title,
                        "bullets": topic.bullets,
                        "listTitle": topic.list_title,
                        "listItems": topic.list_items,
                    })
        current["topics"] = topics
    flush()

    # Enrich with design metadata and stable identifiers.
    result: List[dict] = []
    unit_number = {"g1": 0, "g2": 0, "g3": 0}
    for unit in units:
        key = unit["gradeKey"]
        unit_number[key] += 1
        uid = f"{key}-u{unit_number[key]}"
        meta = UNIT_META[uid]
        unit["id"] = uid
        unit["sectionId"] = key
        unit["order"] = unit_number[key]
        unit["template"] = meta["template"]
        unit["accent"] = meta["accent"]
        unit["figures"] = meta["figures"]
        unit["unitText"] = "\n".join(
            [t["title"] + "\n" + "\n".join(t["bullets"]) for t in unit["topics"]]
        )
        for question in unit["questions"]:
            question.pop("answerIndex", None)
            if question["kind"] == "choice":
                manual = CHOICE_ANSWERS.get((uid, question["id"]))
                if manual is not None:
                    option_index, evidence = manual
                    if canon(evidence) not in canon(unit["unitText"]):
                        raise SystemExit(f"choice evidence missing in source: {uid}/{question['id']}")
                    if not _option_supported(question["options"][option_index], evidence):
                        raise SystemExit(f"choice evidence does not contain the answer: {uid}/{question['id']}")
                    question["answerIndex"] = option_index
                    question["answerSupport"] = polish(evidence)
                    continue
                index, support = _resolve_choice(question, unit["unitText"])
                if index is None:
                    question["answerIndex"] = None
                    question["answerSupport"] = None
                else:
                    question["answerIndex"] = index
                    question["answerSupport"] = support
        result.append(unit)
    return result


def _keywords(text: str) -> List[str]:
    words = re.findall(r"[\u0621-\u064a]+", text)
    out = []
    for word in words:
        for prefix in ("وال", "بال", "كال", "فال", "ال"):
            if word.startswith(prefix) and len(word) > len(prefix) + 2:
                word = word[len(prefix):]
                break
        if len(word) > 2:
            out.append(word)
    return out


def _option_supported(option: str, evidence: str) -> bool:
    if canon(option) and canon(option) in canon(evidence):
        return True
    evidence_keywords = set(_keywords(evidence))
    hits = [word for word in _keywords(option) if word in evidence_keywords]
    return len(hits) >= 2


def _resolve_choice(question: dict, unit_text: str) -> tuple[Optional[int], Optional[str]]:
    """Find which option the source text explicitly supports (no guessing)."""
    hits = []
    for i, option in enumerate(question["options"]):
        support = None
        for sentence in re.split(r"[.؟!\n]", unit_text):
            if canon(option) and canon(option) in canon(sentence):
                support = polish(sentence)
                break
        if support:
            hits.append((i, support))
    if len(hits) == 1:
        return hits[0]
    return None, None


# ------------------------------------------------------------------ intro ---

def build_intro() -> dict:
    document = docx.Document(str(INTRO_DOC))
    paragraphs = [polish(p.text) for p in document.paragraphs if p.text.strip()]
    topics: List[dict] = []

    def add(topic: dict):
        topic["id"] = f"t{len(topics) + 1}"
        topic.setdefault("bullets", [])
        topic.setdefault("listTitle", None)
        topic.setdefault("listItems", [])
        topics.append(topic)

    # Introduction paragraphs (between "المقدمة" and "انواع طرائق التدريس").
    intro_lines: List[str] = []
    section = "intro"
    aims: List[str] = []
    methods: List[dict] = []
    current_method: Optional[dict] = None
    intro_done = False
    for text in paragraphs[2:]:
        if text.startswith("انواع طرائق التدريس") or text.startswith("أنواع طرائق التدريس"):
            section = "methods"
            continue
        if text.startswith("الأهداف العامة"):
            section = "aims"
            continue
        if text.startswith("المرحلة المتوسطة"):
            break
        if section == "intro":
            if not intro_done:
                intro_lines.append(text)
        elif section == "methods":
            if text in ("أ", "ب") or text.startswith("أ -") or text.startswith("ب -"):
                continue
            if text.startswith(("أ-", "ب-", "أ -", "ب -")) and "الطرائق" in text:
                continue
            m = re.match(r"^([٠-٩0-9]+)\s*[-–]\s*(.+)$", text)
            if m:
                body = polish(m.group(2))
                if ":" in body:
                    name, rest = body.split(":", 1)
                    current_method = {
                        "title": polish(name),
                        "bullets": [],
                    }
                    if polish(rest):
                        current_method["bullets"].append(_sentence_case(rest))
                    methods.append(current_method)
                else:
                    current_method = {"title": body, "bullets": []}
                    methods.append(current_method)
                continue
            if current_method is not None:
                current_method["bullets"].append(_sentence_case(text))
            else:
                methods.append({"title": text, "bullets": []})
                current_method = methods[-1]
        elif section == "aims":
            m = re.match(r"^([٠-٩0-9]+)\s*[-–]\s*(.+)$", text)
            if m:
                aims.append(polish(m.group(2)))
            else:
                aims.append(text)

    add({
        "title": "المقدمة",
        "bullets": [_reflow("\n".join(intro_lines))],
        "kind": "prose",
    })
    if aims:
        add({
            "title": "الأهداف العامة لمادة التربية الفنية في المرحلة المتوسطة",
            "bullets": [],
            "listTitle": "الأهداف",
            "listItems": aims,
            "kind": "list",
        })
    for method in methods:
        if method["bullets"]:
            method["bullets"] = [_reflow("\n".join(method["bullets"]))]
    # Group the teaching methods by the two axes of the source document.
    teacher_centred = []
    student_centred = []
    for method in methods:
        (teacher_centred if _is_teacher_centred(method["title"]) else student_centred).append(method)
    if teacher_centred:
        add({
            "title": "طرائق مركزها المدرس",
            "bullets": [],
            "listTitle": None,
            "listItems": [],
            "kind": "methods",
            "methods": teacher_centred,
        })
    if student_centred:
        add({
            "title": "طرائق مركزها الطلبة",
            "bullets": [],
            "listTitle": None,
            "listItems": [],
            "kind": "methods",
            "methods": student_centred,
        })

    return {
        "id": "intro",
        "sectionId": "intro",
        "order": 1,
        "title": "مدخل إلى التربية الفنية",
        "displayTitle": "مدخل إلى التربية الفنية",
        "grade": "مدخل",
        "template": INTRO_META["template"],
        "accent": INTRO_META["accent"],
        "figures": INTRO_META["figures"],
        "topics": topics,
        "questions": [],
        "unitText": docx_text(document),
    }


def _sentence_case(text: str) -> str:
    text = polish(text)
    if not text:
        return text
    return text


def _is_teacher_centred(title: str) -> bool:
    return any(word in title for word in ("المحاضرة", "العرض"))


# ----------------------------------------------------------------- lessons ---

LESSON_FILES = [
    ("الظل والضوء", "theory", "الظل والضوء.docx"),
    ("الظل والضوء", "practice", "الظل والضوء العملي.docx"),
    ("المنظور", "theory", "المنظور.docx"),
    ("المنظور", "practice", "المنظور العملي.docx"),
    ("الزخرفة", "theory", "الرخرفة.docx"),
    ("الزخرفة", "practice", "الزخرفة عملي.docx"),
    ("تصميم غلاف كتاب", "theory", "تصميم غلاف كتاب.docx"),
    ("تصميم غلاف كتاب", "practice", "تصميم غلاف كتاب عملي.docx"),
]

LESSON_META = {
    "الظل والضوء": {
        "summary": "مصادر الضوء، والضوء المباشر والمنعكس، والظل الحقيقي والساقط، والأجسام المعتمة والشفافة ونصف الشفافة.",
        "figures": [
            figure(
                "light-shadow",
                "مصادر الضوء والظل الحقيقي والظل الساقط.",
                legend(("الضوء", "gold"), ("الظل الحقيقي", "secondary"), ("الظل الساقط", "ink")),
            )
        ],
        "accent": "gold",
    },
    "المنظور": {
        "summary": "خط الأفق ونقطة التلاشي وحجم الأشياء القريبة والبعيدة ووضوحها.",
        "figures": [
            figure(
                "perspective",
                "عناصر المنظور: خط الأرض وخط الأفق وخطوط التلاشي.",
                legend(("خط الأرض", "green"), ("خط الأفق", "secondary"), ("نقطة التلاشي", "primary")),
            )
        ],
        "accent": "secondary",
    },
    "الزخرفة": {
        "summary": "أنواع الزخارف: النباتية والحيوانية والكتابية والهندسية، وتطبيقاتها في النقش والملابس والجدران.",
        "figures": [
            figure(
                "ornament-grid",
                "الوحدة الزخرفية وتكرارها وتماثلها داخل المساحة.",
                legend(("الوحدة", "primary"), ("التكرار", "secondary")),
            )
        ],
        "accent": "primary",
    },
    "تصميم غلاف كتاب": {
        "summary": "غلاف الكتاب «وجه» الكتاب وعناصره الأربعة: العنوان والصورة واسم المؤلف والألوان.",
        "figures": [
            figure(
                "book-cover",
                "عناصر غلاف الكتاب: العنوان والصورة واسم المؤلف والألوان.",
                legend(("العنوان", "primary"), ("الصورة", "secondary"), ("المؤلف", "ink")),
            )
        ],
        "accent": "green",
    },
}

_LABELS = {
    "الموضوع": "subject",
    "الأهداف العامة": "generalAims",
    "الأهداف الخاصة": "specificAims",
    "الوسائل التعليمية": "media",
    "المقدمـــــــة": "introduction",
    "المقدمة": "introduction",
    "العـــــــــــرض": "presentation",
    "العرض": "presentation",
    "الخاتمة": "conclusion",
}

_BULLET_MARKERS = ("*", "-", "•", "–")


def build_lessons() -> List[dict]:
    grouped: Dict[str, dict] = {}
    for title, kind, filename in LESSON_FILES:
        path = ROOT / "محتوى مكتمل" / filename
        if not path.exists():
            raise SystemExit(f"missing lesson plan: {path}")
        document = docx.Document(str(path))
        plan = _read_plan(document)
        plan["kind"] = kind
        plan["label"] = "الحصة النظرية" if kind == "theory" else "الحصة العملية"
        lesson = grouped.setdefault(title, {
            "id": "lesson-" + slug(title),
            "title": title,
            "summary": LESSON_META[title]["summary"],
            "figures": LESSON_META[title]["figures"],
            "accent": LESSON_META[title]["accent"],
            "template": "lesson",
            "plans": [],
        })
        lesson["plans"].append(plan)
    lessons = []
    for i, title in enumerate(["الظل والضوء", "المنظور", "الزخرفة", "تصميم غلاف كتاب"], start=1):
        lesson = grouped[title]
        lesson["order"] = i
        lesson["plans"].sort(key=lambda plan: 0 if plan["kind"] == "theory" else 1)
        lessons.append(lesson)
    return lessons


def _read_plan(document) -> dict:
    """Turn a weekly-plan table into a structured lesson plan."""
    plan: dict = {
        "subject": "",
        "generalAims": "",
        "specificAims": [],
        "media": "",
        "introduction": "",
        "body": [],
        "homework": [],
    }
    for kind, item in iter_body(document):
        if kind != "tbl":
            continue
        for row in item.rows:
            cells = row.cells
            if len(cells) < 2:
                continue
            values = [normalize_ws(cell.text) for cell in cells]
            label = None
            label_index = None
            for i, value in enumerate(values[:3]):
                cleaned = re.sub(r"[\s\u0640]+", "", value)
                for candidate, key in _LABELS.items():
                    if cleaned == re.sub(r"[\s\u0640]+", "", candidate):
                        label = key
                        label_index = i
                        break
                if label:
                    break
            if not label:
                continue
            value = values[1] if label_index == 0 and len(values) > 1 else values[0]
            blocks = _blocks(value)
            if label == "subject":
                plan["subject"] = _reflow(value)
            elif label == "generalAims":
                plan["generalAims"] = _reflow(value)
            elif label == "specificAims":
                aims = []
                for block in blocks:
                    text = re.sub(r"^[0-9]+[)-]\s*", "", block["text"])
                    aims.append(text)
                plan["specificAims"] = aims
            elif label == "media":
                plan["media"] = _reflow(value)
            elif label == "introduction":
                plan["introduction"] = _reflow(value)
            elif label == "conclusion":
                plan["body"].append({"kind": "heading", "text": "الخاتمة"})
                plan["body"].extend(blocks)
            elif label == "presentation":
                for block in blocks:
                    if block["text"].startswith("واجب"):
                        plan["homework"].append(block["text"])
                    else:
                        plan["body"].append(block)
        break
    return plan


def _blocks(value: str) -> List[dict]:
    """Split a DOCX cell into heading / bullet / paragraph blocks."""
    blocks: List[dict] = []
    paragraph: List[str] = []

    def flush():
        if paragraph:
            blocks.append({"kind": "paragraph", "text": polish(" ".join(paragraph))})
            paragraph.clear()

    for raw in value.split("\n"):
        line = polish(raw)
        if not line:
            flush()
            continue
        if line.startswith(_BULLET_MARKERS):
            flush()
            text = line.lstrip("*-•–").strip()
            if text:
                blocks.append({"kind": "bullet", "text": polish(text)})
            continue
        if len(line) <= 70 and (line.endswith(":") or line.endswith("：")):
            flush()
            blocks.append({"kind": "heading", "text": line[:-1].strip()})
            continue
        if paragraph and re.search(r"[.؟!:]$", paragraph[-1]):
            flush()
        paragraph.append(line)
    flush()
    return blocks


def _reflow(value: str) -> str:
    """Join the hard-wrapped lines of a DOCX paragraph back together."""
    parts = [polish(line) for line in value.split("\n") if polish(line)]
    return polish(" ".join(parts))


def _split_method_title(body: str) -> str:
    return polish(body)


def slug(text: str) -> str:
    table = {
        "الظل والضوء": "light",
        "المنظور": "perspective",
        "الزخرفة": "ornament",
        "تصميم غلاف كتاب": "book-cover",
    }
    return table.get(text, re.sub(r"\s+", "-", text))


# ------------------------------------------------------------------ plates --

PLATE_FILES = [
    ("08", "الصف الأول المتوسط", "الوحدة الأولى: التعبير الفني", "g1-u1"),
    ("09", "الصف الأول المتوسط", "الوحدة الثانية: التصميم والزخرفة", "g1-u2"),
    ("10", "الصف الأول المتوسط", "الوحدة الثالثة: التشكيل الفني والهندسي", "g1-u3"),
    ("11", "الصف الأول المتوسط", "الوحدة الرابعة: التذوق وتاريخ الفن", "g1-u4"),
    ("12", "الصف الثاني المتوسط", "الوحدة الأولى: التعبير الفني والهندسي", "g2-u1"),
    ("13", "الصف الثاني المتوسط", "الوحدة الثانية: التصميم والزخرفة", "g2-u2"),
    ("14", "الصف الثاني المتوسط", "الوحدة الثالثة: التشكيل المجسم", "g2-u3"),
    ("15", "الصف الثاني المتوسط", "الوحدة الرابعة: التذوق الفني وتاريخ الفن", "g2-u4"),
    ("16", "الصف الثالث المتوسط", "الوحدة الأولى: التعبير الفني والهندسي", "g3-u1"),
    ("17", "الصف الثالث المتوسط", "الوحدة الثانية: التصميم والزخرفة", "g3-u2"),
    ("18", "الصف الثالث المتوسط", "الوحدة الثالثة: التشكيل المجسم", "g3-u3"),
    ("19", "الصف الثالث المتوسط", "الوحدة الرابعة: التذوق وتاريخ الفن", "g3-u4"),
    ("20", "المرحلة المتوسطة", "مفردات الأنشطة المسرحية", "theatre"),
]


def crop_plate(source: Path, target: Path, max_width: int = 1600) -> None:
    image = Image.open(source).convert("RGB")
    gray = image.convert("L")
    # The scans are mounted on a white page: keep only the artwork.
    mask = gray.point(lambda value: 0 if value > 244 else 255)
    box = mask.getbbox()
    if box:
        left, top, right, bottom = box
        pad_x = int((right - left) * 0.04)
        pad_y = int((bottom - top) * 0.04)
        box = (
            max(0, left - pad_x),
            max(0, top - pad_y),
            min(image.width, right + pad_x),
            min(image.height, bottom + pad_y),
        )
        image = image.crop(box)
    if image.width > max_width:
        ratio = max_width / image.width
        image = image.resize((max_width, int(image.height * ratio)), Image.LANCZOS)
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, "JPEG", quality=88, optimize=True, progressive=True)


def build_plates() -> List[dict]:
    plates: List[dict] = []
    for prefix, grade, unit_title, unit_id in PLATE_FILES:
        matches = sorted(ROOT.glob(f"{prefix}_*.docx"))
        if not matches:
            raise SystemExit(f"missing plate source for {prefix}")
        source = matches[0]
        document = docx.Document(str(source))
        paragraphs = [polish(p.text) for p in document.paragraphs if p.text.strip()]
        caption = unit_title
        page_source = ""
        for text in paragraphs:
            if text.startswith("المصدر:"):
                page_source = text
            elif text.startswith("لوحة توضيحية"):
                continue
            elif paragraph_looks_like_caption(text):
                caption = text
        image_name = f"plate-{prefix}.jpg"
        with_zip_image(source, ROOT / "build_tmp_plate.jpg")
        crop_plate(ROOT / "build_tmp_plate.jpg", PLATE_DIR / image_name)
        (ROOT / "build_tmp_plate.jpg").unlink(missing_ok=True)
        plates.append({
            "id": f"plate-{prefix}",
            "asset": f"assets/images/plates/{image_name}",
            "title": unit_title,
            "caption": caption,
            "source": page_source,
            "grade": grade,
            "unitId": unit_id,
        })
    return plates


def paragraph_looks_like_caption(text: str) -> bool:
    return bool(re.search(r"(الوحدة|مفردات|الأنشطة)", text)) and not text.startswith("المصدر:")


def with_zip_image(docx_path: Path, target: Path) -> None:
    import zipfile

    with zipfile.ZipFile(docx_path) as archive:
        names = [n for n in archive.namelist() if n.startswith("word/media/")]
        if not names:
            raise SystemExit(f"no media in {docx_path}")
        target.write_bytes(archive.read(sorted(names)[0]))


# --------------------------------------------------------------- glossary ---

def build_glossary(units: List[dict], intro: dict) -> List[dict]:
    corpus = "\n".join([intro["unitText"]] + [unit["unitText"] for unit in units])
    entries = [
        ("المنظور", "قواعد تساعد على إظهار العمق والبعد الثالث على سطح اللوحة ذي البعدين.", "g1-u1", "t1"),
        ("خواص اللون", "كنه اللون: الاسم الذي يميز اللون، مثل الأحمر أو الأصفر.", "g1-u1", "t6"),
        ("الألوان الأساسية", "الألوان الأساسية: الأصفر والأزرق والأحمر، ولا تُستخرج من مزج ألوان أخرى.", "g1-u1", "t5"),
        ("التصميم", "التصميم فكرة تُنظّم عناصر العمل الفني داخل مساحة لتحقيق غرض محدد.", "g1-u2", "t8"),
        ("الوحدات الزخرفية", "تُستمد الوحدات من الطبيعة، مثل العناصر النباتية والحيوانية والآدمية، أو من الأشكال الهندسية.", "g1-u2", "t6"),
        ("التكرار", "التكرار: إعادة الوحدة الزخرفية؛ والتماثل: نصفي أو كلي.", "g1-u2", "t7"),
        ("الانفراد", "يعتمد العمل على رسم سطح المجسم «الانفراد» ثم قصه وثنيه وتجميعه ولصق أجزائه.", "g1-u3", "t7"),
        ("الفنون القديمة والحضارات", "يربط الدليل الفنون بحضارات بلاد الرافدين ودجلة والفرات، وبمواد البناء مثل الطين واللبن والقصب.", "g1-u4", "t3"),
        ("الظل والنور", "دراسة مصادر الضوء والضوء المباشر والمنعكس، وملاحظة الظل الحقيقي والظل الساقط.", "g2-u1", "t6"),
        ("الرسم من البيئة", "رسم موضوعات مستمدة من البيت والمدرسة والبيئة المحيطة بالطالب.", "g2-u1", "t2"),
        ("الأشكال الهندسية المنتظمة", "تكوين أشكال هندسية أساسها المربع والمثلث والدائرة.", "g2-u2", "t3"),
        ("قواعد التصميم الزخرفي", "بناء التصاميم على التكرار والتماثل والتناظر والتوزيع النجمي.", "g2-u2", "t4"),
        ("الطباعة", "إعداد تصميم وحفره على قالب مناسب ثم طباعته، مع تطبيقات على أسطح مختلفة.", "g2-u3", "t3"),
        ("النسيج والحياكة", "التعرف على النول اليدوي البسيط وخيوط السدى واللحمة وصنع نماذج نسيجية.", "g2-u3", "t4"),
        ("مميزات الفن الإسلامي", "الاهتمام بزخرفة السطوح وملء الفراغات، واستخدام مواد متنوعة وتحقيق قيمة جمالية فيها.", "g2-u4", "t4"),
        ("الطبيعة الجامدة", "رسم مجموعة من العناصر الطبيعية الجامدة وتلوينها.", "g3-u1", "t3"),
        ("الخط الكوفي البسيط", "التدريب على الخط الكوفي وأسس حروفه باستخدام الأدوات الهندسية.", "g3-u2", "t3"),
        ("الملصق الإعلاني", "عناصر الاتصال: المرسل، والرسالة، والوسيلة، والمستقبل، والصدى.", "g3-u2", "t5"),
        ("المكرمية", "تنفيذ مشغولات بالخيوط والحبال باستخدام العقد.", "g3-u3", "t2"),
        ("التزجيج", "التزجيج طلاء زجاجي يضاف إلى الأواني الفخارية بعد الحرق.", "g3-u3", "t1"),
        ("جماعة الرواد", "جماعة الرواد حول فائق حسن سنة 1950.", "g3-u4", "t4"),
    ]
    canonical_corpus = canon(corpus)
    glossary = []
    for order, (term, definition, unit_id, topic_id) in enumerate(entries, start=1):
        if canon(definition) not in canonical_corpus:
            raise SystemExit(f"glossary definition not found in the source: {term}")
        glossary.append({
            "id": f"term-{order:02d}",
            "term": term,
            "definition": definition,
            "unitId": unit_id,
            "topicId": topic_id,
        })
    return glossary


# -------------------------------------------------------------------- main ---

def apply_ocr_fixes(value):
    if isinstance(value, str):
        for old, new in OCR_FIXES:
            value = value.replace(old, new)
        return value
    if isinstance(value, list):
        return [apply_ocr_fixes(item) for item in value]
    if isinstance(value, dict):
        return {key: apply_ocr_fixes(item) for key, item in value.items()}
    return value


def write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def main() -> None:
    units = build_units()
    intro = build_intro()
    lessons = build_lessons()
    plates = build_plates()
    glossary = build_glossary(units, intro)

    sections = [
        {"id": "intro", "title": "مدخل إلى التربية الفنية", "subtitle": "المقدمة والأهداف العامة وطرائق التدريس", "kind": "intro"},
        {"id": "g1", "title": "الصف الأول المتوسط", "subtitle": "أربع وحدات دراسية", "kind": "grade"},
        {"id": "g2", "title": "الصف الثاني المتوسط", "subtitle": "أربع وحدات دراسية", "kind": "grade"},
        {"id": "g3", "title": "الصف الثالث المتوسط", "subtitle": "أربع وحدات دراسية", "kind": "grade"},
        {"id": "lessons", "title": "دروس تطبيقية", "subtitle": "خطط الحصص النظرية والعملية", "kind": "lessons"},
        {"id": "plates", "title": "لوحات من دليل المعلم", "subtitle": "أعمال فنية مصورة من صفحات الدليل", "kind": "plates"},
    ]

    curriculum = {
        "schemaVersion": 1,
        "title": "مِرسم",
        "subtitle": "التربية الفنية للمرحلة المتوسطة",
        "source": "محتوى مكتمل/ملخص_التربية_الفنية.docx",
        "sections": sections,
        "units": [intro] + units,
    }

    # Attach plates & glossary references to their units.
    by_id = {unit["id"]: unit for unit in curriculum["units"]}
    for plate in plates:
        unit = by_id.get(plate["unitId"])
        if unit is not None:
            unit["plate"] = {
                "asset": plate["asset"],
                "caption": plate["caption"],
                "source": plate["source"],
            }
    for entry in glossary:
        unit = by_id.get(entry["unitId"])
        if unit is not None:
            unit.setdefault("glossary", []).append(entry["id"])

    write_json(CONTENT_DIR / "curriculum.json", apply_ocr_fixes(curriculum))
    write_json(CONTENT_DIR / "lessons.json", apply_ocr_fixes({"schemaVersion": 1, "lessons": lessons}))
    write_json(CONTENT_DIR / "glossary.json", apply_ocr_fixes({"schemaVersion": 1, "terms": glossary}))
    write_json(CONTENT_DIR / "plates.json", apply_ocr_fixes({"schemaVersion": 1, "plates": plates}))

    topics = sum(len(unit["topics"]) for unit in curriculum["units"])
    questions = sum(len(unit["questions"]) for unit in curriculum["units"])
    print(f"units: {len(curriculum['units'])} (12 grade units + intro)")
    print(f"topics: {topics}  questions: {questions}  lessons: {len(lessons)}  plates: {len(plates)}")
    unresolved = [
        (unit["id"], q["prompt"])
        for unit in curriculum["units"]
        for q in unit["questions"]
        if q["kind"] == "choice" and q.get("answerIndex") is None
    ]
    print(f"choice questions without explicit source answer: {len(unresolved)}")
    for unit_id, prompt in unresolved:
        print(f"  - {unit_id}: {prompt[:70]}")


if __name__ == "__main__":
    main()
