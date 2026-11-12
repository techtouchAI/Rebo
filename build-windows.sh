#!/usr/bin/env bash
# ============================================================================
#  Rebo · build-windows.sh
#
#  Cross-compiles the native Windows host with Zig (clang + MinGW-w64 runtime),
#  then packages it with the web app into:
#
#     dist/Rebo-Windows-1.0.0/            portable folder (Rebo.exe + www/)
#     dist/Rebo-Windows-1.0.0-portable.zip
#     dist/Rebo-Setup-1.0.0.exe           installer (NSIS)
#
#  No third-party UI runtime is bundled: the interface is rendered by the
#  Microsoft Edge WebView2 Runtime, a Windows component provided by Microsoft.
#  The small WebView2Loader in ./app/windows/loader is built from source here.
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ZIG="${ZIG:-zig}"
WIN="$HERE/app/windows"
OUT="$HERE/build/windows"
DIST="$HERE/dist"
NAME="Rebo-Windows-1.0.0"
MAKENSIS="${MAKENSIS:-}"

rm -rf "$OUT"
mkdir -p "$OUT/obj" "$DIST/$NAME"

echo "» compiling resources"
"$ZIG" rc /fo "$OUT/obj/rebo.res.o" "$WIN/res/rebo.rc"

echo "» building WebView2Loader.dll (from source)"
"$ZIG" c++ -target x86_64-windows-gnu -O2 -shared -std=c++17 \
  -DUNICODE -D_UNICODE \
  "$WIN/loader/webview2loader.cpp" \
  -o "$DIST/$NAME/WebView2Loader.dll" \
  -lole32 -lshell32 -lshlwapi -luser32 -ladvapi32 \
  -Wl,--out-implib,"$OUT/obj/libwv2loader.a"

echo "» compiling host (webview + Win32 + WebView2)"
"$ZIG" c++ -target x86_64-windows-gnu -O2 -std=c++17 -municode \
  -DUNICODE -D_UNICODE -DWEBVIEW_STATIC \
  -I"$WIN/third_party" -I"$WIN/third_party/mingw" \
  "$WIN/src/main.cpp" "$OUT/obj/rebo.res.o" \
  "$OUT/obj/libwv2loader.a" \
  -o "$DIST/$NAME/Rebo.exe" \
  -Wl,--subsystem,windows \
  -lole32 -loleaut32 -lshell32 -lshlwapi -luser32 -lversion -ladvapi32 -lgdi32 \
  -Wl,--gc-sections -s
rm -f "$DIST/$NAME"/*.pdb

echo "» copying web app"
mkdir -p "$DIST/$NAME/www"
cp -R "$HERE/app/www/." "$DIST/$NAME/www/"

cp "$WIN/README.txt" "$DIST/$NAME/README.txt" 2>/dev/null || true

echo "» portable archive"
( cd "$DIST" && rm -f "$NAME-portable.zip" && zip -qr "$NAME-portable.zip" "$NAME" )
cp "$DIST/$NAME-portable.zip" "$DIST/Rebo-Windows-1.0.0-portable.zip" 2>/dev/null || true

if [ -n "$MAKENSIS" ] && [ -x "$MAKENSIS" ]; then
  echo "» building installer"
  "$MAKENSIS" -V2 -DOUTDIR="$DIST" -DSRCDIR="$DIST/$NAME" "$HERE/app/windows/installer.nsi"
fi

echo
echo "✔ Windows build ready:"
ls -lh "$DIST" | sed 's/^/   /'

# --------------------------------------------------------------------------
#  Installer: per-user setup that embeds the app as a stored zip payload.
# --------------------------------------------------------------------------
echo "» building setup"
PAY="$OUT/payload"
rm -rf "$PAY"; mkdir -p "$PAY"
cp -R "$DIST/$NAME/." "$PAY/"
python3 - "$PAY" "$OUT/payload.zip" <<'PY'
import os, sys, zipfile
payload, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_STORED) as z:
    for root, dirs, files in os.walk(payload):
        dirs.sort(); files.sort()
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, payload).replace(os.sep, '/')
            z.write(full, rel)
print('payload entries written')
PY
cp app/windows/setup/payload.rc "$OUT/payload.rc"
cp app/windows/res/rebo.ico "$OUT/rebo.ico" 2>/dev/null || true

( cd "$OUT" && cp "$HERE/app/windows/res/rebo.ico" . && "$ZIG" rc /fo "$OUT/obj/setup.res.o" "$HERE/app/windows/setup/payload.rc" )
"$ZIG" c++ -target x86_64-windows-gnu -O2 -std=c++17 -municode \
  -DUNICODE -D_UNICODE -DWIN32_LEAN_AND_MEAN \
  "$HERE/app/windows/setup/setup.cpp" "$OUT/obj/setup.res.o" \
  -o "$DIST/Rebo-Setup-1.0.0.exe" \
  -Wl,--subsystem,windows \
  -lole32 -loleaut32 -lshell32 -lshlwapi -luser32 -ladvapi32 -lcomctl32 -lcomdlg32 -lgdi32 \
  -Wl,--gc-sections -s
rm -f "$DIST/Rebo-Setup-1.0.0.pdb"
echo "✔ Installer: dist/Rebo-Setup-1.0.0.exe ($(du -h "$DIST/Rebo-Setup-1.0.0.exe" | cut -f1))"
