#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
import json
import shutil
import struct
import sys

root = Path(sys.argv[1]).resolve()
source = root / "input/legacy/mmkv"
data_path = source / "mmkv.default"
crc_path = source / "mmkv.default.crc"
if not data_path.is_file() or not crc_path.is_file():
    raise SystemExit("the complete source MMKV fixture is missing")
variants = root / "input/mmkv-errors"
if len(sys.argv) != 4:
    raise SystemExit("usage: make-damaged-mmkv-fixtures.py <fixture-root> <meta-size> <crc-offset>")
meta_size = int(sys.argv[2])
crc_offset = int(sys.argv[3])
active_length = struct.unpack("<I", data_path.read_bytes()[:4])[0]
if len(data_path.read_bytes()) < 4 or crc_offset < 0 or crc_offset + 4 > meta_size:
    raise SystemExit("MMKV source or metadata layout is invalid")
specs = {
    "truncated-data": "data",
    "truncated-crc": "crc",
    "wrong-crc": "wrong-crc",
}
for name, damage in specs.items():
    destination = variants / name
    if destination.exists():
        raise SystemExit(f"output already exists: {destination}")
    destination.mkdir(parents=True)
    shutil.copyfile(data_path, destination / data_path.name)
    shutil.copyfile(crc_path, destination / crc_path.name)
    damaged_path = destination / (data_path.name if damage == "data" else crc_path.name)
    value = bytearray(damaged_path.read_bytes())
    if damage == "data":
        value = value[:3]
    elif damage == "crc":
        value = value[:meta_size - 1]
    else:
        value[crc_offset] ^= 0x80
    damaged_path.write_bytes(value)

manifest_path = root / "fixture-manifest.json"
manifest = json.loads(manifest_path.read_text())
manifest["mmkvDamageVariants"] = {
    name: {
        "dataSha256": sha256((variants / name / "mmkv.default").read_bytes()).hexdigest(),
        "crcSha256": sha256((variants / name / "mmkv.default.crc").read_bytes()).hexdigest(),
        "dataBytes": (variants / name / "mmkv.default").stat().st_size,
        "crcBytes": (variants / name / "mmkv.default.crc").stat().st_size,
        "activeLength": active_length,
        "metaInfoBytes": meta_size,
        "crcDigestOffset": crc_offset,
    }
    for name in specs
}
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Created damaged MMKV copies; activeLength={active_length}, metaInfoBytes={meta_size}, crcDigestOffset={crc_offset}.")
