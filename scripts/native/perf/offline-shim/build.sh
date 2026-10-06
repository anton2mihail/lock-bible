#!/bin/bash
# Build the offline shim and probe. Source only. Does not start a simulator.
# Usage: build.sh sim|host OUTPUT_DIR     (OUTPUT_DIR must not exist)
#   sim  : arm64 iOS 26.0 Simulator dylib and probe, for the dedicated John device.
#   host : arm64 macOS build. Use it only for the loopback self-test in the run procedure.
set -euo pipefail
mode="${1:-}"; out="${2:-}"
[ -n "$mode" ] && [ -n "$out" ] || { echo "usage: $0 sim|host OUTPUT_DIR" >&2; exit 2; }
[ ! -e "$out" ] || { echo "OUTPUT_DIR already exists: $out" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"
case "$mode" in
  sim)  sdk=iphonesimulator; target=arm64-apple-ios26.0-simulator ;;
  host) sdk=macosx;          target=arm64-apple-macos15.0 ;;
  *) echo "mode must be sim or host" >&2; exit 2 ;;
esac
xcrun --sdk "$sdk" clang -target "$target" -O1 -Wall -dynamiclib "$here/offline_shim.c" \
  -install_name "@rpath/offline_shim.dylib" -o "$out/offline_shim.dylib"
xcrun --sdk "$sdk" clang -target "$target" -O1 -Wall -fobjc-arc -framework Foundation "$here/offline_probe.m" -o "$out/offline_probe"
codesign --force --sign - "$out/offline_shim.dylib" "$out/offline_probe" 2>/dev/null || true
shasum -a 256 "$out/offline_shim.dylib" "$out/offline_probe" | tee "$out/SHA256SUMS"
