#!/usr/bin/env python3
"""
Write the machine-generated half of the final report.

Everything here is measured, not narrated: ratios, exclusion counts, the plate
inventory, before/after excerpts and the test totals.  The report's prose lives
in the markdown file; its numbers live here.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from pipeline import compile_plan, figures_map


def load(doc_id):
    return json.load(open(os.path.join(ROOT, "samples", "model_%s.json" % doc_id),
                          encoding="utf-8"))


def main():
    out = {"samples": {}}
    for i in ("19", "14"):
        m = load(i)
        t = m["teaching"]
        st = t["stats"]
        plates = []
        axes = {a["n"]: a for s in t["sections"] for a in s["axes"]}
        for n, items in m["_attachments"].items():
            for p in items:
                plates.append({
                    "axis": int(n),
                    "axis_title": axes[int(n)].get("title", ""),
                    "plate": p["name"],
                    "caption": p["caption"],
                    "kind": p["kind"],
                    "where": "بعد محور %s" % n,
                })
        src_rows = len(m["content_rows"])
        # before/after: one axis whose procedural units were excluded
        sample = None
        for sec in t["sections"]:
            for a in sec["axes"]:
                if len(a["dropped"]) >= 3 and len(a["blocks"]) >= 2:
                    sample = {
                        "axis": a["n"],
                        "title": a["title"],
                        "before_chars": a["source_chars"],
                        "after_chars": a["kept_chars"],
                        "kept": [b["text"] for b in a["blocks"]],
                        "dropped": [{"text": d["text"], "reason": d["reason"]}
                                    for d in a["dropped"]],
                    }
                    break
            if sample:
                break
        out["samples"][i] = {
            "stats": st,
            "pages": None,
            "source_rows": src_rows,
            "plates": plates,
            "plate_count": len(plates),
            "timeline": m.get("_timeline", []),
            "quiz": {
                "mc": len(m["_quiz"]["mc"]),
                "tf": len(m["_quiz"]["tf"]),
                "key": m["_quiz"]["key"],
                "generated": m["_quiz"]["generated"],
            },
            "closure": m["_quiz_check"],
            "example": sample,
            "sections": [{"title": s["title"],
                          "axes": [a["n"] for a in s["axes"]]}
                         for s in t["sections"]],
            "excluded_by_reason": st["by_reason"],
        }
    path = os.path.join(ROOT, "samples", "report_assets.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)
    print("wrote", path)
    for i, v in out["samples"].items():
        print(" %s: axes=%d plates=%d kept=%.0f%% excluded=%d"
              % (i, v["stats"]["axes"], v["plate_count"],
                 100 * v["stats"]["ratio"], v["stats"]["dropped_units"]))


if __name__ == "__main__":
    main()
