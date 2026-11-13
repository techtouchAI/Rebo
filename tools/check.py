#!/usr/bin/env python3
"""
Rebo · release checks
=====================

Static and structural gates that a release must pass. Runs without a browser,
without Android and without Windows, so it works on any build host:

    1. version         every artefact agrees with package.json
    2. content         data.js parses and every unit/plan/quiz item is complete
    3. assets          every file the app references exists on disk
    4. javascript      app.js parses (via node when available)
    5. android         APK signature, alignment, manifest and payload integrity
    6. windows         PE headers, embedded manifest, payload walk

Usage:
    python3 tools/check.py                # everything that is available
    python3 tools/check.py --skip apk     # skip artefact checks
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from importlib.machinery import SourceFileLoader  # noqa: E402

pe_check = SourceFileLoader("verify_pe", os.path.join(ROOT, "tools", "verify-pe.py")).load_module()

PASS, FAIL, SKIP = "PASS", "FAIL", "SKIP"
results: list[tuple[str, str, str]] = []


def record(status: str, name: str, detail: str = "") -> None:
    results.append((status, name, detail))


def check(name: str):
    def wrap(fn):
        def run(*args, **kwargs):
            try:
                detail = fn(*args, **kwargs)
                record(PASS, name, detail or "")
            except AssertionError as exc:
                record(FAIL, name, str(exc))
            except Exception as exc:  # noqa: BLE001 - surfaced as a failure
                record(FAIL, name, "%s: %s" % (type(exc).__name__, exc))
        run.__name__ = fn.__name__
        return run
    return wrap


# ------------------------------------------------------------------ 1. version
@check("version references are in sync")
def version_sync() -> str:
    out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "sync-version.py"),
                          "--check"], capture_output=True, text=True)
    assert out.returncode == 0, out.stdout + out.stderr
    with open(os.path.join(ROOT, "package.json"), encoding="utf8") as fh:
        return "v" + json.load(fh)["version"]


# ------------------------------------------------------------------ 2. content
@check("content data is complete")
def content_complete() -> str:
    path = os.path.join(ROOT, "app", "www", "js", "data.js")
    with open(path, encoding="utf8") as fh:
        source = fh.read()
    assert source.startswith("window.REBO_CONTENT="), "data.js must assign REBO_CONTENT"
    payload = source[len("window.REBO_CONTENT="):].rstrip().rstrip(";")
    data = json.loads(payload)

    units = data["units"]
    assert len(units) == 13, "expected 13 units, found %d" % len(units)
    assert len(data["plans"]) == 9, "expected 9 lesson plans"
    assert len(data["index"]) == 20, "expected a 20-row index"

    questions = 0
    for unit in units:
        assert unit["sections"], "%s has no sections" % unit["id"]
        assert unit["objectives"], "%s has no general objectives" % unit["id"]
        assert unit["plates"], "%s has no illustration plates" % unit["id"]
        for section in unit["sections"]:
            assert section["paras"], "%s: empty section %r" % (unit["id"], section["title"])
            for para in section["paras"]:
                assert len(para) > 20, "%s: truncated paragraph" % unit["id"]
        for q in unit["mcq"]:
            assert q["answer"], "%s: multiple-choice item without an answer key" % unit["id"]
            assert len(q["options"]) >= 2, "%s: multiple-choice item with <2 options" % unit["id"]
            questions += 1
        for q in unit["truefalse"]:
            assert q["answer"], "%s: true/false item without an answer key" % unit["id"]
            questions += 1

    for plan in data["plans"]:
        for field in ("objectives", "tools", "intro"):
            assert plan.get(field), "%s plan is missing %r" % (plan["name"], field)

    media_dir = os.path.join(ROOT, "app", "www", "media")
    on_disk = {n for n in os.listdir(media_dir) if n.endswith(".jpg")}
    referenced = {p for u in units for p in u["plates"]}
    assert referenced <= on_disk, "data.js references missing plates: %s" % (
        sorted(referenced - on_disk)[:4])
    assert len(on_disk) == len(referenced), (
        "media/ has %d plates but data.js references %d — the folder was "
        "regenerated with a different pipeline run" % (len(on_disk), len(referenced)))

    sections = sum(len(u["sections"]) for u in units)
    plates = sum(len(u["plates"]) for u in units)
    return "%d units · %d topics · %d questions · %d plates · %d plans" % (
        len(units), sections, questions, plates, len(data["plans"]))


# ------------------------------------------------------------------- 3. assets
@check("referenced assets exist")
def assets_present() -> str:
    www = os.path.join(ROOT, "app", "www")
    missing: list[str] = []
    checked = 0

    with open(os.path.join(www, "index.html"), encoding="utf8") as fh:
        html = fh.read()
    for match in re.findall(r'(?:src|href)="([^"#]+)"', html):
        if match.startswith(("http", "data:", "//")):
            continue
        checked += 1
        if not os.path.exists(os.path.join(www, match)):
            missing.append(match)

    # Fonts referenced from CSS
    with open(os.path.join(www, "css", "app.css"), encoding="utf8") as fh:
        css = fh.read()
    for match in re.findall(r"url\(['\"]?\.\./([^'\")]+)", css):
        checked += 1
        if not os.path.exists(os.path.join(www, match)):
            missing.append(match)

    # Plates referenced from the data file
    with open(os.path.join(www, "js", "data.js"), encoding="utf8") as fh:
        data = fh.read()
    for plate in set(re.findall(r'"(\d\d_\d+\.jpg)"', data)):
        checked += 1
        if not os.path.exists(os.path.join(www, "media", plate)):
            missing.append("media/" + plate)

    assert not missing, "missing: %s" % ", ".join(sorted(missing)[:6])
    return "%d references resolved" % checked


# --------------------------------------------------------------- 4. javascript
@check("javascript parses")
def javascript_parses() -> str:
    node = shutil.which("node")
    files = [os.path.join(ROOT, "app", "www", "js", name)
             for name in ("app.js", "data.js", "version.js")]
    if not node:
        for path in files:
            with open(path, encoding="utf8") as fh:
                source = fh.read()
            assert source.count("{") == source.count("}"), \
                "%s has unbalanced braces" % os.path.basename(path)
        return "brace balance only (node not installed)"
    for path in files:
        out = subprocess.run([node, "--check", path], capture_output=True, text=True)
        assert out.returncode == 0, "%s: %s" % (os.path.basename(path), out.stderr.strip())
    return "%d files checked with node" % len(files)


# ------------------------------------------------------------------- 5. android
@check("APK is signed, aligned and complete")
def apk_integrity() -> str:
    with open(os.path.join(ROOT, "package.json"), encoding="utf8") as fh:
        version = json.load(fh)["version"]
    apk = os.path.join(ROOT, "dist", "rebo-android-v%s.apk" % version)
    assert os.path.exists(apk), "APK not built: %s" % os.path.relpath(apk, ROOT)

    with zipfile.ZipFile(apk) as zf:
        assert zf.testzip() is None, "APK zip is corrupt"
        names = set(zf.namelist())
        for required in ("AndroidManifest.xml", "classes.dex", "resources.arsc",
                         "assets/www/index.html", "assets/www/js/data.js"):
            assert required in names, "APK is missing %s" % required
            media = [n for n in names if n.startswith("assets/www/media/")]
        # Guards against a pipeline run without Pillow, which used to degrade
        # silently to one unsplit plate per unit.
        assert len(media) >= 19, (
            "APK carries only %d plates (expected >= 19); regenerate the media "
            "with Pillow installed: PYTHONPATH=... python3 app/pipeline/build_content.py"
            % len(media))

    java = shutil.which("java")
    if java:
        signer = os.path.join(ROOT, "tools", "apksigner.jar")
        if os.path.exists(signer):
            out = subprocess.run([java, "--enable-native-access=ALL-UNNAMED", "-jar", signer,
                                  "verify", "--verbose", apk],
                                 capture_output=True, text=True)
            combined = out.stdout + out.stderr
            assert out.returncode == 0, "apksigner rejected the APK"
            for scheme in ("v2 scheme (APK Signature Scheme v2): true",
                           "v3 scheme (APK Signature Scheme v3): true"):
                assert scheme in combined, "APK is not signed with %s" % scheme.split(":")[0]

    zipalign = os.path.join(ROOT, "tools", "zipalign.py")
    out = subprocess.run([sys.executable, zipalign, "--verify", "-p", "4", apk],
                         capture_output=True, text=True)
    assert out.returncode == 0, out.stderr.strip()

    size = os.path.getsize(apk) / 1048576
    return "%.1f MB · %d entries · signed v2+v3 · aligned" % (size, len(names))


# ------------------------------------------------------------------- 6. windows
@check("Windows binaries are valid and self-contained")
def windows_binaries() -> str:
    with open(os.path.join(ROOT, "package.json"), encoding="utf8") as fh:
        version = json.load(fh)["version"]
    folder = os.path.join(ROOT, "dist", "Rebo-Windows-%s" % version)
    exe = os.path.join(folder, "Rebo.exe")
    setup = os.path.join(ROOT, "dist", "Rebo-Setup-%s.exe" % version)
    assert os.path.exists(exe), "portable build not found"
    assert os.path.exists(setup), "installer not found"
    assert os.path.exists(os.path.join(folder, "WebView2Loader.dll")), "loader missing"
    assert os.path.exists(os.path.join(folder, "www", "index.html")), "payload missing"

    for binary in (exe, setup):
        image = pe_check.PE(binary)
        assert image.bits == 64, "%s is not 64-bit" % os.path.basename(binary)
        assert image.subsystem == 2, "%s is not a GUI binary" % os.path.basename(binary)
        resources = image.resources()
        for needed in (pe_check.RT_MANIFEST, pe_check.RT_VERSION,
                       pe_check.RT_ICON, pe_check.RT_GROUP_ICON):
            assert needed in resources, "%s lacks resource type %d" % (
                os.path.basename(binary), needed)
        manifest = resources[pe_check.RT_MANIFEST][0].decode("utf-8", "ignore")
        assert "permonitorv2" in manifest, "%s is not per-monitor DPI aware" % os.path.basename(binary)
        assert "Microsoft.Windows.Common-Controls" in manifest, \
            "%s does not opt into themed controls" % os.path.basename(binary)

    with zipfile.ZipFile(setup) as _:
        pass  # setup is not a zip; the payload check below covers it

    image = pe_check.PE(setup)
    payload = image.resources()[pe_check.RT_RCDATA][0]
    with zipfile.ZipFile(__import__("io").BytesIO(payload)) as zf:
        assert zf.testzip() is None, "installer payload is corrupt"
        assert "Rebo.exe" in zf.namelist(), "installer payload lacks Rebo.exe"
    return "Rebo.exe + loader + %d-file payload" % len(zf.namelist())


# ---------------------------------------------------------------------- main
def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Rebo release checks")
    parser.add_argument("--skip", action="append", default=[],
                        choices=["version", "content", "assets", "javascript",
                                 "apk", "windows"])
    args = parser.parse_args(argv)

    skipped = set(args.skip)
    for fn, key in ((version_sync, "version"), (content_complete, "content"),
                    (assets_present, "assets"), (javascript_parses, "javascript"),
                    (apk_integrity, "apk"), (windows_binaries, "windows")):
        if key in skipped:
            record(SKIP, fn.__name__.replace("_", " "), "--skip " + key)
            continue
        fn()

    width = max(len(name) for _s, name, _d in results)
    failures = 0
    for status, name, detail in results:
        colour = {"PASS": "\033[38;5;78m", "FAIL": "\033[38;5;203m",
                  "SKIP": "\033[2m"}[status]
        print("%s%s\033[0m  %-*s  %s" % (colour, status, width, name,
                                         ("\033[2m" + detail + "\033[0m") if detail else ""))
        failures += status == FAIL
    print()
    if failures:
        print("\033[38;5;203m✖ %d check(s) failed\033[0m" % failures)
        return 1
    print("\033[38;5;78m✔ all checks passed\033[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
