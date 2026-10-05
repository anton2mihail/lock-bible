#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
OUT_DIR="${1:-$ROOT_DIR/build/native-evidence/L04/fixtures/gate-a-synthetic}"
OUT_DIR="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$OUT_DIR")"
if [[ -e "$OUT_DIR" ]]; then
  echo "Output already exists: $OUT_DIR" >&2
  exit 2
fi

bun "$ROOT_DIR/scripts/native/source-fixtures/l04/write-fixture-data.ts" "$OUT_DIR"

VENDOR="$ROOT_DIR/native/John/LegacyAdapter/Vendor/MMKVCore"
DERIVED="$OUT_DIR/build/MMKVCore-mac"
mkdir -p "$OUT_DIR/build"
xcodebuild -project "$VENDOR/Core.xcodeproj" -scheme Core -configuration Debug \
  -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
  GCC_PREPROCESSOR_DEFINITIONS='DEBUG=1 FORCE_POSIX=1 $(inherited)' build \
  > "$OUT_DIR/build/mmkv-core-host.log" 2>&1

CORE_LIB="$DERIVED/Build/Products/Debug/libMMKVCore.a"
clang++ -std=c++20 -DFORCE_POSIX=1 -I "$VENDOR" \
  "$ROOT_DIR/scripts/native/source-fixtures/l04/create-mmk-v2-fixture.cpp" \
  "$CORE_LIB" -framework Foundation -lz -o "$OUT_DIR/build/create-mmv2-fixture"

BUILDER="$OUT_DIR/build/create-mmv2-fixture"
"$BUILDER" "$OUT_DIR/input/legacy/mmkv" "$OUT_DIR/legacy-values.tsv"
"$BUILDER" "$OUT_DIR/input/invalid-legacy/mmkv" "$OUT_DIR/invalid-legacy-values.tsv"
MMKV_LAYOUT=$("$BUILDER" --layout)
MMKV_META_SIZE="${MMKV_LAYOUT%%$'\t'*}"
MMKV_CRC_OFFSET="${MMKV_LAYOUT#*$'\t'}"
python3 "$ROOT_DIR/scripts/native/source-fixtures/l04/make-damaged-mmkv-fixtures.py" \
  "$OUT_DIR" "$MMKV_META_SIZE" "$MMKV_CRC_OFFSET"

python3 - "$OUT_DIR" <<'PY'
from hashlib import sha256
from pathlib import Path
import json
import sys

root = Path(sys.argv[1])
manifest_path = root / "fixture-manifest.json"
manifest = json.loads(manifest_path.read_text())
files = {}
for path in sorted((root / "input").rglob("*")):
    if not path.is_file():
        continue
    if "-shm" in path.name:
        continue
    data = path.read_bytes()
    if not data:
        raise SystemExit(f"Empty fixture input: {path}")
    files[path.relative_to(root).as_posix()] = {
        "bytes": len(data),
        "sha256": sha256(data).hexdigest(),
    }
manifest["inputFiles"] = files
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Fixture input files: {len(files)}; all non-empty and hashed.")
PY

echo "Synthetic Gate A fixture root: $OUT_DIR"
echo "Use this path as the test input. Do not change the app-created baseline fixture."
