#!/usr/bin/env python3
"""
Minimal, dependency-free re-implementation of Android's `zipalign`.

Stored (uncompressed) entries are padded with an "extra field" so that each
entry's payload starts on a 4-byte boundary and the central directory starts
on a 4-byte boundary — the alignment requirement of the Android package
manager and of APK Signature Scheme v2.

Usage: zipalign.py [-f] [-p] 4 in.apk out.apk
       (-p = also page-align .so files, -f = overwrite output)
"""
import os
import struct
import sys
import zipfile

ALIGN_EXTRA_ID = 0xD935


def pad_extra(extra: bytes, misalign: int) -> bytes:
    if misalign == 0:
        return extra
    # 4 header bytes + payload; payload must make (offset + len) % align == 0
    pad_len = misalign
    while pad_len < 4:
        pad_len += 4
    payload = b"\x00" * (pad_len - 4)
    return extra + struct.pack("<HH", ALIGN_EXTRA_ID, len(payload)) + payload


def align(in_path: str, out_path: str, align: int = 4, page_align_so: bool = True):
    zin = zipfile.ZipFile(in_path, "r")
    zout = zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED)
    for info in zin.infolist():
        data = zin.read(info.filename)
        zi = zipfile.ZipInfo(info.filename, date_time=info.date_time)
        zi.external_attr = info.external_attr
        zi.internal_attr = info.internal_attr
        zi.create_system = info.create_system
        store = info.compress_type == zipfile.ZIP_STORED
        target = align
        if page_align_so and info.filename.endswith(".so"):
            target = 16384
        if store:
            zi.compress_type = zipfile.ZIP_STORED
            local_header_len = 30 + len(info.filename.encode("utf-8"))
            base_extra = info.extra or b""
            offset = zout.fp.tell() if zout.fp else 0
            data_start = offset + local_header_len + len(base_extra)
            pad = (-data_start) % target
            zi.extra = pad_extra(base_extra, pad)
        else:
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.extra = info.extra or b""
        zi.comment = info.comment
        zout.writestr(zi, data)
    zout.close()
    zin.close()


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("-")]
    align_n = int(args[0])
    in_p, out_p = args[1], args[2]
    if in_p != out_p:
        align(in_p, out_p, align_n)
    else:
        tmp = out_p + ".za"
        align(in_p, tmp, align_n)
        os.replace(tmp, out_p)
    print("zipalign(py): %s -> %s (%d-byte)" % (in_p, out_p, align_n))


if __name__ == "__main__":
    main(sys.argv)
