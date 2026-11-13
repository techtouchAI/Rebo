#!/usr/bin/env python3
"""
Portable `zipalign` for Android packages.
=========================================

The Android package manager requires that every *stored* (uncompressed) entry
start on a 4-byte boundary, and that ``.so`` files be page-aligned (16 KiB
since Android 15) because the loader maps them directly.

Google ships ``zipalign`` only as a host binary inside Build-Tools; this module
reproduces the documented behaviour with the standard library so that the build
is reproducible on any host OS.

Usage
-----
    zipalign.py [-f] [-p] 4 in.apk out.apk     # align into a new package
    zipalign.py --verify -p 4 in.apk           # check an existing package

``-p`` page-aligns ``.so`` files; ``-f`` is accepted for CLI compatibility
(the output file is always overwritten).
"""
from __future__ import annotations

import os
import struct
import sys
import time
import zipfile

#: Extra-field header id used by AOSP zipalign for alignment padding.
ALIGN_EXTRA_ID = 0xD935
LOCAL_HEADER_SIZE = 30
PAGE_SIZE = 16384


def payload_offset(zf: zipfile.ZipFile, info: zipfile.ZipInfo) -> int:
    """Absolute byte offset of an entry's payload within the archive."""
    zf.fp.seek(info.header_offset)
    header = zf.fp.read(LOCAL_HEADER_SIZE)
    name_len, extra_len = struct.unpack_from("<HH", header, 26)
    return info.header_offset + LOCAL_HEADER_SIZE + name_len + extra_len


def alignment_extra(extra: bytes, pad: int) -> bytes:
    """
    Append an alignment extra field that shifts the payload by exactly ``pad``
    modulo the alignment (``pad`` is in ``1..3``).

    An extra field is ``id(2) + size(2) + payload(N)``, i.e. ``4 + N`` bytes,
    so the total always shifts by a multiple of 4 plus ``pad``.
    """
    if pad <= 0:
        return extra
    return extra + struct.pack("<HH", ALIGN_EXTRA_ID, pad) + b"\0" * pad


def build_timestamp() -> tuple[int, int, int, int, int, int]:
    """
    Reproducible-build timestamp.

    ``SOURCE_DATE_EPOCH`` (https://reproducible-builds.org/specs/source-date-epoch/)
    pins every entry to a fixed moment so two builds of the same sources produce
    identical bytes. Without it the original entry timestamps are preserved.
    """
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    if epoch is None:
        return None  # type: ignore[return-value]
    stamp = time.gmtime(int(epoch))
    return (stamp.tm_year, stamp.tm_mon, stamp.tm_mday,
            stamp.tm_hour, stamp.tm_min, stamp.tm_sec)


def align(in_path: str, out_path: str, alignment: int = 4, page_align: bool = True) -> None:
    """Write an aligned copy of ``in_path`` at ``out_path``."""
    fixed_time = build_timestamp()
    with zipfile.ZipFile(in_path, "r") as zin, zipfile.ZipFile(out_path, "w") as zout:
        for info in zin.infolist():
            data = zin.read(info.filename)
            entry = zipfile.ZipInfo(info.filename,
                                    date_time=fixed_time or info.date_time)
            entry.external_attr = info.external_attr
            entry.internal_attr = info.internal_attr
            entry.create_system = info.create_system
            entry.comment = info.comment

            if info.compress_type == zipfile.ZIP_STORED:
                entry.compress_type = zipfile.ZIP_STORED
                target = PAGE_SIZE if (page_align and info.filename.endswith(".so")) else alignment
                extra = info.extra or b""
                name_len = len(info.filename.encode("utf-8"))
                # Position this entry's local header will occupy in the output.
                start = zout.fp.tell() + LOCAL_HEADER_SIZE + name_len + len(extra)
                entry.extra = alignment_extra(extra, (-start) % target)
            else:
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.extra = info.extra or b""

            zout.writestr(entry, data)


def verify(path: str, alignment: int = 4, page_align: bool = True) -> list[str]:
    """Return a list of alignment problems; an empty list means the APK is fine."""
    problems: list[str] = []
    with zipfile.ZipFile(path, "r") as zf:
        for info in zf.infolist():
            if info.compress_type != zipfile.ZIP_STORED:
                continue
            target = PAGE_SIZE if (page_align and info.filename.endswith(".so")) else alignment
            offset = payload_offset(zf, info)
            if offset % target:
                problems.append(
                    "%s: payload at %d is not %d-byte aligned" % (info.filename, offset, target)
                )
    return problems


def main(argv: list[str]) -> int:
    positional = [arg for arg in argv[1:] if not arg.startswith("-")]
    verify_only = "--verify" in argv
    page_align = "-p" in argv

    if verify_only:
        if len(positional) < 2:
            print("usage: zipalign.py --verify [-p] <align> <apk>", file=sys.stderr)
            return 2
        alignment, path = int(positional[0]), positional[1]
        problems = verify(path, alignment, page_align)
        for problem in problems:
            print("zipalign: " + problem, file=sys.stderr)
        if problems:
            return 1
        print("zipalign(py): %s is aligned (%d-byte)" % (path, alignment))
        return 0

    if len(positional) < 3:
        print("usage: zipalign.py [-f] [-p] <align> <in.apk> <out.apk>", file=sys.stderr)
        return 2

    alignment, in_path, out_path = int(positional[0]), positional[1], positional[2]
    if os.path.abspath(in_path) == os.path.abspath(out_path):
        tmp = out_path + ".zipalign.tmp"
        align(in_path, tmp, alignment, page_align)
        os.replace(tmp, out_path)
    else:
        align(in_path, out_path, alignment, page_align)

    problems = verify(out_path, alignment, page_align)
    for problem in problems:
        print("zipalign: " + problem, file=sys.stderr)
    if problems:
        return 1
    print("zipalign(py): %s -> %s (%d-byte)" % (in_path, out_path, alignment))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
