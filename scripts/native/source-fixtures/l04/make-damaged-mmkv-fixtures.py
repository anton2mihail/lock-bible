#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
import json
import shutil
import sys

root = Path(sys.argv[1]).resolve()
source = root / "input/legacy/mmkv"
data_path = source / "mmkv.default"
crc_path = source / "mmkv.default.crc"
if not data_path.is_file() or not crc_path.is_file():
    raise SystemExit("the complete source MMKV fixture is missing")
variants = root / "input/mmkv-errors"
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
    value = damaged_path.read_bytes()
    if damage in ("data", "crc"):
        damaged_path.write_bytes(value[:-5])
    else:
        changed = bytearray(value)
        changed[-1] ^= 0x80
        damaged_path.write_bytes(changed)

manifest_path = root / "fixture-manifest.json"
manifest = json.loads(manifest_path.read_text())
manifest["mmkvDamageVariants"] = {
    name: {
        "dataSha256": sha256((variants / name / "mmkv.default").read_bytes()).hexdigest(),
        "crcSha256": sha256((variants / name / "mmkv.default.crc").read_bytes()).hexdigest(),
    }
    for name in specs
}
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print("Created truncated-data, truncated-CRC, and wrong-CRC copies.")
