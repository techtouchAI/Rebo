#!/usr/bin/env python3
"""
Build the teaching plans for the two review samples.

    python3 tools/build_teaching.py 19 14

Writes, per sample:
    samples/plan_<id>.docx        the deliverable (condensed + illustrated)
    samples/plan_<id>_full.docx   the verbatim facsimile (lossless proof)
    samples/model_<id>.json       the neutral model, teaching view included
    samples/changes_<id>.json     every text change, before/after

Sources are opened read-only and their SHA is verified before and after.
"""
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, "tools"))

from pipeline import compile_plan
from render_preview import convert


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def find_source(doc_id):
    for name in sorted(os.listdir(ROOT)):
        if name.startswith(doc_id + "_") and name.endswith(".docx"):
            return os.path.join(ROOT, name)
    raise SystemExit("no source for id %s" % doc_id)


def measure(path):
    import glob
    import tempfile
    base = os.path.join(tempfile.gettempdir(), "rebo_pg_" + os.path.basename(path))
    n = convert(path, base + ".pdf", None)
    if isinstance(n, tuple):
        n = n[0]
    for f in glob.glob(base + "*.pdf"):
        try:
            os.remove(f)
        except OSError:
            pass
    return n


def build(doc_id, out_dir):
    src = find_source(doc_id)
    before = sha(src)
    rec = compile_plan.build_pair(src, doc_id, out_dir, measure)
    after = sha(src)
    if before != after:
        raise SystemExit("SOURCE MODIFIED: %s" % src)

    st = rec["teaching"]["stats"]
    plates = sum(len(v) for v in rec["plates"].values())
    print("built %s  (%d pp, %d axes, %d plates)  + %s (%d pp)"
          % (rec["docx"], rec["pages"], st["axes"], plates,
             os.path.basename(rec["full_docx"]), rec["full_pages"]))
    print("      content kept %.0f%% of %d chars; %d units excluded, all logged"
          % (100 * st["ratio"], st["source_chars"], st["dropped_units"]))
    print("      quiz closure: %s" % ("all keyed answers taught"
                                      if rec["closure"][0] else "FAILED"))
    return rec


if __name__ == "__main__":
    ids = sys.argv[1:] or ["19", "14"]
    for i in ids:
        build(i, os.path.join(ROOT, "samples"))
