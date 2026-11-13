#!/usr/bin/env bash
# ============================================================================
#  Rebo · build-android.sh
#
#  Builds a signed, zipaligned APK straight from the official Android
#  command-line toolchain (no Gradle, no network access at build time):
#
#     aapt2        resource compiler / linker        (build-tools)
#     ecj          Java compiler                     (Eclipse JDT core)
#     d8           dexer                             (build-tools)
#     apksigner    signing (v1 + v2 + v3)            (build-tools)
#     zipalign.py  4-byte alignment (portable impl.) tools/
#     android.jar  platform API                      (platform 34)
#
#  The web app is copied to assets/www, so the APK is fully offline.
#  Every step is verified; a failing check aborts the build.
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/lib/common.sh
. "$HERE/tools/lib/common.sh"

AAPT2="${AAPT2:-$HERE/tools/aapt2}"
ANDROID_JAR="${ANDROID_JAR:-$HERE/tools/android.jar}"
D8_JAR="${D8_JAR:-$HERE/tools/d8.jar}"
ECJ_JAR="${ECJ_JAR:-$HERE/tools/ecj.jar}"
APKSIGNER_JAR="${APKSIGNER_JAR:-$HERE/tools/apksigner.jar}"
KEYSTORE="${KEYSTORE:-$HERE/keystore/rebo-release.jks}"
KS_PASS="${KS_PASS:-rebo-keystore-2026}"
KS_ALIAS="${KS_ALIAS:-rebo}"
JAVA="${JAVA:-java}"
JAVA_FLAGS="$(rebo_java_flags)"

SRC="$HERE/app/android"
OUT="$HERE/build/android"
APP_WWW="$HERE/app/www"
GEN="$OUT/gen"

VERSION="$(rebo_version "$HERE")"
VERSION_CODE="$(python3 -c 'import json,sys;v=json.load(open(sys.argv[1]))["version"].split(".");print(int(v[0])*10000+int(v[1])*100+int(v[2]))' "$HERE/package.json")"
APK_NAME="rebo-android-v${VERSION}.apk"

# ---------------------------------------------------------------- preflight
step "preflight"
require java  "اضبط JAVA_HOME على JDK 17 أو أحدث"
require python3 "لازم لمحاذاة الحزمة والأدوات المساعدة"
require_file "$AAPT2"          "Android SDK build-tools 34.0.0 (aapt2)"
require_file "$ANDROID_JAR"    "Android SDK platform 34 (android.jar)"
require_file "$D8_JAR"         "Android SDK build-tools (d8.jar)"
require_file "$ECJ_JAR"        "Eclipse JDT core (ecj.jar)"
require_file "$APKSIGNER_JAR"  "Android SDK build-tools (apksigner.jar)"
require_file "$KEYSTORE"       "مفتاح التوقيع (keystore/rebo-release.jks)"

if [ "${CI:-}" = "true" ]; then
  "$JAVA" -version >/dev/null 2>&1
fi

# Keep every generated version string in lockstep with package.json.
python3 "$HERE/tools/sync-version.py" --check >/dev/null \
  || die "أرقام الإصدار غير متزامنة — شغّل: python3 tools/sync-version.py"

rm -rf "$OUT"
mkdir -p "$OUT/compiled" "$OUT/classes" "$OUT/dex" "$GEN"

# ------------------------------------------------------------------ assets
step "syncing web assets"
rm -rf "$SRC/assets/www"
mkdir -p "$SRC/assets/www"
cp -R "$APP_WWW/." "$SRC/assets/www/"
find "$SRC/assets/www" -name '.DS_Store' -delete
n_assets=$(find "$SRC/assets/www" -type f | wc -l | tr -d ' ')
[ "$n_assets" -ge 30 ] || die "نسخ الأصول غير مكتمل ($n_assets ملفًا)"

# ---------------------------------------------------------------- resources
step "compiling resources (aapt2)"
"$AAPT2" compile --dir "$SRC/res" -o "$OUT/compiled/res.zip"

step "linking resources (aapt2)"
"$AAPT2" link \
  -o "$OUT/base.apk" \
  -I "$ANDROID_JAR" \
  --manifest "$SRC/AndroidManifest.xml" \
  "$OUT/compiled/res.zip" \
  -A "$SRC/assets" \
  --java "$GEN" \
  --min-sdk-version 21 \
  --target-sdk-version 34 \
  --version-code "$VERSION_CODE" \
  --version-name "$VERSION" \
  --auto-add-overlay

# --------------------------------------------------------------------- java
step "compiling java (ecj)"
find "$SRC/java" -name '*.java' -print > "$OUT/sources.txt"
[ -s "$OUT/sources.txt" ] || die "لم يُعثر على أي ملف Java في app/android/java"
# -Xlint:-options silences the "source 8 is obsolete" note on newer JDKs only.
"$JAVA" -jar "$ECJ_JAR" -source 8 -target 8 -nowarn \
  -bootclasspath "$ANDROID_JAR" -classpath "$ANDROID_JAR" \
  -d "$OUT/classes" @"$OUT/sources.txt" > "$OUT/ecj.log" 2>&1 \
  || { cat "$OUT/ecj.log" >&2; die "فشل تصريف Java"; }
[ -f "$OUT/classes/com/techtouch/rebo/MainActivity.class" ] \
  || die "لم يُنتج التصريف MainActivity.class"

# ---------------------------------------------------------------------- dex
step "dexing (d8)"
# shellcheck disable=SC2046
"$JAVA" -cp "$D8_JAR" com.android.tools.r8.D8 \
  --min-api 21 --release --lib "$ANDROID_JAR" \
  --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')
[ -f "$OUT/dex/classes.dex" ] || die "لم يُنتج d8 ملف classes.dex"

# ---------------------------------------------------------------- packaging
step "packaging"
cp "$OUT/base.apk" "$OUT/unsigned.apk"
# -X strips extra attributes; timestamps come from SOURCE_DATE_EPOCH when set,
# so repeated builds of identical sources produce identical packages.
( cd "$OUT/dex" && TZ=UTC touch -t 202601010000 classes.dex \
    && zip -q -X "$OUT/unsigned.apk" classes.dex )

step "zipalign (4-byte, page-aligned .so)"
python3 "$HERE/tools/zipalign.py" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
python3 "$HERE/tools/zipalign.py" --verify 4 "$OUT/aligned.apk" \
  || die "فشل التحقق من محاذاة الحزمة"

step "signing"
"$JAVA" $JAVA_FLAGS -jar "$APKSIGNER_JAR" sign \
  --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias "$KS_ALIAS" \
  --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
  --out "$OUT/$APK_NAME" "$OUT/aligned.apk"

step "verifying signature"
"$JAVA" $JAVA_FLAGS -jar "$APKSIGNER_JAR" verify --verbose --print-certs "$OUT/$APK_NAME" \
  > "$OUT/verify.log" 2>&1 || { cat "$OUT/verify.log" >&2; die "توقيع APK غير صالح"; }
grep -q "Verified using v2 scheme (APK Signature Scheme v2): true" "$OUT/verify.log" \
  || die "التوقيع v2 مفقود"
grep -q "Verified using v3 scheme (APK Signature Scheme v3): true" "$OUT/verify.log" \
  || die "التوقيع v3 مفقود"

step "inspecting package"
"$AAPT2" dump badging "$OUT/$APK_NAME" > "$OUT/badging.txt"
grep -q "package: name='com.techtouch.rebo' versionCode='$VERSION_CODE' versionName='$VERSION'" \
  "$OUT/badging.txt" || die "بيانات الحزمة لا تطابق الإصدار $VERSION"
grep -q "launchable-activity: name='com.techtouch.rebo.MainActivity'" "$OUT/badging.txt" \
  || die "النشاط القابل للتشغيل مفقود في AndroidManifest"

# ---------------------------------------------------------------------- out
mkdir -p "$HERE/dist"
cp "$OUT/$APK_NAME" "$HERE/dist/$APK_NAME"
ok "APK: dist/$APK_NAME ($(du -h "$HERE/dist/$APK_NAME" | cut -f1))"
printf '%s   %s · versionCode %s\n' "$C_DIM" "$VERSION" "$VERSION_CODE$C_OFF"
