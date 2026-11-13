#!/usr/bin/env python3
"""Write dist/SHA256SUMS.txt for every release artefact."""
import hashlib
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, 'dist')
def targets(version: str) -> list[str]:
    return [
        'rebo-android-v%s.apk' % version,
        'Rebo-Setup-%s.exe' % version,
        'Rebo-Windows-%s-portable.zip' % version,
    ]


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    with open(os.path.join(ROOT, 'package.json'), encoding='utf8') as fh:
        version = json.load(fh)['version']
    lines = []
    for name in targets(version):
        p = os.path.join(DIST, name)
        if not os.path.exists(p):
            continue
        lines.append('%s  %s  (%.1f MB)' % (sha256(p), name,
                                            os.path.getsize(p) / 1048576))
    out = os.path.join(DIST, 'SHA256SUMS.txt')
    with open(out, 'w', encoding='utf8') as f:
        f.write('\n'.join(lines) + '\n')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
