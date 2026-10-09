#!/usr/bin/env python3
"""Copy each new Scripture card PNG from one simulator app container."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import struct

PREFIX = "john-scripture-card-"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
MAX_TIMEOUT_SECONDS = 600.0


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def resolve_data_container(udid: str, bundle_id: str) -> Path | None:
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "get_app_container", udid, bundle_id, "data"],
            check=False,
            capture_output=True,
            text=True,
            timeout=4,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    value = result.stdout.strip()
    if not value:
        return None
    try:
        path = Path(value).expanduser().resolve(strict=True)
    except OSError:
        return None
    return path if path.is_dir() else None


def source_signature(path: Path) -> tuple[int, int] | None:
    try:
        stat = path.stat()
    except OSError:
        return None
    if not path.is_file() or stat.st_size <= 0:
        return None
    return stat.st_size, stat.st_mtime_ns


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def png_dimensions(data: bytes, filename: str) -> tuple[int, int]:
    if len(data) < 24 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        raise ValueError(f"Invalid PNG header: {filename}")
    width, height = struct.unpack(">II", data[16:24])
    if width <= 0 or height <= 0:
        raise ValueError(f"Invalid PNG dimensions: {filename}")
    return width, height


def write_manifest(path: Path, payload: dict[str, object]) -> None:
    temporary = path.with_suffix(".json.tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        json.dump(payload, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def copy_stable_png(source: Path, destination: Path) -> dict[str, object]:
    before = source.stat()
    data = source.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    width, height = png_dimensions(data, source.name)
    after = source.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise RuntimeError(f"Source changed while being copied: {source.name}")

    temporary = destination.with_suffix(destination.suffix + ".tmp")
    with temporary.open("xb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    copied_digest = hashlib.sha256(temporary.read_bytes()).hexdigest()
    if copied_digest != digest:
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"Copied bytes do not match source: {source.name}")
    temporary.replace(destination)
    return {
        "sourceFilename": source.name,
        "sha256": digest,
        "copiedSha256": copied_digest,
        "sizeBytes": len(data),
        "widthPixels": width,
        "heightPixels": height,
        "sourceModifiedUTC": datetime.fromtimestamp(before.st_mtime, timezone.utc).isoformat(timespec="seconds"),
        "capturedAtUTC": utc_now(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--udid", required=True, help="Exact simulator UDID")
    parser.add_argument("--bundle-id", required=True, help="Task-only app bundle ID")
    parser.add_argument("--evidence-dir", required=True, type=Path,
                        help="New output directory for all captures and the manifest")
    parser.add_argument("--labels", nargs="+", default=["ivory", "plum", "plum-repeat"],
                        help="Capture labels in the order that the UI test exports them")
    parser.add_argument("--timeout-seconds", type=float, default=300.0,
                        help=f"Maximum run time (1 to {int(MAX_TIMEOUT_SECONDS)} seconds)")
    parser.add_argument("--poll-interval-seconds", type=float, default=0.2,
                        help="Interval for container and file checks")
    parser.add_argument("--stable-polls", type=int, default=3,
                        help="Equal file size and modification time polls before copy")
    args = parser.parse_args()

    if not args.udid.strip() or not args.bundle_id.strip():
        parser.error("udid and bundle-id must not be empty")
    if not args.labels or any(not label.strip() for label in args.labels):
        parser.error("at least one non-empty label is required")
    if any(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", label) is None for label in args.labels):
        parser.error("labels may contain only letters, numbers, underscore, and hyphen")
    if len(set(args.labels)) != len(args.labels):
        parser.error("labels must be unique")
    if not 0 < args.timeout_seconds <= MAX_TIMEOUT_SECONDS:
        parser.error(f"timeout-seconds must be between 0 and {int(MAX_TIMEOUT_SECONDS)}")
    if not 0.05 <= args.poll_interval_seconds <= 2:
        parser.error("poll-interval-seconds must be between 0.05 and 2")
    if not 2 <= args.stable_polls <= 10:
        parser.error("stable-polls must be between 2 and 10")

    evidence_dir = args.evidence_dir.expanduser().resolve(strict=False)
    if evidence_dir.exists():
        parser.error("evidence-dir must be a new path")
    evidence_dir.mkdir(parents=True, exist_ok=False)
    manifest_path = evidence_dir / "capture-manifest.json"
    manifest: dict[str, object] = {
        "schemaVersion": 1,
        "bundleID": args.bundle_id,
        "simulatorUDID": args.udid,
        "startedAtUTC": utc_now(),
        "expectedLabels": args.labels,
        "captures": [],
        "status": "waiting-for-container",
    }
    write_manifest(manifest_path, manifest)

    print(json.dumps({"event": "ARMED", "labels": args.labels,
                      "timeoutSeconds": args.timeout_seconds}, sort_keys=True), flush=True)

    deadline = time.monotonic() + args.timeout_seconds
    container: Path | None = None
    baseline: dict[str, tuple[int, int]] = {}
    candidates: dict[str, tuple[int, int, int]] = {}
    captured_keys: set[tuple[str, str, int, int]] = set()
    next_label = 0
    last_wait_report = 0.0

    try:
        while time.monotonic() < deadline and next_label < len(args.labels):
            resolved = resolve_data_container(args.udid, args.bundle_id)
            if resolved is None:
                if container is not None and not container.exists():
                    print(json.dumps({"event": "CONTAINER_LOST", "retrying": True}, sort_keys=True), flush=True)
                    container = None
                    baseline = {}
                    candidates = {}
                now = time.monotonic()
                if now - last_wait_report >= 5:
                    print(json.dumps({"event": "WAITING_FOR_APP_CONTAINER", "retrying": True}, sort_keys=True), flush=True)
                    last_wait_report = now
                time.sleep(args.poll_interval_seconds)
                continue

            changed_container = container is not None and resolved != container
            first_container = container is None
            if first_container or changed_container:
                container = resolved
                if is_within(evidence_dir, container) or is_within(container, evidence_dir):
                    print(json.dumps({"event": "ERROR", "reason": "evidence and app container paths overlap"},
                                     sort_keys=True), flush=True)
                    manifest["status"] = "error"
                    manifest["updatedAtUTC"] = utc_now()
                    write_manifest(manifest_path, manifest)
                    return 2
                source_dir = container / "tmp"
                existing = {}
                if source_dir.is_dir():
                    for path in source_dir.glob(f"{PREFIX}*.png"):
                        signature = source_signature(path)
                        if signature is not None:
                            existing[path.name] = signature
                # A new container after reinstall has no prior watcher baseline.
                # Treat its existing card files as new so an early export is not lost.
                if first_container:
                    baseline = existing
                else:
                    baseline = {}
                candidates = {}
                print(json.dumps({
                    "event": "CONTAINER_READY" if first_container else "CONTAINER_CHANGED",
                    "baselineCount": len(baseline),
                    "retryingOnReinstall": True,
                }, sort_keys=True), flush=True)
                if first_container:
                    manifest["status"] = "watching"
                    write_manifest(manifest_path, manifest)

            source_dir = container / "tmp"
            if source_dir.is_dir():
                for path in sorted(source_dir.glob(f"{PREFIX}*.png"), key=lambda item: item.name):
                    signature = source_signature(path)
                    if signature is None:
                        continue
                    if baseline.get(path.name) == signature:
                        continue
                    key = (str(container), path.name, signature[0], signature[1])
                    if key in captured_keys:
                        continue
                    previous = candidates.get(path.name)
                    if previous is not None and previous[:2] == signature:
                        stable_count = previous[2] + 1
                    else:
                        stable_count = 1
                    candidates[path.name] = (signature[0], signature[1], stable_count)
                    if stable_count < args.stable_polls:
                        continue

                    label = args.labels[next_label]
                    destination = evidence_dir / f"scripture-card-{label}.png"
                    try:
                        details = copy_stable_png(path, destination)
                    except (OSError, ValueError, RuntimeError) as error:
                        print(json.dumps({"event": "COPY_RETRY", "label": label,
                                          "reason": str(error)}, sort_keys=True), flush=True)
                        candidates.pop(path.name, None)
                        continue

                    capture = {"label": label, **details}
                    captures = manifest["captures"]
                    assert isinstance(captures, list)
                    captures.append(capture)
                    manifest["status"] = "complete" if next_label + 1 == len(args.labels) else "watching"
                    manifest["updatedAtUTC"] = utc_now()
                    write_manifest(manifest_path, manifest)
                    captured_keys.add(key)
                    next_label += 1
                    candidates.pop(path.name, None)
                    print(json.dumps({"event": "CAPTURED", **capture}, sort_keys=True), flush=True)
                    if next_label >= len(args.labels):
                        break

            time.sleep(args.poll_interval_seconds)

        if next_label < len(args.labels):
            manifest["status"] = "timeout"
            manifest["updatedAtUTC"] = utc_now()
            write_manifest(manifest_path, manifest)
            print(json.dumps({"event": "TIMEOUT", "capturedCount": next_label,
                              "expectedCount": len(args.labels)}, sort_keys=True), flush=True)
            return 2
        manifest["finishedAtUTC"] = utc_now()
        write_manifest(manifest_path, manifest)
        print(json.dumps({"event": "DONE", "capturedCount": next_label,
                          "manifest": str(manifest_path)}, sort_keys=True), flush=True)
        return 0
    except KeyboardInterrupt:
        manifest["status"] = "interrupted"
        manifest["updatedAtUTC"] = utc_now()
        write_manifest(manifest_path, manifest)
        print(json.dumps({"event": "INTERRUPTED", "capturedCount": next_label}, sort_keys=True), flush=True)
        return 130


if __name__ == "__main__":
    sys.exit(main())
