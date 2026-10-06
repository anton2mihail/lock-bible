#!/usr/bin/env python3
"""Step 7 Rosary media package check. Read only. No simulator.

Compares the Rosary media catalog inside a built John.app with the old source catalog
(src/services/rosary/catalog.ts:190 ROSARY_MEDIA_EPISODES). It also searches the app binaries and the bundled
catalog for the two Debug sample URLs. Use it on a Release app and on a Debug app.

Usage: check_media_package.py --app /path/to/John.app [--evidence-dir NEW_DIR]
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
SAMPLE_URLS = [b"commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
               b"www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_episodes():
    code = ('import {ROSARY_MEDIA_EPISODES} from "./src/services/rosary/catalog"; '
            'console.log(JSON.stringify(ROSARY_MEDIA_EPISODES))')
    result = subprocess.run(["bun", "-e", code], cwd=REPO, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit("bun failed: " + result.stderr)
    return json.loads(result.stdout.strip().splitlines()[-1])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", required=True)
    parser.add_argument("--evidence-dir")
    args = parser.parse_args()
    app = Path(args.app)
    info = json.loads(subprocess.run(["plutil", "-convert", "json", "-o", "-", str(app / "Info.plist")],
                                     capture_output=True, text=True, check=True).stdout)
    catalog_path = app / "App/Catalogs/devotional-catalogs.json"
    rosary = json.loads(catalog_path.read_text())["rosary"]
    bundled = rosary["mediaEpisodes"]
    source = source_episodes()
    rows, problems = [], []
    if [e["id"] for e in bundled] != [e["id"] for e in source]:
        problems.append("episode ids or order differ")
    for src, got in zip(source, bundled):
        row = {"id": src["id"], "sourceOfficialUrl": src["officialUrl"], "bundledOfficialUrl": got.get("officialUrl"),
               "urlMatches": src["officialUrl"] == got.get("officialUrl"),
               "titleMatches": src["title"] == got.get("title"), "subtitleMatches": src["subtitle"] == got.get("subtitle"),
               "mysterySetMatches": src.get("mysterySetId") == got.get("mysterySetId"),
               "hasVideoUri": bool(got.get("videoUri")), "hasAudioUri": bool(got.get("audioUri"))}
        rows.append(row)
        if not (row["urlMatches"] and row["titleMatches"] and row["subtitleMatches"] and row["mysterySetMatches"]):
            problems.append("episode differs: " + src["id"])
        if row["hasVideoUri"] or row["hasAudioUri"]:
            problems.append("approved direct media URI present: " + src["id"])
    approved = {e["id"]: e["approved"] for e in rosary.get("mediaApproved", [])}
    if any(approved.values()):
        problems.append("a catalog entry is marked approved")
    scan = {}
    targets = [p for p in [app / info.get("CFBundleExecutable", "John"), app / "John.debug.dylib", app / "__preview.dylib"] if p.exists()]
    targets += [p for p in (app / "PlugIns").glob("*.appex/*") if p.is_file() and p.suffix in ("", ".dylib")]
    targets += [catalog_path]
    for path in targets:
        data = path.read_bytes()
        scan[str(path.relative_to(app))] = {url.decode(): (url in data) for url in SAMPLE_URLS}
    report = {"app": str(app), "bundleId": info.get("CFBundleIdentifier"), "version": info.get("CFBundleShortVersionString"),
              "build": info.get("CFBundleVersion"), "catalogSha256": sha(catalog_path), "episodes": rows,
              "sampleUrlScan": scan, "problems": problems,
              "note": "A missing sample URL string is package evidence. It does not prove that no sample player exists."}
    print(json.dumps(report, indent=2))
    if args.evidence_dir:
        out = Path(args.evidence_dir)
        out.mkdir(parents=True)
        (out / "media-package-report.json").write_text(json.dumps(report, indent=2) + "\n")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
