#!/usr/bin/env python3
"""Build the structured app content (JSON + plate images) from the DOCX sources.

Run from the repository root::

    python3 tools/build_content.py

The script is deterministic: running it twice produces identical output.
Sources (read-only):

* ``ملزمة_التربية_الفنية_بنموذج_إجابة_موحد.docx`` -> the 9 grade units, topics,
  unified answer-key questions, and embedded artwork/diagram plates
* ``محتوى مكتمل/مقدمة.docx``                 -> introduction & teaching methods
* ``محتوى مكتمل/*نظري*.docx``                -> practical lesson plans
* ``tools/theatre_content.py``                -> theatre activities section
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).parent))
from contentlib import (  # noqa: E402
    canon,
    normalize_ws,
    parse_malzama_docx,
    polish,
    read_docx_paragraphs_and_tables,
    read_docx_plain_text,
)
from theatre_content import (  # noqa: E402
    THEATRE_INTRO,
    THEATRE_TITLE,
    THEATRE_TOPICS,
)

ROOT = Path(__file__).resolve().parents[1]
CONTENT_DIR = ROOT / "assets" / "content"
PLATE_DIR = ROOT / "assets" / "images" / "plates"
MALZAMA_DOC = ROOT / "ملزمة_التربية_الفنية_بنموذج_إجابة_موحد.docx"
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
                "أنواع التصميم: الصناعي والطباعي والديكور والأقمشة.",
                legend(("صناعي", "secondary"), ("طباعي", "primary"), ("ديكور", "gold"), ("أقمشة", "green")),
            ),
            figure(
                "ornament-grid",
                "الوحدة الزخرفية وتكرارها وتماثلها داخل المساحة.",
                legend(("الوحدة", "primary"), ("التكرار", "secondary")),
            ),
        ],
    },
    "g1-u4": {
        "template": "concept",
        "accent": "ink",
        "figures": [
            figure(
                "cuneiform",
                "من مظاهر الفن في بلاد الرافدين: الكتابة المسمارية والنقوش.",
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
            figure(
                "perspective",
                "المنظور ونقاط التلاشي وخط الأفق.",
                legend(("خط الأرض", "green"), ("خط الأفق", "secondary"), ("نقطة التلاشي", "primary")),
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
    "g2-u4": {
        "template": "concept",
        "accent": "gold",
        "figures": [
            figure(
                "islamic-pattern",
                "تنظيم الوحدات وتكرارها وملء المساحات في الزخرفة الإسلامية.",
                legend(("الخطوط", "gold"), ("الفراغات", "secondary")),
            ),
        ],
    },
    "g3-u1": {
        "template": "concept",
        "accent": "primary",
        "figures": [
            figure(
                "light-shadow",
                "الضوء والظل وإظهار حجم الأشكال وعمقها.",
                legend(("الضوء", "gold"), ("الظل الحقيقي", "secondary"), ("الظل الساقط", "ink")),
            ),
            figure(
                "perspective",
                "قواعد المنظور الهندسي: خط الأفق ونقاط التلاشي.",
                legend(("خط الأرض", "green"), ("خط الأفق", "secondary"), ("نقطة التلاشي", "primary")),
            ),
        ],
    },
    "g3-u2": {
        "template": "process",
        "accent": "secondary",
        "figures": [
            figure(
                "kufi-grid",
                "الخط الكوفي وبناء حروفه القائم على الخطوط والزوايا.",
                legend(("الشبكة", "secondary"), ("الحروف", "ink")),
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

OCR_FIXES = [
    ("بإهتمام", "باهتمام"),
    ("تُعّد", "تُعد"),
]


# ------------------------------------------------------------------ units ---

def _keywords(text: str) -> List[str]:
    words = re.findall(r"[\u0621-\u064a٠-٩0-9]+", text)
    out = []
    for word in words:
        for prefix in ("وال", "بال", "كال", "فال", "ال"):
            if word.startswith(prefix) and len(word) > len(prefix) + 2:
                word = word[len(prefix):]
                break
        if len(word) > 2:
            out.append(word)
    return out


def _find_choice_support(option: str, unit_text: str) -> Optional[str]:
    target = canon(option)
    if not target:
        return None
    sentences = [polish(s) for s in re.split(r"[.؟!\n]", unit_text) if polish(s)]
    for sentence in sentences:
        if target in canon(sentence):
            return sentence
    opt_words = [canon(w) for w in _keywords(option)]
    if opt_words:
        for sentence in sentences:
            sc = canon(sentence)
            if all(w in sc for w in opt_words):
                return sentence
        for sentence in sentences:
            sc = canon(sentence)
            if any(w in sc for w in opt_words):
                return sentence
    return None


def build_units_and_plates() -> Tuple[List[dict], List[dict]]:
    if not MALZAMA_DOC.exists():
        raise SystemExit(f"missing source booklet: {MALZAMA_DOC}")
    raw_units, media = parse_malzama_docx(MALZAMA_DOC)

    # Clear stale plate files and write the exact images from the booklet.
    PLATE_DIR.mkdir(parents=True, exist_ok=True)
    for stale in PLATE_DIR.glob("plate-*.jpg"):
        stale.unlink()

    units: List[dict] = []
    plates: List[dict] = []
    plate_counter = 0

    for unit in raw_units:
        uid = unit["id"]
        if uid not in UNIT_META:
            raise SystemExit(f"missing UNIT_META for {uid}")
        meta = UNIT_META[uid]
        unit_images = unit.pop("images", [])
        unit["template"] = meta["template"]
        unit["accent"] = meta["accent"]
        unit["figures"] = meta["figures"]
        unit["unitText"] = "\n".join(
            [t["title"] + "\n" + "\n".join(t["bullets"]) for t in unit["topics"]]
        )

        unit_plates: List[dict] = []
        for img_entry in unit_images:
            plate_counter += 1
            media_key = img_entry["media"]
            if media_key not in media:
                raise SystemExit(f"missing media {media_key} in {MALZAMA_DOC}")
            ext = Path(media_key).suffix.lower() or ".jpg"
            filename = f"plate-{plate_counter:02d}{ext}"
            (PLATE_DIR / filename).write_bytes(media[media_key])
            caption = img_entry["caption"] or unit["displayTitle"]
            plate_id = f"plate-{plate_counter:02d}"
            asset_path = f"assets/images/plates/{filename}"
            unit_plates.append({
                "id": plate_id,
                "asset": asset_path,
                "caption": caption,
            })
            plates.append({
                "id": plate_id,
                "asset": asset_path,
                "title": caption,
                "caption": f"{unit['title']} — {caption}",
                "grade": unit["grade"],
                "unitId": uid,
            })

        unit["plates"] = unit_plates
        if unit_plates:
            unit["plate"] = unit_plates[0]

        for question in unit["questions"]:
            if question["kind"] == "choice":
                ans_idx = question.get("answerIndex")
                if ans_idx is None or not (0 <= ans_idx < len(question["options"])):
                    raise SystemExit(f"invalid answerIndex in {uid}/{question['id']}")
                support = _find_choice_support(
                    question["options"][ans_idx], unit["unitText"]
                )
                if not support:
                    raise SystemExit(
                        f"choice evidence missing in source: {uid}/{question['id']}"
                    )
                question["answerSupport"] = support

        units.append(unit)

    return units, plates


# ------------------------------------------------------------------ intro ---

def build_intro() -> dict:
    blocks = read_docx_paragraphs_and_tables(INTRO_DOC)
    paragraphs = [
        polish(item.text)
        for kind, item in blocks
        if kind == "p" and item.text.strip()
    ]
    topics: List[dict] = []

    def add(topic: dict):
        topic["id"] = f"t{len(topics) + 1}"
        topic.setdefault("bullets", [])
        topic.setdefault("listTitle", None)
        topic.setdefault("listItems", [])
        topics.append(topic)

    intro_lines: List[str] = []
    section = "intro"
    aims: List[str] = []
    methods: List[dict] = []
    current_method: Optional[dict] = None
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
                    current_method = {"title": polish(name), "bullets": []}
                    if polish(rest):
                        current_method["bullets"].append(polish(rest))
                    methods.append(current_method)
                else:
                    current_method = {"title": body, "bullets": []}
                    methods.append(current_method)
                continue
            if current_method is not None:
                current_method["bullets"].append(polish(text))
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
        "unitText": read_docx_plain_text(INTRO_DOC),
    }


def _is_teacher_centred(title: str) -> bool:
    return any(word in title for word in ("المحاضرة", "العرض"))


# ----------------------------------------------------------------- lessons ---

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

LESSON_FILES = [
    ("الظل والضوء", "theory", "الظل والضوء.docx"),
    ("المنظور", "theory", "المنظور.docx"),
    ("الزخرفة", "theory", "الرخرفة.docx"),
    ("تصميم غلاف كتاب", "theory", "تصميم غلاف كتاب.docx"),
]


def build_lessons() -> List[dict]:
    grouped: Dict[str, dict] = {}
    for title, kind, filename in LESSON_FILES:
        path = ROOT / "محتوى مكتمل" / filename
        if not path.exists():
            raise SystemExit(f"missing lesson plan: {path}")
        plan = _read_plan(path)
        plan["kind"] = kind
        plan["label"] = "الدرس"
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
        lessons.append(lesson)
    return lessons


def _read_plan(path: Path) -> dict:
    """Keep the presentation and the home assignment of a lesson document."""
    plan: dict = {
        "subject": "",
        "body": [],
        "homework": [],
    }
    for kind, item in read_docx_paragraphs_and_tables(path):
        if kind != "tbl":
            continue
        for cells in item:
            if len(cells) < 2:
                continue
            values = [normalize_ws(cell) for cell in cells]
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


def slug(text: str) -> str:
    table = {
        "الظل والضوء": "light",
        "المنظور": "perspective",
        "الزخرفة": "ornament",
        "تصميم غلاف كتاب": "book-cover",
    }
    return table.get(text, re.sub(r"\s+", "-", text))


# --------------------------------------------------------------- theatre ---

def build_theatre() -> dict:
    topics = []
    for index, topic in enumerate(THEATRE_TOPICS, start=1):
        topics.append({
            "id": f"t{index}",
            "title": topic["title"],
            "bullets": list(topic["bullets"]),
            "listTitle": None,
            "listItems": [],
        })
    return {
        "id": "theatre",
        "sectionId": "theatre",
        "order": 1,
        "title": THEATRE_TITLE,
        "displayTitle": THEATRE_TITLE,
        "grade": "المرحلة المتوسطة",
        "template": "concept",
        "accent": "primary",
        "figures": [],
        "topics": topics,
        "questions": [],
        "intro": THEATRE_INTRO,
        "unitText": "\n".join(
            [THEATRE_INTRO] + [topic["title"] + "\n" + "\n".join(topic["bullets"]) for topic in topics]
        ),
    }


# --------------------------------------------------------------- glossary ---

def build_glossary(units: List[dict], intro: dict) -> List[dict]:
    by_id = {unit["id"]: unit for unit in units}
    corpus = "\n".join([intro["unitText"]] + [unit["unitText"] for unit in units])
    entries = [
        ("التخطيط في العمل الفني", "يبدأ العمل الفني بفكرة واضحة، ويُترجم مضمونها إلى تخطيط مبسط يحدد الشكل العام والعناصر والأبعاد.", "g1-u1", "t2"),
        ("الألوان الأساسية", "الألوان الأساسية في الصبغات هي الأصفر والأزرق والأحمر، ولا تنتج من مزج ألوان أخرى.", "g1-u1", "t3"),
        ("الألوان الثانوية", "تنشأ الألوان الثانوية من مزج لونين أساسيين؛ ومن أمثلتها الأخضر والبرتقالي والبنفسجي.", "g1-u1", "t3"),
        ("الألوان الحيادية", "تشمل الألوان الحيادية الأبيض والرمادي والأسود. ويختلف مزج الألوان الصبغية عن مزج الأضواء الملونة.", "g1-u1", "t3"),
        ("خواص اللون", "كنه اللون هو الاسم الذي يميّز اللون، مثل الأحمر أو الأصفر.", "g1-u1", "t4"),
        ("المنظور", "المنظور قواعد فنية تساعد على إظهار العمق والبعد الثالث على سطح اللوحة ذي البعدين.", "g1-u1", "t5"),
        ("التصميم", "التصميم فكرة تُنظّم عناصر العمل الفني داخل مساحة محددة لتحقيق غرض معين.", "g1-u2", "t1"),
        ("التصميم الصناعي", "التصميم الصناعي: تصميم الأجهزة والأدوات والأثاث.", "g1-u2", "t2"),
        ("التصميم الطباعي", "التصميم الطباعي: تصميم الصحف والمجلات وأغلفة الكتب والبطاقات والمطبوعات.", "g1-u2", "t2"),
        ("الوحدات الزخرفية", "تُستمد الوحدات الزخرفية من عناصر الطبيعة، مثل العناصر النباتية والحيوانية والآدمية، كما تُستمد من الأشكال الهندسية.", "g1-u2", "t3"),
        ("التكرار والتماثل", "التكرار هو إعادة الوحدة الزخرفية وفق نظام معين.", "g1-u2", "t4"),
        ("التشعب", "التشعب هو امتداد العناصر الزخرفية من نقطة أو من خط.", "g1-u2", "t4"),
        ("الفنون القديمة في بلاد الرافدين", "من مظاهر الفن في حضارات بلاد الرافدين الكتابة المسمارية والنقوش والرسوم الحيوانية والآدمية والهندسية.", "g1-u4", "t1"),
        ("التكوين الفني", "يقوم التكوين الفني على تنظيم العناصر داخل مساحة العمل بما يحقق الوحدة والاتزان.", "g2-u1", "t2"),
        ("نقطة التلاشي", "نقطة التلاشي هي الموضع الذي تبدو الخطوط المتوازية متجهة نحوه عند تمثيل العمق بصرياً.", "g2-u1", "t4"),
        ("الضوء المباشر والمنعكس", "الضوء المباشر هو الضوء الذي يصل إلى الجسم من مصدره، أما الضوء المنعكس فيصل إليه بعد انعكاسه عن سطح آخر.", "g2-u1", "t5"),
        ("الظل الحقيقي والساقط", "الظل الحقيقي هو الجزء غير المضاء من الجسم، والظل الساقط هو الظل الذي يلقيه الجسم على سطح مجاور.", "g2-u1", "t5"),
        ("الأشكال الهندسية المنتظمة", "من الأشكال الهندسية الأساسية المربع والمثلث والدائرة.", "g2-u2", "t2"),
        ("قواعد التصميم الزخرفي", "تعتمد التصاميم الزخرفية على قواعد منها التكرار والتماثل والتناظر والتوزيع النجمي.", "g2-u2", "t3"),
        ("الحرف والمصنوعات الشعبية", "من الحرف والمصنوعات الشعبية النسيج والسجاد والبسط والفخار والخزف وأعمال المعادن والنجارة والجلود.", "g2-u4", "t1"),
        ("الزخرفة الإسلامية", "من السمات البارزة في الزخرفة الإسلامية تنظيم الوحدات وتكرارها وملء المساحات بعلاقات زخرفية متناسقة.", "g2-u4", "t2"),
        ("الضوء والظل وإظهار الحجم", "يساعد الضوء والظل على إظهار حجم الأشكال وعمقها، ويعتمد التمثيل البصري على تدرج درجات الإضاءة والظل.", "g3-u1", "t1"),
        ("النسب والخطوط البنائية", "تساعد الخطوط البنائية على تنظيم الهيئة العامة وتحديد اتجاه الجسم وتوازنه.", "g3-u1", "t3"),
        ("التحوير", "التحوير هو إعادة صياغة العنصر الطبيعي وتبسيط تفاصيله أو تعديلها بما يلائم البناء الزخرفي مع الاحتفاظ بسماته الأساسية.", "g3-u2", "t1"),
        ("الخط الكوفي", "الخط الكوفي من الخطوط العربية ذات الطابع الهندسي، وتتميز حروفه ببنائها القائم على الخطوط والزوايا.", "g3-u2", "t2"),
        ("الملصق وعناصر الاتصال", "الملصق أو البوستر وسيلة اتصال بصري تعتمد على وضوح الفكرة وقوة التعبير وسرعة التأثير في المتلقي.", "g3-u2", "t3"),
        ("جماعة الرواد", "تأسست جماعة الرواد حول الفنان فائق حسن سنة ١٩٥٠، وجماعة بغداد للفن الحديث حول الفنان جواد سليم سنة ١٩٥١.", "g3-u4", "t1"),
    ]
    canonical_corpus = canon(corpus)
    glossary = []
    for order, (term, definition, unit_id, topic_id) in enumerate(entries, start=1):
        if unit_id not in by_id:
            raise SystemExit(f"glossary unit missing: {term} -> {unit_id}")
        topic_ids = {t["id"] for t in by_id[unit_id]["topics"]}
        if topic_id not in topic_ids:
            raise SystemExit(f"glossary topic missing: {term} -> {unit_id}/{topic_id}")
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
    units, plates = build_units_and_plates()
    intro = build_intro()
    theatre = build_theatre()
    lessons = build_lessons()
    glossary = build_glossary(units, intro)

    sections = [
        {"id": "intro", "title": "مدخل إلى التربية الفنية", "subtitle": "المقدمة والأهداف العامة وطرائق التدريس", "kind": "intro"},
        {"id": "g1", "title": "الصف الأول المتوسط", "subtitle": "ثلاث وحدات دراسية", "kind": "grade"},
        {"id": "g2", "title": "الصف الثاني المتوسط", "subtitle": "ثلاث وحدات دراسية", "kind": "grade"},
        {"id": "g3", "title": "الصف الثالث المتوسط", "subtitle": "ثلاث وحدات دراسية", "kind": "grade"},
        {"id": "lessons", "title": "دروس تطبيقية", "subtitle": "خطط الحصص النظرية والعملية", "kind": "lessons"},
        {"id": "plates", "title": "اللوحات", "subtitle": "أعمال فنية وصور توضيحية", "kind": "plates"},
        {"id": "theatre", "title": "مفردات الأنشطة المسرحية", "subtitle": "موضوعات الأنشطة المسرحية للمرحلة المتوسطة", "kind": "theatre"},
    ]

    curriculum = {
        "schemaVersion": 1,
        "title": "مِرسم",
        "subtitle": "التربية الفنية للمرحلة المتوسطة",
        "sections": sections,
        "units": [intro, theatre] + units,
    }

    by_id = {unit["id"]: unit for unit in curriculum["units"]}
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
    print(f"units: {len(curriculum['units'])} (9 grade units + intro + theatre)")
    print(f"topics: {topics}  questions: {questions}  lessons: {len(lessons)}  plates: {len(plates)}")


if __name__ == "__main__":
    main()
