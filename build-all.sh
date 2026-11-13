#!/usr/bin/env bash
# ============================================================================
#  Rebo · build-all.sh — build every deliverable in one pass.
#
#     1. verify the generated content is present (regenerate on request)
#     2. build the signed APK
#     3. build the Windows app + installer
#     4. write dist/SHA256SUMS.txt and run the release checks
#
#  Usage:  JAVA_HOME=/path/to/jdk17 ZIG=/path/to/zig bash build-all.sh [--content]
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/lib/common.sh
. "$HERE/tools/lib/common.sh"

if [ "${1:-}" = "--content" ]; then
  step "regenerating content from the .docx sources"
  require python3 "needed by the content pipeline"
  python3 "$HERE/app/pipeline/build_content.py"
fi

require_file "$HERE/app/www/js/data.js" "شغّل: bash build-all.sh --content"

step "checking version consistency"
python3 "$HERE/tools/sync-version.py" --check

bash "$HERE/build-android.sh"
ZIG="${ZIG:-zig}" bash "$HERE/build-windows.sh"

step "writing checksums"
python3 "$HERE/tools/make_manifest.py"

step "running release checks"
JAVA="${JAVA:-java}" python3 "$HERE/tools/check.py"

echo
ok "all deliverables built and verified — see ./dist"
