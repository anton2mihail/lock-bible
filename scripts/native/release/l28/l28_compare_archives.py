#!/usr/bin/env python3
"""L28 reproducibility comparison of two builds. Source only. Read only on the inputs.

Compares two .xcarchive folders (or two John.app folders) file by file.
For Mach-O files it also compares the content after the code signature is removed (done on temporary copies),
and the LC_UUID values. For dSYM folders it compares the DWARF UUIDs.
Result classes per file: identical, signature-only (same after signature removal), different, only-in-A, only-in-B.
Known volatile files are listed apart: the archive Info.plist (creation date) and _CodeSignature folders.

Usage: l28_compare_archives.py --a ARCHIVE_A --b ARCHIVE_B --out-dir NEW_DIR
Exit code 0 = no 'different' and no only-in files. Exit code 1 = differences found.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

MAGIC = (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe")


def sha(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def is_macho(path):
    with open(path, "rb") as handle:
        return handle.read(4) in MAGIC


def stripped_sha(path):
    with tempfile.TemporaryDirectory() as folder:
        copy = os.path.join(folder, "x")
        shutil.copyfile(path, copy)
        subprocess.run(["codesign", "--remove-signature", copy], capture_output=True)
        return sha(copy)


def uuids(path):
    out = subprocess.run(["otool", "-l", str(path)], capture_output=True, text=True).stdout
    return re.findall(r"uuid\s+([0-9A-F-]{36})", out)


def inventory(root):
    files = {}
    for path in sorted(Path(root).rglob("*")):
        if path.is_file() and not path.is_symlink():
            files[str(path.relative_to(root))] = path
    return files


def volatile(rel):
    return rel == "Info.plist" or "/_CodeSignature/" in "/" + rel or rel.endswith("embedded.mobileprovision")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--a", required=True)
    parser.add_argument("--b", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    a_root, b_root, out = Path(args.a).resolve(strict=True), Path(args.b).resolve(strict=True), Path(args.out_dir)
    if out.exists():
        sys.exit(f"--out-dir already exists: {out}")
    a, b = inventory(a_root), inventory(b_root)
    rows = {"identical": [], "signature-only": [], "different": [], "only-in-A": sorted(set(a) - set(b)),
            "only-in-B": sorted(set(b) - set(a)), "volatile-listed-apart": []}
    for rel in sorted(set(a) & set(b)):
        if volatile(rel):
            rows["volatile-listed-apart"].append(rel)
            continue
        if sha(a[rel]) == sha(b[rel]):
            rows["identical"].append(rel)
        elif is_macho(a[rel]) and is_macho(b[rel]) and stripped_sha(a[rel]) == stripped_sha(b[rel]):
            rows["signature-only"].append(rel)
        else:
            entry = {"path": rel}
            if is_macho(a[rel]) and is_macho(b[rel]):
                entry["uuidA"], entry["uuidB"] = uuids(a[rel]), uuids(b[rel])
            rows["different"].append(entry)
    report = {"formatVersion": 1, "a": str(a_root), "b": str(b_root),
              "counts": {k: len(v) for k, v in rows.items()}, "files": rows,
              "note": "Signature-only differences are expected for signed builds only when the signing time or "
                      "identity differs. Different content in a Mach-O file is a reproducibility failure to explain."}
    out.mkdir(parents=True)
    (out / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report["counts"]), "->", out)
    return 1 if rows["different"] or rows["only-in-A"] or rows["only-in-B"] else 0


if __name__ == "__main__":
    sys.exit(main())
