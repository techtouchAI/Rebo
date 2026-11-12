#!/usr/bin/env bash
# Fetch the official Android command-line toolchain pieces used to build the APK.
# Everything is downloaded from Google's official endpoints.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$DIR/.env" ]; then . "$DIR/.env"; fi
: "${SDK_ZIP_URL:=https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip}"
: "${BUILD_TOOLS_VERSION:=34.0.0}"
: "${PLATFORM:=android-34}"

echo "This script needs the Android *platform* and *build-tools* packages."
echo "Recommended (official):"
echo "  sdkmanager --install \"build-tools;${BUILD_TOOLS_VERSION}\" \"platforms;${PLATFORM}\""
echo
echo "Then copy:"
echo "  \$ANDROID_HOME/build-tools/${BUILD_TOOLS_VERSION}/aapt2      -> tools/aapt2"
echo "  \$ANDROID_HOME/build-tools/${BUILD_TOOLS_VERSION}/d8.jar     -> tools/d8.jar"
echo "  \$ANDROID_HOME/build-tools/${BUILD_TOOLS_VERSION}/apksigner.jar -> tools/apksigner.jar"
echo "  \$ANDROID_HOME/build-tools/${BUILD_TOOLS_VERSION}/lib/apksigner.jar (same file)"
echo "  \$ANDROID_HOME/platforms/${PLATFORM}/android.jar           -> tools/android.jar"
echo "  \$ANDROID_HOME/build-tools/${BUILD_TOOLS_VERSION}/lib/ecj.jar (or ecj-*.jar) -> tools/ecj.jar"
echo
echo "Alternatively download the command-line tools zip: $SDK_ZIP_URL"
echo "and run: sdkmanager --sdk_root=\$PWD/.sdk \"build-tools;${BUILD_TOOLS_VERSION}\" \"platforms;${PLATFORM}\""
