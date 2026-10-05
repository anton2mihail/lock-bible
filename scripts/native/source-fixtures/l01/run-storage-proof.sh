#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
PROOF_DIR="$ROOT_DIR/build/native-evidence/L01/storage-proof"
MMKV_CORE="$ROOT_DIR/node_modules/react-native-mmkv/MMKV/Core"
CORE_PROJECT="$MMKV_CORE/Core.xcodeproj"
SOURCE="$ROOT_DIR/scripts/native/source-fixtures/l01/storage_proof.mm"
mkdir -p "$PROOF_DIR"

xcodebuild -project "$CORE_PROJECT" -scheme Core -sdk macosx -destination 'generic/platform=macOS' \
  -derivedDataPath "$PROOF_DIR/MacDerivedData" GCC_PREPROCESSOR_DEFINITIONS=FORCE_POSIX build \
  > "$PROOF_DIR/xcodebuild-macos.log" 2>&1
xcodebuild -project "$CORE_PROJECT" -scheme Core -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$PROOF_DIR/DerivedData" GCC_PREPROCESSOR_DEFINITIONS=FORCE_POSIX build \
  > "$PROOF_DIR/xcodebuild-simulator.log" 2>&1

MAC_SDK="$(xcrun --sdk macosx --show-sdk-path)"
SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
MAC_CORE="$PROOF_DIR/MacDerivedData/Build/Products/Debug/libMMKVCore.a"
SIM_CORE="$PROOF_DIR/DerivedData/Build/Products/Debug-iphonesimulator/libMMKVCore.a"

clang++ -std=c++17 -fobjc-arc -fblocks -DFORCE_POSIX -isysroot "$MAC_SDK" -mmacosx-version-min=13.0 \
  -I "$MMKV_CORE" "$SOURCE" "$MAC_CORE" -framework Foundation -lsqlite3 -lz \
  -o "$PROOF_DIR/storage-proof-host"
clang++ -std=c++17 -fobjc-arc -fblocks -DFORCE_POSIX -target arm64-apple-ios26.0-simulator -isysroot "$SIM_SDK" \
  -I "$MMKV_CORE" "$SOURCE" "$SIM_CORE" -framework Foundation -lsqlite3 -lz \
  -o "$PROOF_DIR/storage-proof-simulator"

FIXTURE_PARENT="$(mktemp -d "$PROOF_DIR/synthetic-mmkv.XXXXXX")"
FIXTURE_ROOT="$FIXTURE_PARENT/mmkv-root"
"$PROOF_DIR/storage-proof-host" synthetic-create \
  "$ROOT_DIR/assets/bible/bible-search.db" \
  "$ROOT_DIR/assets/works/works.db" \
  "$FIXTURE_PARENT/create-output" \
  "$FIXTURE_ROOT"
"$PROOF_DIR/storage-proof-host" host-audit \
  "$ROOT_DIR/assets/bible/bible-search.db" \
  "$ROOT_DIR/assets/works/works.db" \
  "$PROOF_DIR/runtime-output" \
  "$FIXTURE_ROOT" \
  'bible.reader.textSize,novena.synthetic.progress.v1,vesper.sunday.2026-10-05' | tee "$PROOF_DIR/host-run.txt"

shasum -a 256 "$SOURCE" "$ROOT_DIR/node_modules/react-native-mmkv/package.json" \
  "$ROOT_DIR/node_modules/react-native-mmkv/react-native-mmkv.podspec" \
  "$ROOT_DIR/node_modules/react-native-mmkv/src/createMMKV.ts" \
  "$MMKV_CORE/MMKVPredef.h" "$MMKV_CORE/MMKV.h" \
  "$ROOT_DIR/assets/bible/bible-search.db" "$ROOT_DIR/assets/works/works.db" \
  > "$PROOF_DIR/source-hashes.sha256"
file "$PROOF_DIR/storage-proof-host" "$PROOF_DIR/storage-proof-simulator" \
  > "$PROOF_DIR/binary-types.txt"
