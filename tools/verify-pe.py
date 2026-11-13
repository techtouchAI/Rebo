#!/usr/bin/env python3
"""
Rebo · PE verification
======================

Cross-compiled Windows binaries cannot be *run* on the build host, so the build
verifies the container instead: architecture, subsystem, embedded manifest
(DPI awareness + Common Controls v6), version resource, icon, imports and — for
the installer — that the embedded payload is a readable zip archive.

Usage
-----
    verify-pe.py --exe Rebo.exe --subsystem windows --bits 64 \
                 --require-manifest --require-version --require-icon \
                 --require-import WebView2Loader.dll

    verify-pe.py --exe Rebo-Setup-1.0.0.exe --dump-rcdata 100 --expect-zip

Exit status is 0 only when every requested check passes.
"""
from __future__ import annotations

import argparse
import io
import re
import struct
import sys
import zipfile

SUBSYSTEM_NAMES = {
    1: "native",
    2: "windows",
    3: "console",
    9: "windows-ce",
}
RT_ICON, RT_RCDATA, RT_GROUP_ICON, RT_VERSION, RT_MANIFEST = 3, 10, 14, 16, 24


class PE:
    """Minimal PE/COFF reader — enough to audit resources and imports."""

    def __init__(self, path: str) -> None:
        with open(path, "rb") as fh:
            self.blob = fh.read()
        if self.blob[:2] != b"MZ":
            raise ValueError("%s is not a PE file (no MZ header)" % path)
        self.path = path
        self.pe_offset = struct.unpack_from("<I", self.blob, 0x3C)[0]
        if self.blob[self.pe_offset:self.pe_offset + 4] != b"PE\0\0":
            raise ValueError("%s has no PE signature" % path)
        coff = self.pe_offset + 4
        self.machine, n_sections = struct.unpack_from("<HH", self.blob, coff)
        opt_size = struct.unpack_from("<H", self.blob, coff + 16)[0]
        self.opt = coff + 20
        self.magic = struct.unpack_from("<H", self.blob, self.opt)[0]
        self.sections = []
        base = self.opt + opt_size
        for i in range(n_sections):
            off = base + i * 40
            vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", self.blob, off + 8)
            self.sections.append((vaddr, max(vsize, rawsize), rawptr, rawsize))
        data_dir = self.opt + (112 if self.magic == 0x20B else 96)
        self.dirs = [struct.unpack_from("<II", self.blob, data_dir + i * 8) for i in range(16)]

    # -- basics ------------------------------------------------------------
    @property
    def bits(self) -> int:
        return 64 if self.magic == 0x20B else 32

    @property
    def subsystem(self) -> int:
        return struct.unpack_from("<H", self.blob, self.opt + 68)[0]

    def rva_to_offset(self, rva: int) -> int:
        for vaddr, span, rawptr, rawsize in self.sections:
            if vaddr <= rva < vaddr + span:
                delta = rva - vaddr
                return rawptr + min(delta, rawsize - 1)
        raise ValueError("RVA 0x%x is outside every section" % rva)

    # -- resources ---------------------------------------------------------
    # IMAGE_RESOURCE_DIRECTORY_ENTRY: a Name is a string when its high bit is
    # set; an OffsetToData is a *subdirectory* when its high bit is set, and a
    # leaf IMAGE_RESOURCE_DATA_ENTRY when it is clear.
    def resources(self) -> dict[int, list[bytes]]:
        rva, _ = self.dirs[2]
        if not rva:
            return {}
        base = self.rva_to_offset(rva)

        def entries(offset: int):
            named, ids = struct.unpack_from("<HH", self.blob, base + offset + 12)
            out = []
            for i in range(named + ids):
                entry = base + offset + 16 + i * 8
                name, target = struct.unpack_from("<II", self.blob, entry)
                out.append((name, target))
            return out

        def name_at(offset: int) -> str:
            length = struct.unpack_from("<H", self.blob, base + offset)[0]
            start = base + offset + 2
            return self.blob[start:start + length * 2].decode("utf-16-le")

        found: dict[int, list[bytes]] = {}
        for type_key, type_target in entries(0):
            if not type_target & 0x80000000:
                continue                       # resource types are directories
            label = name_at(type_key & 0x7FFFFFFF) if type_key & 0x80000000 else type_key
            key = label if isinstance(label, str) else label
            for _name_key, name_target in entries(type_target & 0x7FFFFFFF):
                if not name_target & 0x80000000:
                    continue                   # names are directories too
                for _lang, lang_target in entries(name_target & 0x7FFFFFFF):
                    if lang_target & 0x80000000:
                        continue
                    data_rva, size = struct.unpack_from("<II", self.blob,
                                                        base + lang_target)
                    start = self.rva_to_offset(data_rva)
                    found.setdefault(key, []).append(self.blob[start:start + size])
        return found

    # -- imports -----------------------------------------------------------
    def imports(self) -> list[str]:
        rva, _ = self.dirs[1]
        if not rva:
            return []
        offset = self.rva_to_offset(rva)
        names = []
        while True:
            entry = self.blob[offset:offset + 20]
            if len(entry) < 20 or entry == b"\0" * 20:
                break
            name_rva = struct.unpack_from("<I", entry, 12)[0]
            if not name_rva:
                break
            start = self.rva_to_offset(name_rva)
            end = self.blob.index(b"\0", start)
            names.append(self.blob[start:end].decode("ascii", "replace"))
            offset += 20
        return names

    def version_strings(self) -> list[str]:
        for blob in self.resources().get(RT_VERSION, []):
            text = blob.decode("utf-16-le", "ignore")
            return re.findall(r"[A-Za-z][ -~]{2,}", text)
        return []

    def fixed_file_version(self) -> tuple[int, int] | None:
        for blob in self.resources().get(RT_VERSION, []):
            idx = blob.find(struct.pack("<I", 0xFEEF04BD))
            if idx >= 0:
                file_ms, file_ls = struct.unpack_from("<II", blob, idx + 8)
                prod_ms, prod_ls = struct.unpack_from("<II", blob, idx + 16)
                return (file_ms, file_ls), (prod_ms, prod_ls)
        return None


def verify_stored_walk(blob: bytes, zf: zipfile.ZipFile) -> list[str]:
    """Replay setup.cpp's payload reader and compare against a real zip reader."""
    problems: list[str] = []
    offset = 0
    seen: dict[str, bytes] = {}
    while offset + 30 <= len(blob):
        if blob[offset:offset + 4] != b"PK\x03\x04":
            break
        method, = struct.unpack_from("<H", blob, offset + 8)
        compressed, uncompressed = struct.unpack_from("<II", blob, offset + 18)
        name_len, extra_len = struct.unpack_from("<HH", blob, offset + 26)
        if method != 0:
            problems.append("payload entry at %d is deflated; the installer reads "
                            "stored entries only" % offset)
            break
        name = blob[offset + 30:offset + 30 + name_len].decode("utf-8")
        start = offset + 30 + name_len + extra_len
        data = blob[start:start + compressed]
        if len(data) != uncompressed or len(data) != compressed:
            problems.append("%s: size mismatch in the stored-walk parser" % name)
        seen[name] = data
        offset = start + compressed

    if set(seen) != set(zf.namelist()):
        missing = set(zf.namelist()) - set(seen)
        extra = set(seen) - set(zf.namelist())
        problems.append("payload walk disagrees with the zip index "
                        "(missing=%d extra=%d)" % (len(missing), len(extra)))
    else:
        differing = [name for name, data in seen.items() if zf.read(name) != data]
        if differing:
            problems.append("payload walk returned different bytes for: %s"
                            % ", ".join(differing[:3]))
    print("  payload walk : %d entries verified byte-for-byte" % len(seen))
    return problems


def check(args: argparse.Namespace) -> int:
    failures: list[str] = []

    def fail(message: str) -> None:
        failures.append(message)

    try:
        pe = PE(args.exe)
    except (ValueError, struct.error) as exc:
        print("✖ %s" % exc, file=sys.stderr)
        return 1

    print("%s" % args.exe)
    print("  machine      : 0x%04x, %d-bit" % (pe.machine, pe.bits))
    print("  subsystem    : %s" % SUBSYSTEM_NAMES.get(pe.subsystem, pe.subsystem))
    resources = pe.resources()
    print("  resources    : %s" % sorted(resources))
    print("  imports      : %s" % ", ".join(pe.imports()))

    if args.bits and pe.bits != args.bits:
        fail("expected a %d-bit image, found %d-bit" % (args.bits, pe.bits))
    if args.subsystem:
        want = {v: k for k, v in SUBSYSTEM_NAMES.items()}[args.subsystem]
        if pe.subsystem != want:
            fail("expected the %s subsystem, found %s"
                 % (args.subsystem, SUBSYSTEM_NAMES.get(pe.subsystem, pe.subsystem)))

    if args.require_manifest:
        manifests = resources.get(RT_MANIFEST, [])
        if not manifests:
            fail("no application manifest (RT_MANIFEST) embedded")
        else:
            text = manifests[0].decode("utf-8", "ignore")
            for needle in ("dpiAware", "Microsoft.Windows.Common-Controls"):
                if needle not in text:
                    fail("manifest is missing %r" % needle)

    if args.require_version:
        versions = pe.version_strings()
        if not versions:
            fail("no version resource (RT_VERSION) embedded")
        else:
            print("  version info : %s" % ", ".join(versions[:6]))
            fixed = pe.fixed_file_version()
            if not fixed:
                fail("version resource has no VS_FIXEDFILEINFO block")
            else:
                (fms, fls), _ = fixed
                print("  file version : %d.%d.%d.%d"
                      % (fms >> 16, fms & 0xFFFF, fls >> 16, fls & 0xFFFF))

    if args.require_icon:
        if not resources.get(RT_ICON):
            fail("no icons (RT_ICON) embedded")
        if not resources.get(RT_GROUP_ICON):
            fail("no icon group (RT_GROUP_ICON) embedded")

    for module in args.require_loadlibrary or []:
        needle = module.encode("utf-16-le")
        if needle not in pe.blob and module.encode("ascii") not in pe.blob:
            fail("binary never references %s (expected a LoadLibrary target)" % module)

    for module in args.require_import or []:
        if module.lower() not in [name.lower() for name in pe.imports()]:
            fail("missing import: %s" % module)

    if args.require_rcdata is not None:
        payloads = resources.get(RT_RCDATA, [])
        if not payloads:
            fail("no RCDATA payload embedded")
        else:
            sizes = [len(p) for p in payloads]
            print("  rcdata sizes : %s" % sizes)

    if args.dump_rcdata is not None:
        payloads = resources.get(RT_RCDATA, [])
        if not payloads:
            fail("no RCDATA payload to inspect")
        else:
            blob = payloads[0]
            if args.expect_zip:
                try:
                    with zipfile.ZipFile(io.BytesIO(blob)) as zf:
                        names = zf.namelist()
                        bad = zf.testzip()
                        print("  payload      : %d entries, %.1f MB, corrupt=%s"
                              % (len(names), len(blob) / 1048576, bad))
                        for required in ("Rebo.exe", "www/index.html"):
                            if required not in names:
                                fail("payload is missing %s" % required)
                        # The installer walks local file headers directly (no
                        # central directory), so prove that walk yields the same
                        # bytes that a zip reader sees.
                        for problem in verify_stored_walk(blob, zf):
                            fail(problem)
                except zipfile.BadZipFile:
                    fail("RCDATA blob is not a valid zip archive")

    if failures:
        for failure in failures:
            print("✖ " + failure, file=sys.stderr)
        return 1
    print("  ✔ all checks passed")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Verify a cross-built Windows binary.")
    parser.add_argument("--exe", required=True)
    parser.add_argument("--bits", type=int, choices=(32, 64))
    parser.add_argument("--subsystem", choices=sorted(SUBSYSTEM_NAMES.values()))
    parser.add_argument("--require-manifest", action="store_true")
    parser.add_argument("--require-version", action="store_true")
    parser.add_argument("--require-icon", action="store_true")
    parser.add_argument("--require-import", action="append", metavar="DLL")
    parser.add_argument("--require-loadlibrary", action="append", metavar="DLL",
                        help="assert the DLL name appears as a string literal "
                             "(dynamic LoadLibrary, not a static import)")
    parser.add_argument("--require-rcdata", type=int, metavar="ID")
    parser.add_argument("--dump-rcdata", type=int, metavar="ID")
    parser.add_argument("--expect-zip", action="store_true")
    return check(parser.parse_args(argv))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
