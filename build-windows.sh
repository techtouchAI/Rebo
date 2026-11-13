#!/usr/bin/env bash
# ============================================================================
#  Rebo · build-windows.sh
#
#  Cross-compiles the native Windows host with Zig (clang + MinGW-w64), then
#  packages it with the web app into:
#
#     dist/Rebo-Windows-<ver>/                 portable folder
#     dist/Rebo-Windows-<ver>-portable.zip
#     dist/Rebo-Setup-<ver>.exe                per-user installer
#
#  No third-party UI runtime is bundled: the interface is rendered by the
#  Microsoft Edge WebView2 Runtime, a Windows component. The WebView2Loader in
#  ./app/windows/loader is built from source here, so nothing from Microsoft
#  is redistributed.
#
#  Every artefact is verified (PE subsystem, embedded manifest, icon, version
#  resource, zip integrity) before the build reports success.
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/lib/common.sh
. "$HERE/tools/lib/common.sh"

ZIG="${ZIG:-zig}"
WIN="$HERE/app/windows"
OUT="$HERE/build/windows"
DIST="$HERE/dist"
VERSION="$(rebo_version "$HERE")"
NAME="Rebo-Windows-$VERSION"
SETUP="Rebo-Setup-$VERSION.exe"

TARGET="x86_64-windows-gnu"

# ---------------------------------------------------------------- preflight
step "preflight"
require "$ZIG"     "ثبّت Zig 0.12+ أو اضبط ZIG=/path/to/zig"
require python3    "لازم لفحص المخرجات وتغليف الحمولة"
require_file "$WIN/src/main.cpp"        "مصدر مضيف ويندوز"
require_file "$WIN/loader/webview2loader.cpp" "محمل WebView2"
require_file "$WIN/res/rebo.ico"        "أيقونة التطبيق"
require_file "$WIN/res/manifest.xml"    "مانيفست التطبيق (DPI + Common Controls)"

python3 "$HERE/tools/sync-version.py" --check >/dev/null \
  || die "أرقام الإصدار غير متزامنة — شغّل: python3 tools/sync-version.py"

rm -rf "$OUT"
mkdir -p "$OUT/obj" "$OUT/rc" "$DIST/$NAME"

# The resource compiler resolves quoted paths relative to the .rc file, so we
# stage each .rc next to the assets it references. `--` stops option parsing,
# which is what silences the "<cli>: note: this argument was inferred to be a
# filepath" diagnostic on paths that begin with a slash.
step "compiling resources (icon + version + manifest)"
cp "$WIN/res/rebo.ico" "$WIN/res/manifest.xml" "$OUT/rc/"
"$ZIG" rc /fo "$OUT/obj/rebo.res.o" -- "$WIN/res/rebo.rc"
[ -s "$OUT/obj/rebo.res.o" ] || die "فشل تصريف موارد التطبيق"

step "building WebView2Loader.dll (from source)"
"$ZIG" c++ -target "$TARGET" -O2 -shared -std=c++17 \
  -DUNICODE -D_UNICODE -DNOMINMAX \
  "$WIN/loader/webview2loader.cpp" \
  -o "$DIST/$NAME/WebView2Loader.dll" \
  -Wl,--out-implib,"$OUT/obj/libwv2loader.a" \
  -lole32 -lshell32 -lshlwapi -luser32 -ladvapi32
[ -f "$DIST/$NAME/WebView2Loader.dll" ] || die "لم يُبنَ WebView2Loader.dll"

step "compiling host (Win32 + WebView2)"
"$ZIG" c++ -target "$TARGET" -O2 -std=c++17 -municode \
  -DUNICODE -D_UNICODE -DNOMINMAX -DWEBVIEW_STATIC \
  -I"$WIN/src" -I"$WIN/third_party" -I"$WIN/third_party/mingw" \
  "$WIN/src/main.cpp" "$OUT/obj/rebo.res.o" "$OUT/obj/libwv2loader.a" \
  -o "$DIST/$NAME/Rebo.exe" \
  -Wl,--subsystem,windows -Wl,--gc-sections -s \
  -lole32 -loleaut32 -lshell32 -lshlwapi -luser32 -lversion -ladvapi32 -lgdi32
rm -f "$DIST/$NAME"/*.pdb
[ -f "$DIST/$NAME/Rebo.exe" ] || die "لم يُبنَ Rebo.exe"

step "verifying host executable"
python3 "$HERE/tools/verify-pe.py" --exe "$DIST/$NAME/Rebo.exe" \
  --subsystem windows --bits 64 --require-manifest --require-version \
  --require-icon --require-loadlibrary WebView2Loader.dll

step "copying web app"
mkdir -p "$DIST/$NAME/www"
cp -R "$HERE/app/www/." "$DIST/$NAME/www/"
find "$DIST/$NAME/www" -name '.DS_Store' -delete
[ -f "$DIST/$NAME/www/index.html" ] || die "نسخة الويب ناقصة (index.html)"
cp "$WIN/README.txt" "$DIST/$NAME/README.txt"

step "portable archive"
rm -f "$DIST/$NAME-portable.zip"
( cd "$DIST" && zip -qr "$NAME-portable.zip" "$NAME" )
python3 -c "import sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); bad=z.testzip(); \
sys.exit(1 if bad else 0)" "$DIST/$NAME-portable.zip" \
  || die "أرشيف النسخة المحمولة تالف"

# ------------------------------------------------------------------ setup
step "building installer"
PAYLOAD_DIR="$OUT/payload"
mkdir -p "$PAYLOAD_DIR"
cp -R "$DIST/$NAME/." "$PAYLOAD_DIR/"

# The installer embeds a *stored* (uncompressed) zip: the setup binary extracts
# it with a tiny built-in reader, so no compression library is needed and the
# payload stays byte-for-byte identical to the portable build.
python3 - "$PAYLOAD_DIR" "$OUT/payload.zip" <<'PY'
import os, sys, zipfile

src, dst = sys.argv[1], sys.argv[2]
count = 0
with zipfile.ZipFile(dst, "w", zipfile.ZIP_STORED) as zf:
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(files):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, src).replace(os.sep, "/")
            info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_STORED
            info.external_attr = 0o644 << 16
            with open(full, "rb") as fh:
                zf.writestr(info, fh.read())
            count += 1
print("   payload: %d files, %.1f MB" % (count, os.path.getsize(dst) / 1048576))
PY

# Stage the installer's resources beside payload.rc so quoted paths resolve.
cp "$WIN/res/rebo.ico" "$OUT/rc/rebo.ico"
cp "$WIN/setup/setup.manifest.xml" "$OUT/rc/setup.manifest.xml"
cp "$WIN/setup/payload.rc" "$OUT/rc/payload.rc"
cp "$OUT/payload.zip" "$OUT/rc/payload.zip"
"$ZIG" rc /fo "$OUT/obj/setup.res.o" -- "$OUT/rc/payload.rc"
[ -s "$OUT/obj/setup.res.o" ] || die "فشل تصريف موارد المثبّت"

"$ZIG" c++ -target "$TARGET" -O2 -std=c++17 -municode \
  -DUNICODE -D_UNICODE -DNOMINMAX \
  -DREBO_VERSION_STRING=\"$VERSION\" \
  -I"$WIN/src" \
  "$WIN/setup/setup.cpp" "$OUT/obj/setup.res.o" \
  -o "$DIST/$SETUP" \
  -Wl,--subsystem,windows -Wl,--gc-sections -s \
  -lole32 -loleaut32 -lshell32 -lshlwapi -luser32 -ladvapi32 -lgdi32 -lcomctl32
rm -f "$DIST/"*.pdb

step "verifying installer"
python3 "$HERE/tools/verify-pe.py" --exe "$DIST/$SETUP" \
  --subsystem windows --bits 64 --require-manifest --require-version \
  --require-icon --require-rcdata 100

step "checking embedded payload is extractable"
python3 "$HERE/tools/verify-pe.py" --exe "$DIST/$SETUP" --dump-rcdata 100 \
  --expect-zip | sed 's/^/   /'

echo
ok "Windows build ready"
printf '   %s·%s ' "$C_DIM" "$C_OFF"
ls -lh "$DIST" | awk 'NR>1 {printf "%s(%s) ", $9, $5}'
printf '%s\n' ""
ok "Installer: dist/$SETUP ($(du -h "$DIST/$SETUP" | cut -f1))"
