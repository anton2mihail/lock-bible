#!/usr/bin/env python3
"""L28 App Store screenshot check. Source only. Read only.

Checks each image: format (png, jpg, jpeg), pixel size against the accepted sizes, and no alpha channel.
It groups images by device class and checks 1 to 10 images for each class that you name.
The size table comes from Apple's "Screenshot specifications" page (read 6 October 2026).
App Store Connect can change these values. Confirm them in the App Store Connect upload page before submission.

Usage: l28_check_screenshots.py --iphone DIR_OR_FILE... --ipad DIR_OR_FILE... [--out report.json]
Exit code 0 = all checks pass.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

IPHONE = {  # class -> portrait sizes
    "iPhone 6.9in class (Dynamic Island, large)": {(1260, 2736), (1290, 2796), (1320, 2868)},
    "iPhone 6.5in class (Face ID, large)": {(1284, 2778), (1242, 2688)},
    "iPhone 6.3in class (Dynamic Island, medium)": {(1179, 2556), (1206, 2622)},
    "iPhone 6.1in class (Face ID, medium)": {(1170, 2532), (1125, 2436), (1080, 2340)},
}
IPAD = {
    "iPad 13in class": {(2064, 2752), (2048, 2732)},
    "iPad 11in class": {(1488, 2266), (1668, 2420), (1668, 2388), (1640, 2360)},
}


def classify(size, table):
    w, h = size
    for name, sizes in table.items():
        if (w, h) in sizes or (h, w) in sizes:
            return name
    return None


def collect(paths):
    files = []
    for item in paths:
        p = Path(item)
        files += sorted(x for x in p.rglob("*") if x.is_file()) if p.is_dir() else [p]
    return [f for f in files if f.suffix.lower() in (".png", ".jpg", ".jpeg")]


def check(files, table):
    rows, counts = [], {}
    for f in files:
        with Image.open(f) as image:
            alpha = image.mode in ("RGBA", "LA", "PA") or "transparency" in image.info
            cls = classify(image.size, table)
            rows.append({"file": str(f), "size": image.size, "format": image.format, "class": cls, "alpha": alpha,
                         "ok": cls is not None and not alpha})
            counts[cls] = counts.get(cls, 0) + 1
    problems = [f"{r['file']}: " + ("unaccepted size " + str(r["size"]) if r["class"] is None else "has alpha")
                for r in rows if not r["ok"]]
    problems += [f"class {k}: {v} images (limit 1 to 10)" for k, v in counts.items() if k and not 1 <= v <= 10]
    return rows, counts, problems


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--iphone", nargs="+", default=[])
    parser.add_argument("--ipad", nargs="+", default=[])
    parser.add_argument("--out")
    args = parser.parse_args()
    report, problems = {}, []
    for label, paths, table in (("iphone", args.iphone, IPHONE), ("ipad", args.ipad, IPAD)):
        if not paths:
            continue
        rows, counts, probs = check(collect(paths), table)
        report[label] = {"images": rows, "countsByClass": counts}
        problems += probs
        print(label, {str(k): v for k, v in counts.items()})
    report["problems"] = problems
    for p in problems:
        print("PROBLEM:", p)
    if args.out:
        out = Path(args.out)
        if out.exists():
            sys.exit(f"output exists: {out}")
        out.write_text(json.dumps(report, indent=2) + "\n")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
