#!/usr/bin/env python3
"""Copy one newly-created Scripture card PNG while the native share panel is open."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import time
from datetime import datetime, timezone

PATTERN_PREFIX = "john-scripture-card-"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Not a valid PNG header: {path.name}")
    return struct.unpack(">II", header[16:24])


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True, type=Path,
                        help="App-owned temporary directory that contains the exported PNG")
    parser.add_argument("--evidence-dir", required=True, type=Path,
                        help="New output directory for this one capture")
    parser.add_argument("--label", required=True, choices=("ivory", "plum", "plum-repeat"))
    parser.add_argument("--timeout-seconds", type=float, default=40.0)
    parser.add_argument("--stable-interval-seconds", type=float, default=0.5)
    args = parser.parse_args()

    source_dir = args.source_dir.expanduser().resolve(strict=True)
    evidence_dir = args.evidence_dir.expanduser().resolve(strict=False)
    if not source_dir.is_dir():
        raise SystemExit("source-dir must be a directory")
    if is_within(evidence_dir, source_dir) or is_within(source_dir, evidence_dir):
        raise SystemExit("source-dir and evidence-dir must not overlap")
    if evidence_dir.exists():
        raise SystemExit("evidence-dir must be a new path")
    if args.timeout_seconds <= 0 or args.stable_interval_seconds <= 0:
        raise SystemExit("timeout and stable interval must be positive")

    baseline = {
        path.name for path in source_dir.glob(f"{PATTERN_PREFIX}*.png")
        if path.is_file()
    }
    print(json.dumps({
        "event": "READY",
        "label": args.label,
        "baselineCount": len(baseline),
        "timeoutSeconds": args.timeout_seconds,
    }, sort_keys=True), flush=True)
    deadline = time.monotonic() + args.timeout_seconds
    candidate: Path | None = None
    last_size: int | None = None
    stable_reads = 0
    while time.monotonic() < deadline:
        created = sorted(
            (path for path in source_dir.glob(f"{PATTERN_PREFIX}*.png")
             if path.is_file() and path.name not in baseline),
            key=lambda path: path.stat().st_mtime_ns,
        )
        if created:
            current = created[-1]
            size = current.stat().st_size
            if current == candidate and size == last_size and size > 0:
                stable_reads += 1
            else:
                candidate = current
                last_size = size
                stable_reads = 0
            if stable_reads >= 3:
                break
        time.sleep(args.stable_interval_seconds)
    else:
        raise SystemExit("Timed out waiting for one new stable Scripture card PNG")

    if candidate is None:
        raise SystemExit("No new Scripture card PNG was found")
    before_hash = sha256(candidate)
    before_stat = candidate.stat()
    width, height = png_dimensions(candidate)
    evidence_dir.mkdir(parents=True, exist_ok=False)
    destination = evidence_dir / f"scripture-card-{args.label}.png"
    shutil.copyfile(candidate, destination)
    copied_hash = sha256(destination)
    after_stat = candidate.stat()
    after_hash = sha256(candidate)
    if before_hash != copied_hash or before_hash != after_hash:
        destination.unlink(missing_ok=True)
        raise SystemExit("Source changed during capture or copied bytes do not match")
    if before_stat.st_size != after_stat.st_size or before_stat.st_mtime_ns != after_stat.st_mtime_ns:
        destination.unlink(missing_ok=True)
        raise SystemExit("Source changed during capture")

    manifest = {
        "schemaVersion": 1,
        "label": args.label,
        "sourceFilename": candidate.name,
        "sourceBaselineContainedFilename": False,
        "sha256": before_hash,
        "copiedSha256": copied_hash,
        "sizeBytes": before_stat.st_size,
        "widthPixels": width,
        "heightPixels": height,
        "capturedAtUTC": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    (evidence_dir / "capture.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
