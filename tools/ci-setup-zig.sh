#!/usr/bin/env bash
# ============================================================================
#  Rebo · tools/ci-setup-zig.sh
#
#  Installs the Zig toolchain the Windows cross-build needs, into the cached
#  path tools/.cache/zig. Official ziglang.org tarball only.
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$HERE/tools/.cache"
ZIG_VERSION="${ZIG_VERSION:-0.13.0}"
DEST="$CACHE/zig"

if [ -x "$DEST/zig" ]; then
  echo "» zig already cached: $("$DEST/zig" version)"
  exit 0
fi

case "$(uname -m)" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=aarch64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

URL="https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ARCH}-${ZIG_VERSION}.tar.xz"
echo "» downloading $URL"
mkdir -p "$CACHE"
curl -fsSL "$URL" -o "$CACHE/zig.tar.xz"
rm -rf "$CACHE/zig-unpacked" && mkdir -p "$CACHE/zig-unpacked"
tar -xJf "$CACHE/zig.tar.xz" -C "$CACHE/zig-unpacked" --strip-components=1
mkdir -p "$CACHE/zig-unpacked-lib"
mv "$CACHE/zig-unpacked" "$DEST"
chmod +x "$DEST/zig"
echo "» zig $("$DEST/zig" version) ready at $DEST/zig"
