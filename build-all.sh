#!/usr/bin/env bash
# Build every deliverable: Android APK + Windows desktop app + installer.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${JAVA_HOME:?set JAVA_HOME to a JDK 17+ installation}"
export PATH="$JAVA_HOME/bin:$PATH"

bash "$HERE/build-android.sh"
ZIG="${ZIG:-zig}" bash "$HERE/build-windows.sh"
python3 "$HERE/tools/make_manifest.py" || true
echo
echo "Artifacts in ./dist"
