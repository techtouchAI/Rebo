"""
Orchestrator: source .docx -> teaching plan .docx.

The nine responsibilities the brief asks for are kept apart:

    1 extract      pipeline/extract.py     read the source, nothing else
    2 analyse      pipeline/didactic.py    axes, parts, timeline
    3 classify     pipeline/didactic.py    closed-set unit classification
    4 condense     pipeline/didactic.py    selection (verbatim slices only)
    5 need-plate   pipeline/figures_map.py which axis needs which plate
    6 draw         pipeline/figurelib.py   deterministic cached plates
    7 assemble     pipeline/render.py      teaching view + verbatim view
    8 layout       pipeline/render.py      the design's table/page frame
    9 verify       pipeline/quiz.py + tools/check_didactic.py

No condensation or drawing logic lives inside the DOCX writer.
"""
from __future__ import annotations

import json
import os

from . import didactic, figures_map, quiz, render
from .clean import clean_document
from .extract import extract


def build(src, doc_id, out_dir, total_pages=None, cache_dir=None):
    """
    Produce the teaching model + DOCX.

    Returns a dict with the model, the audit trail and the paths written, so a
    caller can render, measure pages and re-render with a correct page count
    without re-running any of the analysis.
    """
    ext = extract(src)
    model, changes = clean_document(ext, doc_id)

    teaching = didactic.condense(model)
    timeline = didactic.timeline_events(
        " ".join(r["value"] for r in model["content_rows"]))
    attachments, plate_log, plate_map = figures_map.resolve(
        teaching, timeline, out_dir=cache_dir)

    qz = quiz.extract(model["appendix"])
    qz["generated"] = quiz.generated(teaching)
    closure_ok, closure_rows = quiz.validate(qz, teaching)

    model["_attachments"] = attachments
    model["_timeline"] = timeline
    model["_plates"] = {"map": plate_map, "log": plate_log}
    model["_quiz"] = qz
    model["_quiz_check"] = {"ok": closure_ok, "rows": closure_rows}
    model["_stats"] = teaching["stats"]

    os.makedirs(out_dir, exist_ok=True)
    out_docx = os.path.join(out_dir, "plan_%s.docx" % doc_id)
    render.render_teaching(model, out_docx, total_pages=total_pages)
    return {"model": model, "teaching": teaching, "changes": changes,
            "ext": ext, "docx": out_docx, "plates": attachments,
            "quiz": qz, "closure": (closure_ok, closure_rows)}


def build_pair(src, doc_id, out_dir, measure, cache_dir=None):
    """
    Build both views, measuring pages once each.

    `measure(path) -> int` is injected so this module never imports the preview
    engine (that would couple the pipeline to a verification tool).
    """
    rec = build(src, doc_id, out_dir, cache_dir=cache_dir)
    pages = measure(rec["docx"])
    render.render_teaching(rec["model"], rec["docx"], total_pages=pages)
    final = measure(rec["docx"])
    if final != pages:
        render.render_teaching(rec["model"], rec["docx"], total_pages=final)
        pages = final
    rec["pages"] = pages

    # the verbatim view is a separate file: it is the facsimile proof, not the
    # deliverable, so it keeps its own page count
    full = os.path.join(out_dir, "plan_%s_full.docx" % doc_id)
    render.render(rec["model"], full)
    fpages = measure(full)
    render.render(rec["model"], full, total_pages=fpages)
    rec["full_docx"] = full
    rec["full_pages"] = fpages

    with open(os.path.join(out_dir, "model_%s.json" % doc_id), "w",
              encoding="utf-8") as fh:
        json.dump(rec["model"], fh, ensure_ascii=False, indent=1)
    with open(os.path.join(out_dir, "changes_%s.json" % doc_id), "w",
              encoding="utf-8") as fh:
        json.dump([c.to_dict() for c in rec["changes"]], fh,
                  ensure_ascii=False, indent=1)
    return rec
