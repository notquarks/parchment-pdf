#!/usr/bin/env bash
# ============================================================================
# Parchment PDF — Release build script
# ============================================================================
# Builds optimized release artifacts for Android and Windows.
#
# Usage:
#   ./scripts/build.sh android-aab      # Android App Bundle (Play Store)
#   ./scripts/build.sh android-apk      # Android APK split per ABI
#   ./scripts/build.sh windows          # Windows desktop
#   ./scripts/build.sh all              # All platforms
#
# Crash symbolication:
#   Build artifacts include --split-debug-info files in build/debug-info/.
#   Upload these to Firebase Crashlytics or Sentry to decode obfuscated
#   stack traces. Do NOT commit them — they are in .gitignore.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEBUG_INFO_DIR="$PROJECT_DIR/build/debug-info"

COMMON_FLAGS=(
  --release
  --split-debug-info="$DEBUG_INFO_DIR"
  --obfuscate
)

mkdir -p "$DEBUG_INFO_DIR"

build_android_aab() {
  echo "==> Building Android App Bundle (AAB)..."
  flutter build appbundle "${COMMON_FLAGS[@]}"
  local aab="$PROJECT_DIR/build/app/outputs/bundle/release/app-release.aab"
  if [[ -f "$aab" ]]; then
    echo "    Output: $aab ($(du -h "$aab" | cut -f1))"
  else
    echo "    ERROR: AAB not found at expected path" >&2
    return 1
  fi
}

build_android_apk() {
  echo "==> Building Android APK (split per ABI)..."
  flutter build apk "${COMMON_FLAGS[@]}" --split-per-abi
  local apk_dir="$PROJECT_DIR/build/app/outputs/flutter-apk"
  if [[ -d "$apk_dir" ]]; then
    echo "    Output:"
    ls -lh "$apk_dir"/*.apk 2>/dev/null | awk '{print "      " $NF " (" $5 ")"}'
  else
    echo "    ERROR: APK directory not found" >&2
    return 1
  fi
}

build_windows() {
  echo "==> Building Windows desktop..."
  flutter build windows "${COMMON_FLAGS[@]}"
  local exe_dir="$PROJECT_DIR/build/windows/x64/runner/Release"
  if [[ -d "$exe_dir" ]]; then
    echo "    Output: $exe_dir/"
    ls -lh "$exe_dir"/*.exe 2>/dev/null | awk '{print "      " $NF " (" $5 ")"}'
  else
    echo "    ERROR: Windows build directory not found" >&2
    return 1
  fi
}


if [[ $# -eq 0 ]]; then
  echo "Usage: $0 {android-aab|android-apk|windows|all}"
  exit 1
fi

for target in "$@"; do
  case "$target" in
    android-aab)  build_android_aab ;;
    android-apk)  build_android_apk ;;
    windows)      build_windows ;;
    all)
      build_android_aab
      build_android_apk
      build_windows
      ;;
    *)
      echo "Unknown target: $target" >&2
      echo "Valid targets: android-aab, android-apk, windows, all" >&2
      exit 1
      ;;
  esac
done

echo ""
echo "==> Done. Debug symbolication files in: $DEBUG_INFO_DIR"
echo "    Upload these to your crash reporting tool to decode obfuscated traces."
