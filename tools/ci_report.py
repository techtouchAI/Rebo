#!/usr/bin/env python3
"""Turns analyzer / test output into GitHub Actions annotations.

GitHub only exposes workflow logs through a downloads domain that is not always
reachable, while the checks API (and therefore annotations) always is. This
script converts the machine readable output of `dart analyze --format machine`
and `flutter test --reporter json` into `::error` annotations, so failures can
be read back with `gh api repos/<owner>/<repo>/check-runs/<id>/annotations`.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

MAX_ANNOTATIONS = 50


def _clean(message: str) -> str:
    text = " ".join(message.split())
    return text[:900]


def emit(level: str, message: str) -> None:
    print(f"::{level}::{_clean(message)}")


def emit_at(level: str, path: str, line: str, message: str) -> None:
    print(f"::{level} file={path},line={line}::{_clean(message)}")


def report_analyze(path: Path) -> int:
    if not path.exists():
        emit("error", f"analyzer output missing: {path}")
        return 0
    counts: dict[str, int] = {}
    printed = 0
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = raw.split("|")
        if len(parts) < 8 or parts[0] not in {"ERROR", "WARNING", "INFO"}:
            continue
        severity, _kind, code, file, line, _col, _len, message = parts[:8]
        counts[severity] = counts.get(severity, 0) + 1
        if severity == "INFO":
            continue
        if printed < MAX_ANNOTATIONS:
            emit_at("error", file, line, f"{severity} {code}: {message}")
            printed += 1
    print(f"## analyzer summary: {counts}")
    if printed > MAX_ANNOTATIONS:
        emit("error", f"{printed - MAX_ANNOTATIONS} more analyzer issues not annotated")
    return 0


def report_test(path: Path) -> int:
    if not path.exists():
        emit("error", f"test output missing: {path}")
        return 0
    names: dict[int, str] = {}
    failures: list[tuple[str, str]] = []
    total = 0
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        raw = raw.strip()
        if not raw.startswith("{"):
            continue
        try:
            event = json.loads(raw)
        except json.JSONDecodeError:
            continue
        kind = event.get("type")
        if kind == "testStart":
            test = event.get("test") or {}
            names[event.get("testID", -1)] = str(test.get("name", "unnamed test"))
        elif kind == "testDone":
            total += 1
            if event.get("result") in {"failure", "error"} and not event.get("hidden"):
                name = names.get(event.get("testID", -1), "unnamed test")
                failures.append((name, event.get("result", "failure")))
        elif kind == "error":
            name = names.get(event.get("testID", -1), "unrelated error")
            message = str(event.get("error", "")).strip()
            if message:
                failures.append((name, message.splitlines()[0]))

    seen: set[str] = set()
    for name, message in failures:
        key = f"{name}|{message}"
        if key in seen:
            continue
        seen.add(key)
        if len(seen) > MAX_ANNOTATIONS:
            break
        emit("error", f"{name}: {message}")
    print(f"## tests: {total} finished, {len(failures)} failing events")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in {"analyze", "test"}:
        print("usage: ci_report.py analyze|test <output-file>", file=sys.stderr)
        return 2
    path = Path(argv[2])
    return report_analyze(path) if argv[1] == "analyze" else report_test(path)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
