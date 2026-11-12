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


def detail(text: str) -> str:
    """Keeps the interesting part of a Flutter test failure message."""
    flat = " ".join(text.split())
    marker = "relevant error-causing widget was:"
    index = flat.find(marker)
    if index >= 0:
        return f"{flat[:280]} … {flat[index:index + 300]}"
    return flat[:700]


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
    messages: dict[int, list[str]] = {}
    current: int | None = None
    failing: list[int] = []
    total = 0
    errors: list[tuple[str, str]] = []

    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    for raw in lines:
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
            test_id = test.get("id")
            if isinstance(test_id, int):
                current = test_id
                names[test_id] = str(test.get("name", "unnamed test"))
                messages[test_id] = []
        elif kind == "print" and current is not None:
            messages.setdefault(current, []).append(str(event.get("message", "")))
        elif kind == "testDone":
            total += 1
            if event.get("result") in {"failure", "error"} and not event.get("hidden"):
                failing.append(int(event.get("testID", -1)))
        elif kind == "error":
            name = names.get(event.get("testID", -1), "unrelated error")
            detail = " ".join(str(event.get("error", "")).split())
            trace = str(event.get("stackTrace", "")).splitlines()
            if detail:
                errors.append((name, detail[:500]))
            if trace:
                errors.append((name, " at " + trace[0].strip()[:300]))

    for test_id in failing:
        name = names.get(test_id, "unnamed test")
        body = messages.get(test_id, [])
        highlight = [line for line in body if "EXCEPTION" in line or "was thrown" in line or "Unable to" in line]
        detail = highlight[0] if highlight else next((line for line in body if line.strip()), "test failed")
        errors.insert(0, (name, detail))

    emitted: set[str] = set()
    for name, message in errors:
        key = f"{name}|{message}"[:200]
        if key in emitted:
            continue
        emitted.add(key)
        if len(emitted) > MAX_ANNOTATIONS:
            break
        emit("error", f"{name} :: {detail(message)}")

    print(f"## tests: {total} finished, {len(failing)} failing")
    return 0


ERROR_HINTS = (
    "error",
    "fatal",
    "failed",
    "exception",
    "undefined reference",
    "cannot open",
    "not found",
    "msbuild",
    "cmake error",
)


def report_log(path: Path) -> int:
    """Annotates the first error-looking lines of an arbitrary build log."""
    if not path.exists():
        emit("error", f"build log missing: {path}")
        return 0
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    matched: list[str] = []
    for index, raw in enumerate(lines):
        line = raw.strip()
        lowered = line.lower()
        if not line or len(line) < 6:
            continue
        if any(hint in lowered for hint in ERROR_HINTS):
            following = ""
            for candidate in lines[index + 1 : index + 4]:
                if candidate.strip():
                    following = candidate.strip()
                    break
            matched.append(f"{line} {following}".strip())
    seen: set[str] = set()
    for line in matched:
        if line in seen:
            continue
        seen.add(line)
        if len(seen) > MAX_ANNOTATIONS:
            break
        emit("error", line)
    tail = " | ".join(item.strip() for item in lines[-16:] if item.strip())
    if matched:
        emit("error", f"log tail: {tail}")
    else:
        emit("error", f"no explicit error line found; tail: {tail}")
    print(f"## build log: {len(lines)} lines, {len(matched)} error-like lines")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in {"analyze", "test", "log"}:
        print("usage: ci_report.py analyze|test|log <output-file>", file=sys.stderr)
        return 2
    path = Path(argv[2])
    if argv[1] == "analyze":
        return report_analyze(path)
    if argv[1] == "test":
        return report_test(path)
    return report_log(path)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
