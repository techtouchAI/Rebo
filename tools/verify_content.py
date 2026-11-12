#!/usr/bin/env python3
"""Verify that the generated app content matches the DOCX sources.

The check fails (non-zero exit code) when:

* a line of a source table is missing from the generated JSON,
* a question, answer or glossary definition cannot be traced back to the source,
* identifiers are duplicated, or a plate image is missing.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import docx

sys.path.insert(0, str(Path(__file__).parent))
from contentlib import canon, docx_text, parse_questions, parse_topics, polish  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "assets" / "content"
SUMMARY_DOC = ROOT / "محتوى مكتمل" / "ملخص_التربية_الفنية.docx"
INTRO_DOC = ROOT / "محتوى مكتمل" / "مقدمة.docx"
LESSON_DOCS = {
    "الظل والضوء": ["الظل والضوء.docx", "الظل والضوء العملي.docx"],
    "المنظور": ["المنظور.docx", "المنظور العملي.docx"],
    "الزخرفة": ["الرخرفة.docx", "الزخرفة عملي.docx"],
    "تصميم غلاف كتاب": ["تصميم غلاف كتاب.docx", "تصميم غلاف كتاب عملي.docx"],
}

errors: list[str] = []
checks = 0


def fail(message: str) -> None:
    errors.append(message)


def expect(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        fail(message)


def load(name: str) -> dict:
    with (CONTENT / name).open(encoding="utf-8") as handle:
        return json.load(handle)


def unit_source_cells() -> list[list[list[str]]]:
    """The topic-table cell lines of every unit, grouped per unit."""
    document = docx.Document(str(SUMMARY_DOC))
    units: list[list[list[str]]] = []
    current: list[list[str]] | None = None
    for table in document.tables:
        lines_per_cell = []
        for row in table.rows:
            for cell in row.cells:
                lines = [polish(line) for line in cell.text.split("\n") if polish(line)]
                lines_per_cell.append(lines)
        units.append(lines_per_cell)
    return units


def main() -> int:
    curriculum = load("curriculum.json")
    lessons = load("lessons.json")
    glossary = load("glossary.json")
    plates = load("plates.json")

    units = curriculum["units"]
    grade_units = [unit for unit in units if unit["sectionId"] != "intro"]
    intro = [unit for unit in units if unit["sectionId"] == "intro"]

    expect(len(grade_units) == 12, f"expected 12 grade units, found {len(grade_units)}")
    expect(len(intro) == 1, "expected exactly one introduction unit")
    expect(len({unit["id"] for unit in units}) == len(units), "duplicate unit ids")

    tables = unit_source_cells()
    expect(len(tables) == 12, f"expected 12 source tables, found {len(tables)}")

    # 1. every line of every source cell must survive into the unit JSON
    for unit, cells in zip(grade_units, tables):
        unit_text = canon(json.dumps(unit, ensure_ascii=False))
        for lines in cells:
            for line in lines:
                stripped = line.lstrip("•").strip()
                if stripped.startswith("تعداد") or not stripped:
                    continue
                if stripped[:2].rstrip("-").isdigit() and "-" in stripped[:3]:
                    stripped = stripped.split("-", 1)[1].strip()
                expect(canon(stripped) in unit_text, f"[{unit['id']}] lost source line: {stripped[:60]}")

    # 2. topics/questions integrity
    total_questions = 0
    for unit in units:
        expect(bool(unit["topics"]), f"[{unit['id']}] has no topics")
        expect(bool(unit.get("template")), f"[{unit['id']}] has no presentation template")
        for topic in unit["topics"]:
            expect(bool(topic["title"].strip()), f"[{unit['id']}] topic without title")
            for bullet in topic["bullets"]:
                expect(bool(bullet.strip()), f"[{unit['id']}/{topic['id']}] empty bullet")
            expect(
                len(topic["listItems"]) >= 1 or not topic["listTitle"],
                f"[{unit['id']}/{topic['id']}] list title without items",
            )
        question_ids = [question["id"] for question in unit["questions"]]
        expect(len(set(question_ids)) == len(question_ids), f"[{unit['id']}] duplicate question ids")
        total_questions += len(unit["questions"])
        for question in unit["questions"]:
            expect(bool(question["prompt"].strip()), f"[{unit['id']}] question without prompt")
            if question["kind"] == "trueFalse":
                expect(isinstance(question["answer"], bool), f"[{unit['id']}] bad true/false answer")
            if question["kind"] == "choice":
                expect(len(question["options"]) >= 2, f"[{unit['id']}] choice with one option")
                index = question.get("answerIndex")
                if index is not None:
                    expect(0 <= index < len(question["options"]), f"[{unit['id']}] bad answer index")
                    support = canon(question.get("answerSupport") or "")
                    expect(bool(support), f"[{unit['id']}] answer without evidence")
                    expect(
                        support in canon(unit.get("unitText", "")),
                        f"[{unit['id']}] answer evidence not in unit text",
                    )
            if question["kind"] == "open":
                expect(bool(question["answer"].strip()), f"[{unit['id']}] open question without answer")
    expect(total_questions >= 60, f"unexpectedly few questions: {total_questions}")

    # 3. every question of the source document must be represented
    source_questions = collect_source_questions()
    generated = {
        canon(question["prompt"])
        for unit in units
        for question in unit["questions"]
    }
    for prompt in source_questions:
        expect(canon(prompt) in generated, f"question dropped: {prompt[:70]}")

    # 4. introduction
    intro_text = docx_text(docx.Document(str(INTRO_DOC)))
    intro_unit = intro[0]
    for topic in intro_unit["topics"]:
        for bullet in topic["bullets"]:
            expect(canon(bullet) in canon(intro_text), f"[intro] invented text: {bullet[:60]}")
            expect(len(bullet) > 20, "[intro] suspiciously short paragraph")
        for item in topic["listItems"]:
            expect(canon(item) in canon(intro_text), f"[intro] objective not in source: {item[:60]}")
        for method in topic.get("methods", []):
            expect(canon(method["title"])[:20] in canon(intro_text), f"[intro] method missing: {method['title'][:40]}")

    # 5. lessons
    expect(len(lessons["lessons"]) == 4, "expected 4 lesson plans")
    for lesson in lessons["lessons"]:
        expect(len(lesson["plans"]) == 2, f"[{lesson['id']}] expected theory + practice")
        source = "\n".join(
            docx_text(docx.Document(str(ROOT / "محتوى مكتمل" / name)))
            for name in LESSON_DOCS[lesson["title"]]
        )
        blocks = [plan for plan in lesson["plans"]]
        for plan in blocks:
            expect(bool(plan["specificAims"]), f"[{lesson['id']}] lesson without objectives")
            for aim in plan["specificAims"]:
                expect(canon(aim) in canon(source), f"[{lesson['id']}] invented objective: {aim[:50]}")
            for block in plan["body"]:
                expect(canon(block["text"]) in canon(source), f"[{lesson['id']}] invented block: {block['text'][:50]}")

    # 6. glossary + plates
    corpus = canon("\n".join([docx_text(docx.Document(str(SUMMARY_DOC))), intro_text]))
    for term in glossary["terms"]:
        expect(canon(term["definition"]) in corpus, f"glossary definition not in source: {term['term']}")
        expect(term["unitId"] in {unit["id"] for unit in units}, f"glossary unit missing: {term['term']}")
    expect(len(glossary["terms"]) >= 15, "glossary too small")

    expect(len(plates["plates"]) == 13, f"expected 13 plates, found {len(plates['plates'])}")
    for plate in plates["plates"]:
        expect((ROOT / plate["asset"]).exists(), f"missing plate asset: {plate['asset']}")
        expect(plate["source"].startswith("المصدر:"), f"plate without source: {plate['id']}")

    # 7. illustrations referenced by content must exist
    figures = [figure for unit in units for figure in unit.get("figures", [])]
    figures += [figure for lesson in lessons["lessons"] for figure in lesson.get("figures", [])]
    for figure in figures:
        expect((ROOT / figure["asset"]).exists(), f"missing illustration: {figure['asset']}")
    expect(len({figure["asset"] for figure in figures}) >= 12, "not enough illustrations")

    # 8. every unit that belongs to a grade carries its plate
    for unit in grade_units:
        expect(bool(unit.get("plate")), f"[{unit['id']}] unit without teacher-guide plate")

    if errors:
        print(f"content verification FAILED ({len(errors)} problems / {checks} checks)")
        for error in errors[:40]:
            print(" -", error)
        return 1
    print(f"content verification passed ({checks} checks)")
    print(f"units={len(units)} topics={sum(len(u['topics']) for u in units)} questions={total_questions}")
    return 0


def collect_source_questions() -> list[str]:
    """Prompts of the unit question banks, in source order."""
    document = docx.Document(str(SUMMARY_DOC))
    paragraphs = [polish(p.text) for p in document.paragraphs if p.text.strip()]
    lines: list[str] = []
    mode = None
    for text in paragraphs:
        if text in ("صح وخطأ", "الاختيارات", "التعداد"):
            mode = text
            continue
        if mode is None:
            continue
        if text == "أسئلة الوحدة" or text.startswith("الوحدة") or text.startswith("الصف"):
            mode = None
            continue
        if mode in ("صح وخطأ", "الاختيارات"):
            head = text.split("|")[0]
            if "الإجابة:" in head:
                head = head.split("الإجابة:")[0]
            head = head.strip()
            if head[:1].isdigit() and "-" in head[:3]:
                head = head.split("-", 1)[1].strip()
            if mode == "صح وخطأ":
                lines.append(head)
            elif "؟" in head:
                lines.append(polish(head.split("؟")[0] + "؟"))
        else:
            if text.startswith("الإجابة:"):
                continue
            stripped = text
            if stripped[:1].isdigit() and "-" in stripped[:3]:
                stripped = stripped.split("-", 1)[1].strip()
            lines.append(stripped)
    return lines


if __name__ == "__main__":
    raise SystemExit(main())
