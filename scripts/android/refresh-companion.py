#!/usr/bin/env python3
"""Explicitly compare or refresh the reviewed Android companion catalog."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
EXPORTER = ROOT / "scripts/native/resources/export-catalogs.ts"
CONTENT = ROOT / "native/Android/content"


def source_records() -> list[dict]:
    """Include relative imports and type imports in the provenance record."""
    pending = [EXPORTER]
    visited = set()
    records = []
    while pending:
        source = pending.pop().resolve()
        if source in visited:
            continue
        visited.add(source)
        relative = source.relative_to(ROOT).as_posix()
        data = source.read_bytes()
        head = subprocess.run(["git", "show", f"HEAD:{relative}"], cwd=ROOT, capture_output=True)
        records.append({"path": relative, "sha256": hashlib.sha256(data).hexdigest(),
                        "headSha256": hashlib.sha256(head.stdout).hexdigest() if head.returncode == 0 else None,
                        "modifiedAgainstHead": head.returncode != 0 or head.stdout != data})
        for dependency in re.findall(r"\bfrom\s+[\"'](\.[^\"']+)[\"']", data.decode()):
            base = source.parent / dependency
            candidates = [base, Path(str(base) + ".ts"), base / "index.ts"]
            target = next((candidate for candidate in candidates if candidate.is_file()), None)
            if target is None:
                raise ValueError(f"Cannot resolve {dependency} from {relative}")
            pending.append(target)
    return sorted(records, key=lambda record: record["path"])


def provenance(data: bytes, records: list[dict]) -> dict:
    catalog = json.loads(data)
    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    return {
        "formatVersion": 1,
        "capturedAtUtc": datetime.now(timezone.utc).isoformat(),
        "repositoryHead": revision,
        "sourceState": "working-tree",
        "purpose": "Reviewed Android release snapshot. Source hashes record provenance; staging does not require the working tree to match them.",
        "exporter": "scripts/native/resources/export-catalogs.ts",
        "catalog": {"path": "native/Android/content/companion.json", "bytes": len(data),
                    "sha256": hashlib.sha256(data).hexdigest(),
                    "counts": {name: len(catalog[name]) for name in ("novenas", "prayers", "teachings")}},
        "sourceFiles": records,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="Compare current shared sources with the pinned input without changing it")
    mode.add_argument("--write", action="store_true", help="Replace the Android input and provenance; review the resulting diff before release")
    args = parser.parse_args()
    records = source_records()
    with tempfile.TemporaryDirectory(prefix="john-companion-") as temporary:
        output = Path(temporary) / "companion.json"
        subprocess.run([str(ROOT / "node_modules/.bin/tsx"), str(EXPORTER), str(output)], cwd=ROOT, check=True)
        data = output.read_bytes()
    if records != source_records():
        raise RuntimeError("Shared source files changed during export; retry after edits finish")
    catalog = CONTENT / "companion.json"
    if args.check:
        if data != catalog.read_bytes():
            raise SystemExit("Shared source output differs from the pinned Android catalog. Review changes before running --write.")
        print(f"Pinned companion catalog matches shared sources: {hashlib.sha256(data).hexdigest()}")
        return
    CONTENT.mkdir(parents=True, exist_ok=True)
    catalog.write_bytes(data)
    (CONTENT / "companion-provenance.json").write_text(json.dumps(provenance(data, records), indent=2) + "\n")
    print(f"Updated Android companion catalog: {hashlib.sha256(data).hexdigest()}. Review both content files and run asset checks.")


if __name__ == "__main__":
    main()
