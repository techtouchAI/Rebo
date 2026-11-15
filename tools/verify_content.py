#!/usr/bin/env python3
"""Verify that the generated app content matches the DOCX sources.

The check fails (non-zero exit code) when:

* any topic, bullet, question, answer, reason, or image from
  ``ملزمة_التربية_الفنية_بنموذج_إجابة_موحد.docx`` is missing or altered,
* a choice answer lacks explicit evidence in its unit text,
* a glossary definition cannot be traced back to the source,
* identifiers are duplicated, or a plate/illustration asset is missing.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from contentlib import (  # noqa: E402
    canon,
    parse_malzama_docx,
    read_docx_media,
    read_docx_plain_text,
)
from drawings_content import (  # noqa: E402
    DRAWINGS,
    DRAWINGS_TITLE,
)
from theatre_content import THEATRE_TOPICS  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "assets" / "content"
MALZAMA_DOC = ROOT / "ملزمة_التربية_الفنية_بنموذج_إجابة_موحد.docx"
DRAWINGS_DOC = ROOT / "التربية_الفنية_14_موضوعا_صورة_واحدة_لكل_موضوع.docx"
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


def main() -> int:
    curriculum = load("curriculum.json")
    lessons = load("lessons.json")
    glossary = load("glossary.json")
    plates = load("plates.json")
    drawings_json = load("drawings.json")

    units = curriculum["units"]
    grade_units = [unit for unit in units if unit["sectionId"] not in ("intro", "theatre")]
    intro = [unit for unit in units if unit["sectionId"] == "intro"]
    theatre = [unit for unit in units if unit["sectionId"] == "theatre"]

    expect(len(grade_units) == 9, f"expected 9 grade units, found {len(grade_units)}")
    expect(len(intro) == 1, "expected exactly one introduction unit")
    expect(len(theatre) == 1, "expected exactly one theatre section")
    expect(len({unit["id"] for unit in units}) == len(units), "duplicate unit ids")

    source_units, source_media = parse_malzama_docx(MALZAMA_DOC)
    expect(len(source_units) == 9, f"expected 9 source units, found {len(source_units)}")

    # 1. Every topic, bullet, question, answer, reason, and image of the
    #    unified booklet must survive verbatim into the generated JSON/assets.
    expected_plates = 0
    for unit, src in zip(grade_units, source_units):
        uid = unit["id"]
        expect(uid == src["id"], f"unit id mismatch: {uid} != {src['id']}")
        expect(canon(unit["title"]) == canon(src["title"]), f"[{uid}] title mismatch")
        expect(len(unit["topics"]) == len(src["topics"]), f"[{uid}] topic count mismatch")

        for topic, src_topic in zip(unit["topics"], src["topics"]):
            expect(canon(topic["title"]) == canon(src_topic["title"]), f"[{uid}/{topic['id']}] topic title mismatch")
            expect(len(topic["bullets"]) == len(src_topic["bullets"]), f"[{uid}/{topic['id']}] bullet count mismatch")
            for bullet, src_bullet in zip(topic["bullets"], src_topic["bullets"]):
                expect(canon(bullet) == canon(src_bullet), f"[{uid}/{topic['id']}] bullet mismatch: {src_bullet[:50]}")

        expect(len(unit["questions"]) == len(src["questions"]), f"[{uid}] question count mismatch")
        for q, src_q in zip(unit["questions"], src["questions"]):
            expect(q["kind"] == src_q["kind"], f"[{uid}/{q['id']}] kind mismatch")
            expect(canon(q["prompt"]) == canon(src_q["prompt"]), f"[{uid}/{q['id']}] prompt mismatch")
            if q["kind"] == "trueFalse":
                expect(q["answer"] == src_q["answer"], f"[{uid}/{q['id']}] trueFalse answer mismatch")
                if src_q.get("answerSupport"):
                    expect(
                        canon(q.get("answerSupport", "")) == canon(src_q["answerSupport"]),
                        f"[{uid}/{q['id']}] trueFalse reason mismatch",
                    )
            elif q["kind"] == "choice":
                expect(len(q["options"]) == len(src_q["options"]), f"[{uid}/{q['id']}] option count mismatch")
                for opt, src_opt in zip(q["options"], src_q["options"]):
                    expect(canon(opt) == canon(src_opt), f"[{uid}/{q['id']}] option mismatch")
                expect(q.get("answerIndex") == src_q["answerIndex"], f"[{uid}/{q['id']}] choice answerIndex mismatch")
            elif q["kind"] == "open":
                expect(canon(q["answer"]) == canon(src_q["answer"]), f"[{uid}/{q['id']}] open answer mismatch")

        src_images = src.get("images", [])
        unit_plates = unit.get("plates", [])
        expect(len(unit_plates) == len(src_images), f"[{uid}] plate count mismatch")
        expected_plates += len(src_images)
        for u_plate, src_img in zip(unit_plates, src_images):
            expect(canon(u_plate["caption"]) == canon(src_img["caption"]), f"[{uid}] plate caption mismatch")
            asset_file = ROOT / u_plate["asset"]
            expect(asset_file.exists(), f"missing unit plate file: {u_plate['asset']}")
            if asset_file.exists():
                expect(
                    asset_file.read_bytes() == source_media[src_img["media"]],
                    f"[{uid}] plate bytes differ from DOCX media {src_img['media']}",
                )

    # 2. Topics and questions integrity across all units
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
                expect(index is not None, f"[{unit['id']}/{question['id']}] choice without answerIndex")
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
    expect(total_questions == 73, f"expected 73 questions, found {total_questions}")

    # 3. Introduction
    intro_text = read_docx_plain_text(INTRO_DOC)
    intro_unit = intro[0]
    for topic in intro_unit["topics"]:
        for bullet in topic["bullets"]:
            expect(canon(bullet) in canon(intro_text), f"[intro] invented text: {bullet[:60]}")
            expect(len(bullet) > 20, "[intro] suspiciously short paragraph")
        for item in topic["listItems"]:
            expect(canon(item) in canon(intro_text), f"[intro] objective not in source: {item[:60]}")
        for method in topic.get("methods", []):
            expect(canon(method["title"])[:20] in canon(intro_text), f"[intro] method missing: {method['title'][:40]}")

    # 4. Lessons: one session per topic, presentation + home assignment only
    expect(len(lessons["lessons"]) == 4, "expected 4 lesson plans")
    dropped_fields = {"generalAims", "specificAims", "media", "introduction"}
    for lesson in lessons["lessons"]:
        expect(len(lesson["plans"]) == 1, f"[{lesson['id']}] expected a single session")
        source = "\n".join(
            read_docx_plain_text(ROOT / "محتوى مكتمل" / name)
            for name in LESSON_DOCS[lesson["title"]]
        )
        for plan in lesson["plans"]:
            expect(bool(plan.get("body")), f"[{lesson['id']}] lesson without content")
            expect(bool(plan["subject"]), f"[{lesson['id']}] lesson without subject")
            for field in dropped_fields:
                expect(field not in plan, f"[{lesson['id']}] weekly-plan field kept: {field}")
            for block in plan["body"]:
                expect(canon(block["text"]) in canon(source), f"[{lesson['id']}] invented block: {block['text'][:50]}")
            for item in plan["homework"]:
                expect(canon(item) in canon(source), f"[{lesson['id']}] invented homework: {item[:50]}")

    # 5. Glossary + plates
    malzama_text = "\n".join(u["unitText"] for u in grade_units)
    corpus = canon("\n".join([malzama_text, intro_text]))
    unit_map = {unit["id"]: unit for unit in units}
    for term in glossary["terms"]:
        expect(canon(term["definition"]) in corpus, f"glossary definition not in source: {term['term']}")
        expect(term["unitId"] in unit_map, f"glossary unit missing: {term['term']}")
        if term["unitId"] in unit_map and term.get("topicId"):
            expect(
                term["topicId"] in {t["id"] for t in unit_map[term["unitId"]]["topics"]},
                f"glossary topic missing: {term['term']} -> {term['unitId']}/{term['topicId']}",
            )
    expect(len(glossary["terms"]) >= 20, f"glossary too small: {len(glossary['terms'])}")

    expect(len(plates["plates"]) == expected_plates, f"expected {expected_plates} plates, found {len(plates['plates'])}")
    for plate in plates["plates"]:
        expect((ROOT / plate["asset"]).exists(), f"missing plate asset: {plate['asset']}")
        expect("المصدر:" not in plate["caption"], f"plate must carry no source credit: {plate['id']}")
        expect(plate["unitId"] in unit_map, f"plate unit missing: {plate['id']}")

    expect(
        all(section["kind"] != "plates" or "دليل" not in section["title"].lower() for section in curriculum["sections"]),
        "the plates section must not be named after the teacher guide",
    )

    # 6. Topic drawings: one source picture per topic, attached to its topic
    drawings = drawings_json["drawings"]
    expect(len(drawings) == len(DRAWINGS), f"expected {len(DRAWINGS)} drawings, found {len(drawings)}")
    expect(drawings_json.get("title") == DRAWINGS_TITLE, "the drawings section changed its title")
    expect(bool(drawings_json.get("intro")), "the drawings section has no introduction")
    source_pictures = read_docx_media(DRAWINGS_DOC)
    expect(
        len(source_pictures) == len(DRAWINGS),
        f"the drawings booklet holds {len(source_pictures)} pictures, expected {len(DRAWINGS)}",
    )
    drawing_assets: set[str] = set()
    for index, (drawing, spec) in enumerate(zip(drawings, DRAWINGS), start=1):
        did = drawing["id"]
        expect(did == f"drawing-{index:02d}", f"drawing id out of document order: {did}")
        expect(drawing["order"] == index, f"[{did}] wrong order")
        expect(
            canon(drawing["title"]) == canon(spec["title"]),
            f"[{did}] caption differs from its source page: {drawing['title']}",
        )
        expect(drawing["unitId"] == spec["unitId"], f"[{did}] unit link changed")
        expect(drawing["topicId"] == spec["topicId"], f"[{did}] topic link changed")
        unit = unit_map.get(drawing["unitId"])
        expect(
            unit is not None and unit["sectionId"] not in ("intro", "theatre"),
            f"[{did}] the drawing is not attached to a grade unit",
        )
        if unit is not None:
            topics = {topic["id"]: topic for topic in unit["topics"]}
            expect(drawing["topicId"] in topics, f"[{did}] drawing topic missing in {drawing['unitId']}")
            if drawing["topicId"] in topics:
                topic = topics[drawing["topicId"]]
                expect(
                    canon(drawing["topicTitle"]) == canon(topic["title"]),
                    f"[{did}] topic title mismatch",
                )
                expected_caption = f"{unit['displayTitle']} — {topic['title']}"
                expect(
                    canon(drawing["caption"]) == canon(expected_caption),
                    f"[{did}] caption is not derived from its unit and topic",
                )
            expect(drawing["unitTitle"] == unit["displayTitle"], f"[{did}] unit title mismatch")
            expect(drawing["grade"] == unit["grade"], f"[{did}] grade mismatch")
        asset = ROOT / drawing["asset"]
        expect(asset.exists(), f"[{did}] missing picture: {drawing['asset']}")
        expect(drawing["asset"] not in drawing_assets, f"[{did}] the same picture is reused")
        drawing_assets.add(drawing["asset"])
        if asset.exists() and index <= len(source_pictures):
            expect(
                asset.read_bytes() == source_pictures[index - 1][1],
                f"[{did}] picture bytes differ from source page {index}",
            )
    expect(
        len({drawing["unitId"] for drawing in drawings}) >= 5,
        "the drawings are not spread across the grade units",
    )
    expect(
        any(section["kind"] == "drawings" for section in curriculum["sections"]),
        "the drawings section is missing from the table of contents",
    )
    expect(
        all(unit["sectionId"] != "drawings" for unit in units),
        "the drawings must be a section of their own, not a unit",
    )
    expect(
        all(plate["asset"] not in drawing_assets for plate in plates["plates"]),
        "a topic drawing was shipped as a plate",
    )

    # 7. Theatre
    theatre_unit = theatre[0]
    expect(bool(theatre_unit["topics"]), "the theatre section has no topics")
    expect(len(theatre_unit["topics"]) >= 5, f"the theatre section lost topics: {len(theatre_unit['topics'])}")
    expect(
        [topic["title"] for topic in theatre_unit["topics"]]
        == [topic["title"] for topic in THEATRE_TOPICS],
        "the theatre topics left their transcribed source",
    )
    for topic in theatre_unit["topics"]:
        expect(bool(topic["title"].strip()), "theatre topic without title")
        for bullet in topic["bullets"]:
            expect(bool(bullet.strip()), "theatre topic without content")
    expect(bool(theatre_unit.get("intro")), "the theatre section has no introduction")
    expect(
        all("theatre" != plate["unitId"] for plate in plates["plates"]),
        "the theatre section must not be shipped as a plate",
    )

    # 8. Illustrations referenced by content must exist
    figures = [figure for unit in units for figure in unit.get("figures", [])]
    figures += [figure for lesson in lessons["lessons"] for figure in lesson.get("figures", [])]
    for figure in figures:
        expect((ROOT / figure["asset"]).exists(), f"missing illustration: {figure['asset']}")
    expect(len({figure["asset"] for figure in figures}) >= 10, "not enough illustrations")

    if errors:
        print(f"content verification FAILED ({len(errors)} problems / {checks} checks)")
        for error in errors[:40]:
            print(" -", error)
        return 1
    print(f"content verification passed ({checks} checks)")
    print(
        f"units={len(units)} topics={sum(len(u['topics']) for u in units)} "
        f"questions={total_questions} plates={len(plates['plates'])} drawings={len(drawings)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
