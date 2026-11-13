#!/usr/bin/env bash
# ============================================================================
#  Rebo · shared build helpers
#  Sourced by build-*.sh — logging, preconditions and hard failure gates.
# ============================================================================

if [ -n "${REBO_COMMON_SH:-}" ]; then return 0; fi
REBO_COMMON_SH=1

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  C_STEP=$'\033[38;5;75m'; C_OK=$'\033[38;5;78m'; C_WARN=$'\033[38;5;214m'
  C_ERR=$'\033[38;5;203m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_STEP=; C_OK=; C_WARN=; C_ERR=; C_DIM=; C_OFF=
fi

step() { printf '%s»%s %s\n' "$C_STEP" "$C_OFF" "$*"; }
ok()   { printf '%s✔%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
die()  { printf '%s✖ %s%s\n' "$C_ERR" "$*" "$C_OFF" >&2; exit 1; }

# require <command> <hint>
require() {
  command -v "$1" >/dev/null 2>&1 || die "أداة مفقودة: $1 — $2"
}

# require_file <path> <hint>
require_file() {
  local path="$1" hint="${2:-}"
  [ -e "$path" ] || die "ملف مفقود: ${path} — ${hint}"
}

# Version metadata comes from package.json (single source of truth).
rebo_version() {
  python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" \
    "$1/package.json"
}

# Deterministic build timestamp: honour SOURCE_DATE_EPOCH when set.
rebo_epoch() {
  printf '%s' "${SOURCE_DATE_EPOCH:-0}"
}

# JVM flags for the SDK tools. JDK 24+ warns about restricted native access in
# apksigner/d8; the flag is harmless on older JDKs, so we probe support once.
rebo_java_flags() {
  if [ -n "${REBO_JAVA_FLAGS:-}" ]; then printf '%s' "$REBO_JAVA_FLAGS"; return; fi
  if java --enable-native-access=ALL-UNNAMED -version >/dev/null 2>&1; then
    REBO_JAVA_FLAGS="--enable-native-access=ALL-UNNAMED"
  else
    REBO_JAVA_FLAGS=""
  fi
  printf '%s' "$REBO_JAVA_FLAGS"
}
