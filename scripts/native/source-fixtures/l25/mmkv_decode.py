#!/usr/bin/env python3
"""Read-only decoder for the legacy MMKV default instance (MMKV Core 2.0.0 layout, no encryption).

Usage: mmkv_decode.py <mmkv-dir-or-data-file>

The decoder opens both files read-only. It never writes. It replays the append log in order.
A key with an empty value removes the key. The last value for a key wins.
It checks the CRC32 and the actual size in the meta (.crc) file.
"""
import json
import os
import struct
import sys
import zlib


def read_varint(buf, pos):
    shift = 0
    value = 0
    while True:
        byte = buf[pos]
        pos += 1
        value |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return value, pos
        shift += 7
        if shift > 63:
            raise ValueError("varint too long")


def decode(data_path, crc_path):
    with open(data_path, "rb") as handle:
        data = handle.read()
    with open(crc_path, "rb") as handle:
        meta = handle.read()
    crc_digest, version, sequence = struct.unpack_from("<III", meta, 0)
    actual_size = struct.unpack_from("<I", meta, 28)[0]
    last_actual, last_crc = struct.unpack_from("<II", meta, 32)
    old_style_size = struct.unpack_from("<I", data, 0)[0]
    region = data[4:4 + actual_size]
    computed = zlib.crc32(region) & 0xFFFFFFFF
    report = {
        "metaVersion": version,
        "sequence": sequence,
        "actualSize": actual_size,
        "oldStyleActualSize": old_style_size,
        "crcInMeta": "%08x" % crc_digest,
        "crcComputed": "%08x" % computed,
        "crcOK": crc_digest == computed,
        "dataFileBytes": len(data),
    }
    # The first four bytes of the region are skipped by the Core reader (readInt32).
    pos = 4
    log = []
    values = {}
    while pos < len(region):
        key_len, pos = read_varint(region, pos)
        key = region[pos:pos + key_len].decode("utf-8")
        pos += key_len
        value_len, pos = read_varint(region, pos)
        raw = region[pos:pos + value_len]
        pos += value_len
        if not key:
            continue
        if value_len == 0:
            values.pop(key, None)
            log.append({"key": key, "op": "delete"})
            continue
        text = None
        try:
            inner_len, inner_pos = read_varint(raw, 0)
            if inner_pos + inner_len == len(raw):
                text = raw[inner_pos:].decode("utf-8")
        except Exception:
            text = None
        entry = {"rawHex": raw.hex(), "string": text}
        values[key] = entry
        log.append({"key": key, "op": "set", "string": text, "rawHex": raw.hex()})
    report["keys"] = {k: v["string"] if v["string"] is not None else "rawHex:" + v["rawHex"] for k, v in sorted(values.items())}
    report["appendLogEntries"] = len(log)
    report["appendLog"] = log
    return report


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    target = sys.argv[1]
    if os.path.isdir(target):
        data_path = os.path.join(target, "mmkv.default")
    else:
        data_path = target
    crc_path = data_path + ".crc"
    result = decode(data_path, crc_path)
    print(json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False))
    return 0 if result["crcOK"] else 1


if __name__ == "__main__":
    sys.exit(main())
