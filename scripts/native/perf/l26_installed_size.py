#!/usr/bin/env python3
"""L26 installed-size report. Source only. Read only. Writes one JSON file to a new path.

Reports app bundle bytes, extension bytes, the largest top-level folders, duplicate file content,
and optional container sizes. A simulator build is not an App Store archive or a thinned install.
Do not use these numbers as archive size or as a physical-device limit.

Usage: l26_installed_size.py --app /path/John.app --out NEW.json [--data-dir DIR] [--group-dir DIR]
  --data-dir / --group-dir: app data container and App Group container (from `simctl get_app_container`).
"""
import argparse
import hashlib
import json
import os
import sys
from collections import defaultdict
from pathlib import Path


def tree_bytes(path):
    total = files = 0
    for root, _dirs, names in os.walk(path):
        for name in names:
            full = os.path.join(root, name)
            if os.path.islink(full):
                continue
            total += os.lstat(full).st_size
            files += 1
    return total, files


def sha(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def top_level(path):
    rows = []
    for child in sorted(Path(path).iterdir()):
        size, count = tree_bytes(child) if child.is_dir() else (child.lstat().st_size, 1)
        rows.append({"name": child.name, "bytes": size, "files": count})
    return sorted(rows, key=lambda row: -row["bytes"])


def duplicates(app):
    """Files with identical content at different paths. Reports only files of at least 64 KiB."""
    by_size = defaultdict(list)
    for root, _dirs, names in os.walk(app):
        for name in names:
            full = os.path.join(root, name)
            if os.path.islink(full):
                continue
            size = os.lstat(full).st_size
            if size >= 65536:
                by_size[size].append(full)
    groups = []
    for size, paths in by_size.items():
        if len(paths) < 2:
            continue
        by_hash = defaultdict(list)
        for path in paths:
            by_hash[sha(path)].append(os.path.relpath(path, app))
        for digest, same in by_hash.items():
            if len(same) > 1:
                groups.append({"sha256": digest, "bytesEach": size, "paths": sorted(same),
                               "wastedBytes": size * (len(same) - 1)})
    return sorted(groups, key=lambda group: -group["wastedBytes"])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--app", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--data-dir")
    parser.add_argument("--group-dir")
    args = parser.parse_args()
    app = Path(args.app).resolve(strict=True)
    out = Path(args.out)
    if app.suffix != ".app" or not app.is_dir():
        sys.exit("--app must be a .app directory")
    if out.exists():
        sys.exit(f"output file already exists: {out}")
    app_total, app_files = tree_bytes(app)
    report = {"formatVersion": 1, "app": str(app), "appBundleBytes": app_total, "appBundleFiles": app_files,
              "appTopLevel": top_level(app), "extensions": [], "duplicateContent": duplicates(app)}
    for appex in sorted(app.glob("PlugIns/*.appex")):
        size, count = tree_bytes(appex)
        report["extensions"].append({"name": appex.name, "bytes": size, "files": count, "topLevel": top_level(appex)})
    report["appBytesWithoutExtensions"] = app_total - sum(row["bytes"] for row in report["extensions"])
    report["duplicateWastedBytes"] = sum(group["wastedBytes"] for group in report["duplicateContent"])
    for key, value in (("appDataContainer", args.data_dir), ("appGroupContainer", args.group_dir)):
        if value:
            size, count = tree_bytes(value)
            report[key] = {"bytes": size, "files": count, "topLevel": top_level(value)}
    report["limits"] = ["Simulator build: not an archive and not a thinned device install.",
                        "Container sizes depend on the actions run before the copy.",
                        "Keep these values separate. Do not add them to one number."]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(f"app bundle {app_total} bytes; extensions {len(report['extensions'])}; "
          f"duplicate waste {report['duplicateWastedBytes']} bytes; wrote {out}")


if __name__ == "__main__":
    main()
