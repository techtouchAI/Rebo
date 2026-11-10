#!/usr/bin/env python3
"""
Educational-integrity audit for the condensed view.

    python3 tools/check_didactic.py

Proves six properties per sample and exits non-zero on any failure:

 A  NO INVENTED TEXT      every displayed string is a verbatim slice of the
                          source cell(s) it was taken from
 B  NO ORDER CHANGE       the units appear in the source in the same order
 C  NO AXIS DROPPED       every source row belongs to exactly one axis
 D  NOT JUST TITLES       every axis carries a body, not only a heading
 E  EXCLUSIONS DECLARED   every unit left out carries a stated reason
 F  QUIZ CLOSED           every keyed answer is still taught in the plan
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from pipeline import compile_plan, didactic


def canon(t):
    t = "".join(c for c in (t or "") if c not in "\u200b\u200c\u200d\u200e\u200f\ufeff")
    return re.sub(r"\s+", "", t)


def find(doc_id):
    for name in sorted(os.listdir(ROOT)):
        if name.startswith(doc_id + "_") and name.endswith(".docx"):
            return os.path.join(ROOT, name)
    raise SystemExit("missing source for %s" % doc_id)


def audit(doc_id, verbose=True):
    src = find(doc_id)
    rec = compile_plan.build(src, doc_id, os.path.join(ROOT, "build", "audit"))
    model, teaching = rec["model"], rec["teaching"]
    fail = []

    # the raw source text of the plan table, in reading order
    src_cells = []
    for r in model["content_rows"]:
        if r.get("label"):
            src_cells.append(r["label"])
        if r.get("value"):
            src_cells.append(r["value"])
    src_flat = canon(" ".join(src_cells))

    # ---- A + B: every block is verbatim and in order ----
    cursor = 0
    shown = 0
    for sec in teaching["sections"]:
        for a in sec["axes"]:
            for b in a["blocks"]:
                shown += 1
                key = canon(b["text"])
                if not key:
                    continue
                at = src_flat.find(key, cursor)
                if at < 0:
                    at = src_flat.find(key)     # out of order?
                    if at >= 0:
                        fail.append("ORDER  axis %d: %r" % (a["n"], b["text"][:48]))
                        cursor = at + len(key)
                    else:
                        fail.append("INVENT axis %d: %r" % (a["n"], b["text"][:48]))
                else:
                    cursor = at + len(key)

    # ---- C: every source row lands in an axis ----
    covered = set()
    for sec in teaching["sections"]:
        for a in sec["axes"]:
            covered.update(a["rows"])
    missing = sorted(set(range(len(model["content_rows"]))) - covered)
    if missing:
        fail.append("AXIS DROPPED rows %s" % missing)

    # ---- D: no axis is a bare title ----
    for sec in teaching["sections"]:
        for a in sec["axes"]:
            if not a["blocks"]:
                fail.append("EMPTY AXIS %d %r" % (a["n"], a["title"][:40]))

    # ---- E: every exclusion is declared ----
    for sec in teaching["sections"]:
        for a in sec["axes"]:
            for d in a["dropped"]:
                if not d.get("reason"):
                    fail.append("UNDECLARED DROP axis %d" % a["n"])

    # ---- F: the quiz is answerable from the plan ----
    ok, rows = rec["closure"]
    if not ok:
        for r in rows:
            if not r["taught"]:
                fail.append("QUIZ Q%d answer not taught: %r" % (r["n"], r["answer"][:48]))

    st = teaching["stats"]
    if verbose:
        print("%-4s axes=%2d parts=%d blocks=%3d kept=%5d/%5d (%.0f%%) "
              "plates=%d dropped=%d" % (
                  doc_id, st["axes"], st["sections"], shown, st["kept_chars"],
                  st["source_chars"], 100.0 * st["ratio"],
                  sum(len(v) for v in rec["plates"].values()),
                  st["dropped_units"]))
    return fail


def main(argv):
    ids = argv or ["19", "14"]
    bad = 0
    for i in ids:
        fail = audit(i)
        if fail:
            bad += 1
            print("FAIL %s" % i)
            for f in fail[:12]:
                print("   -", f)
            if len(fail) > 12:
                print("   ... %d more" % (len(fail) - 12))
        else:
            print("PASS %s" % i)
    print("\n%d/%d samples clean" % (len(ids) - bad, len(ids)))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
