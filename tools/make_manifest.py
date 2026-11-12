#!/usr/bin/env python3
"""Write dist/SHA256SUMS.txt for every release artefact."""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, 'dist')
TARGETS = [
    'rebo-android-v1.0.0.apk',
    'Rebo-Setup-1.0.0.exe',
    'Rebo-Windows-1.0.0-portable.zip',
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    lines = []
    for name in TARGETS:
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
