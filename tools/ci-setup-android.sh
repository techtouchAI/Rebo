#!/usr/bin/env bash
# ============================================================================
#  Rebo · tools/ci-setup-android.sh
#
#  Installs exactly the Android command-line pieces build-android.sh expects:
#
#      tools/aapt2  tools/d8.jar  tools/apksigner.jar  tools/ecj.jar
#      tools/android.jar
#
#  Downloads come from Google's official endpoints only. The two large jars
#  that the SDK does not ship (ecj, apksigner) are resolved from Maven Central.
#  Everything is cached in tools/.cache between CI runs.
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$HERE/tools/.cache"
BT="${ANDROID_BUILD_TOOLS:-34.0.0}"
PLATFORM="${ANDROID_PLATFORM:-android-34}"
SDK="$CACHE/sdk"
CMDLINE_URL="${SDK_CMDLINE_URL:-https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip}"

mkdir -p "$CACHE"

# --------------------------------------------------------------- SDK pieces
if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "» downloading the Android command-line tools"
  mkdir -p "$SDK"
  curl -fsSL "$CMDLINE_URL" -o "$CACHE/cmdline-tools.zip"
  unzip -q -o "$CACHE/cmdline-tools.zip" -d "$CACHE/cmdline-unpacked"
  rm -rf "$SDK/cmdline-tools"
  mkdir -p "$SDK/cmdline-tools"
  mv "$CACHE/cmdline-unpacked/cmdline-tools" "$SDK/cmdline-tools/latest"
fi

SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"

need_bt=1
[ -f "$SDK/build-tools/$BT/aapt2" ] && need_bt=0
need_platform=1
[ -f "$SDK/platforms/$PLATFORM/android.jar" ] && need_platform=0

if [ "$need_bt" = 1 ] || [ "$need_platform" = 1 ]; then
  echo "» installing build-tools;$BT and platforms;$PLATFORM"
  yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
  "$SDKMANAGER" --sdk_root="$SDK" --install \
    "build-tools;$BT" "platforms;$PLATFORM" >/dev/null
fi

BTP="$SDK/build-tools/$BT"

# ------------------------------------------------------------------ binaries
install -m 0755 "$BTP/aapt2"       "$HERE/tools/aapt2"
install -m 0644 "$BTP/lib/d8.jar"  "$HERE/tools/d8.jar"
install -m 0644 "$SDK/platforms/$PLATFORM/android.jar" "$HERE/tools/android.jar"

# apksigner ships inside build-tools as a library plus a launcher script; grab
# the library jar directly so the build can call it through `java -jar`.
if [ -f "$BTP/lib/apksigner.jar" ]; then
  install -m 0644 "$BTP/lib/apksigner.jar" "$HERE/tools/apksigner.jar"
else
  curl -fsSL -o "$HERE/tools/apksigner.jar" \
    "https://repo1.maven.org/maven2/com/android/tools/build/apksig/${APKSIG_VERSION:-8.6.0}/apksig-${APKSIG_VERSION:-8.6.0}.jar"
fi

# ecj (the Eclipse batch compiler) is not part of the SDK any more.
if [ ! -f "$HERE/tools/ecj.jar" ]; then
  ECJ_VERSION="${ECJ_VERSION:-3.38.0}"
  curl -fsSL -o "$HERE/tools/ecj.jar" \
    "https://repo1.maven.org/maven2/org/eclipse/jdt/ecj/${ECJ_VERSION}/ecj-${ECJ_VERSION}.jar"
fi

echo "» toolchain ready:"
for f in aapt2 d8.jar android.jar apksigner.jar ecj.jar; do
  printf '   %-16s %s\n' "$f" "$(du -h "$HERE/tools/$f" | cut -f1)"
done
