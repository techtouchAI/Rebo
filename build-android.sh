#!/usr/bin/env bash
# ============================================================================
#  Rebo · build-android.sh
#  Builds a signed, zipaligned APK straight from the official Android
#  command-line toolchain (no Gradle, no network downloads at build time):
#
#    aapt2   resource compiler / linker   (build-tools)
#    ecj     Java compiler                (Eclipse JDT core, build-tools)
#    d8      dexer                        (build-tools)
#    apksigner + zipalign                 (build-tools)
#    android.jar                          (platform)
#
#  The web app is copied to assets/www, so the APK is fully offline.
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TOOLS="${TOOLS:-/tmp/pk}"                 # directory holding the SDK tools
AAPT2="${AAPT2:-$HERE/tools/aapt2}"
ANDROID_JAR="${ANDROID_JAR:-$HERE/tools/android.jar}"
D8_JAR="${D8_JAR:-$HERE/tools/d8.jar}"
ECJ_JAR="${ECJ_JAR:-$HERE/tools/ecj.jar}"
APKSIGNER_JAR="${APKSIGNER_JAR:-$HERE/tools/apksigner.jar}"
ZIPALIGN="${ZIPALIGN:-python3 $HERE/tools/zipalign.py -f -p}"
KEYSTORE="${KEYSTORE:-$HERE/keystore/rebo-release.jks}"
KS_PASS="${KS_PASS:-rebo-keystore-2026}"
KS_ALIAS="${KS_ALIAS:-rebo}"
JAVA="${JAVA:-java}"

SRC="$HERE/app/android"
OUT="$HERE/build/android"
APP_WWW="$HERE/app/www"

rm -rf "$OUT"
mkdir -p "$OUT/compiled" "$OUT/classes" "$OUT/dex"

echo "» syncing web assets"
rm -rf "$SRC/assets/www"
mkdir -p "$SRC/assets/www"
cp -R "$APP_WWW/." "$SRC/assets/www/"

echo "» compiling resources (aapt2)"
"$AAPT2" compile --dir "$SRC/res" -o "$OUT/compiled/res.zip"

echo "» linking resources (aapt2)"
"$AAPT2" link \
  -o "$OUT/base.apk" \
  -I "$ANDROID_JAR" \
  --manifest "$SRC/AndroidManifest.xml" \
  "$OUT/compiled/res.zip" \
  -A "$SRC/assets" \
  --java "$OUT/gen" \
  --min-sdk-version 21 \
  --target-sdk-version 34 \
  --version-code 1 --version-name "1.0.0" \
  --auto-add-overlay

echo "» compiling java (ecj)"
find "$SRC/java" -name '*.java' > "$OUT/sources.txt"
"$JAVA" -jar "$ECJ_JAR" -source 8 -target 8 -nowarn \
  -bootclasspath "$ANDROID_JAR" -classpath "$ANDROID_JAR" \
  -d "$OUT/classes" @"$OUT/sources.txt"

echo "» dexing (d8)"
"$JAVA" -cp "$D8_JAR" com.android.tools.r8.D8 \
  --min-api 21 --release --lib "$ANDROID_JAR" \
  --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')

echo "» packaging"
cp "$OUT/base.apk" "$OUT/unsigned.apk"
( cd "$OUT/dex" && zip -q -X ../unsigned.apk classes.dex )

echo "» zipalign"
$ZIPALIGN 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

echo "» signing"
"$JAVA" -jar "$APKSIGNER_JAR" sign \
  --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias "$KS_ALIAS" \
  --v1-signing-enabled true --v2-signing-enabled true \
  --out "$OUT/rebo-android-v1.0.0.apk" "$OUT/aligned.apk"

"$JAVA" -jar "$APKSIGNER_JAR" verify --print-certs "$OUT/rebo-android-v1.0.0.apk" || true

mkdir -p "$HERE/dist"
cp "$OUT/rebo-android-v1.0.0.apk" "$HERE/dist/rebo-android-v1.0.0.apk"
echo
echo "✔ APK ready: dist/rebo-android-v1.0.0.apk  ($(du -h "$HERE/dist/rebo-android-v1.0.0.apk" | cut -f1))"
