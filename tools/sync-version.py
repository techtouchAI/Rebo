#!/usr/bin/env python3
"""
Rebo · version sync
===================

`package.json` is the single source of truth for the release version. This
script pushes it into every artefact that has to agree with it:

    app/www/js/version.js            window.REBO_VERSION
    app/android/AndroidManifest.xml  versionCode / versionName
    app/windows/res/rebo.rc          FILEVERSION / PRODUCTVERSION / strings
    app/windows/setup/payload.rc     same, for the installer
    app/pipeline/build_content.py    meta.version of the generated content

Usage:
    python3 tools/sync-version.py            # apply
    python3 tools/sync-version.py --check    # exit 1 if anything is stale
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read_version() -> tuple[str, int]:
    with open(os.path.join(ROOT, 'package.json'), encoding='utf8') as f:
        pkg = json.load(f)
    version = pkg['version']
    m = re.match(r'^(\d+)\.(\d+)\.(\d+)$', version)
    if not m:
        sys.exit('version in package.json must be MAJOR.MINOR.PATCH, got %r' % version)
    major, minor, patch = (int(x) for x in m.groups())
    return version, major * 10000 + minor * 100 + patch


def apply(path: str, transform, check: bool, problems: list[str]) -> None:
    full = os.path.join(ROOT, path)
    with open(full, encoding='utf8', newline='') as f:
        original = f.read()
    updated = transform(original)
    if updated == original:
        return
    if check:
        problems.append(path)
        return
    with open(full, 'w', encoding='utf8', newline='') as f:
        f.write(updated)
    print('  updated', path)


def main(argv: list[str]) -> int:
    check = '--check' in argv
    version, code = read_version()
    print('%s version %s (versionCode %d)' % ('checking' if check else 'syncing',
                                              version, code))
    dot4 = version.replace('.', ',') + ',0'
    problems: list[str] = []

    apply('app/www/js/version.js',
          lambda s: re.sub(r"window\.REBO_VERSION = \{[^}]*\};",
                           "window.REBO_VERSION = { version: '%s', build: %d, "
                           "channel: 'stable' };" % (version, code), s),
          check, problems)

    def manifest(s: str) -> str:
        s = re.sub(r'android:versionCode="\d+"',
                   'android:versionCode="%d"' % code, s)
        return re.sub(r'android:versionName="[^"]+"',
                      'android:versionName="%s"' % version, s)

    apply('app/android/AndroidManifest.xml', manifest, check, problems)

    def rc(s: str) -> str:
        s = re.sub(r'FILEVERSION\s+[\d, ]+', 'FILEVERSION ' + dot4, s)
        s = re.sub(r'PRODUCTVERSION\s+[\d, ]+', 'PRODUCTVERSION ' + dot4, s)
        s = re.sub(r'(VALUE "FileVersion",\s+")[^"]+', r'\g<1>' + version + '.0', s)
        s = re.sub(r'(VALUE "ProductVersion",\s+")[^"]+', r'\g<1>' + version + '.0', s)
        return s

    apply('app/windows/res/rebo.rc', rc, check, problems)
    apply('app/windows/setup/payload.rc', rc, check, problems)

    def pipeline(s: str) -> str:
        return re.sub(r"'version': '[^']+'", "'version': '%s'" % version, s)

    apply('app/pipeline/build_content.py', pipeline, check, problems)

    if check:
        if problems:
            print('✖ stale version in: ' + ', '.join(problems))
            return 1
        print('✔ all version references are up to date')
        return 0
    print('✔ version %s applied' % version)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
