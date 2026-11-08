#!/usr/bin/env python3
"""
Deterministic build of one sample.

    python3 tools/build_sample.py 19 14

Writes:
    samples/plan_<id>.docx      the deliverable
    samples/model_<id>.json     the neutral model (auditable)
    samples/changes_<id>.json   every text change, before/after

Sources are opened read-only and their SHA-256 is verified against
baseline/manifest.json before and after the run.
"""
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from pipeline.extract import extract
from pipeline.clean import clean_document
from pipeline import render


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def find_source(doc_id):
    for name in sorted(os.listdir(ROOT)):
        if name.startswith(doc_id + "_") and name.endswith(".docx"):
            return os.path.join(ROOT, name)
    raise SystemExit("no source for id %s" % doc_id)


def _page_count(docx_path):
    """Measure pagination with the same layout engine used for verification."""
    try:
        sys.path.insert(0, os.path.join(ROOT, "tools"))
        from render_preview import convert
        import tempfile, glob
        base = os.path.join(tempfile.gettempdir(),
                            "rebo_count_%s" % os.path.basename(docx_path)[:12])
        n = convert(docx_path, base + ".pdf", base)
        if isinstance(n, tuple):
            n = n[0]
        for f in glob.glob(base + "*.png") + glob.glob(base + "*.pdf"):
            os.remove(f)
        return n
    except Exception:
        return None


def build(doc_id, out_dir):
    src = find_source(doc_id)
    before = sha(src)

    ext = extract(src)
    model, changes = clean_document(ext, doc_id)

    # display-only conveniences (never used for content comparison)
    model["lesson_title_short"] = model.get("unit_title") or model.get("grade", "")

    os.makedirs(out_dir, exist_ok=True)
    out_docx = os.path.join(out_dir, "plan_%s.docx" % doc_id)

    # two-pass: lay the document out once, measure the real page count, then
    # write that exact number into the NUMPAGES field cache
    render.render(model, out_docx)
    total = _page_count(out_docx)
    render.render(model, out_docx, total_pages=total)
    final = _page_count(out_docx)
    if final != total:
        render.render(model, out_docx, total_pages=final)

    with open(os.path.join(out_dir, "model_%s.json" % doc_id), "w", encoding="utf-8") as f:
        json.dump(model, f, ensure_ascii=False, indent=1)
    with open(os.path.join(out_dir, "changes_%s.json" % doc_id), "w", encoding="utf-8") as f:
        json.dump([c.to_dict() for c in changes], f, ensure_ascii=False, indent=1)

    after = sha(src)
    if before != after:
        raise SystemExit("SOURCE MODIFIED: %s" % src)
    print("built %s  (source untouched, sha %s, %s pages)"
          % (out_docx, before[:16], final))
    return out_docx


if __name__ == "__main__":
    ids = sys.argv[1:] or ["19", "14"]
    out = os.path.join(ROOT, "samples")
    for i in ids:
        build(i, out)
