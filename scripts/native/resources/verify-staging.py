#!/usr/bin/env python3
"""Compare two staging runs and write stable L03 handoff evidence."""
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "build/native-evidence/L03"
EDITIONS = ("web-ce", "douay-rheims", "vulgate")
ROTATION_BASENAMES = {f"{edition}.{suffix}" for edition in EDITIONS for suffix in ("dat", "offsets", "ot", "nt", "meta.json")}


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def verify_rotation(run: Path) -> None:
    rotation_files = {path.name for path in (run / "App/Rotation").iterdir() if path.is_file()}
    if rotation_files != ROTATION_BASENAMES:
        raise RuntimeError(f"app rotation target must contain the 15 indexed corpus files only: {sorted(rotation_files ^ ROTATION_BASENAMES)}")
    for edition in EDITIONS:
        source_path = ROOT / "src/services/bible/data" / edition / "widgetVerses.json"
        source = json.loads(source_path.read_text())["verses"]
        expected_ot = [i for i, verse in enumerate(source) if verse["group"] != "nt"]
        expected_nt = [i for i, verse in enumerate(source) if verse["group"] == "nt"]
        if not expected_ot or not expected_nt:
            raise RuntimeError(f"empty indexed testament map: {edition}")
        for target in ("App/Rotation", "Widget"):
            base = run / target
            dat = (base / f"{edition}.dat").read_bytes()
            offset_bytes = (base / f"{edition}.offsets").read_bytes()
            ot_bytes = (base / f"{edition}.ot").read_bytes()
            nt_bytes = (base / f"{edition}.nt").read_bytes()
            metadata = json.loads((base / f"{edition}.meta.json").read_text())
            if len(offset_bytes) != 4 * (len(source) + 1):
                raise RuntimeError(f"offset count mismatch: {target}/{edition}")
            offsets = [item[0] for item in struct.iter_unpack("<I", offset_bytes)]
            if offsets[0] != 0 or offsets[-1] != len(dat):
                raise RuntimeError(f"offset endpoints mismatch: {target}/{edition}")
            if any(start >= end or end > len(dat) for start, end in zip(offsets, offsets[1:])):
                raise RuntimeError(f"offset bounds or order error: {target}/{edition}")
            if len(ot_bytes) % 4 or len(nt_bytes) % 4:
                raise RuntimeError(f"testament index byte length is invalid: {target}/{edition}")
            ot = [item[0] for item in struct.iter_unpack("<I", ot_bytes)]
            nt = [item[0] for item in struct.iter_unpack("<I", nt_bytes)]
            if ot != expected_ot or nt != expected_nt:
                raise RuntimeError(f"OT/NT map mismatch: {target}/{edition}")
            if metadata != {"formatVersion": 1, "counts": {"full": len(source), "ot": len(expected_ot), "nt": len(expected_nt)}}:
                raise RuntimeError(f"metadata counts mismatch: {target}/{edition}")
            for index, verse in enumerate(source):
                start, end = offsets[index], offsets[index + 1]
                record_bytes = dat[start:end]
                if not record_bytes.endswith(b"\n"):
                    raise RuntimeError(f"record delimiter mismatch: {target}/{edition}/{index}")
                record = json.loads(record_bytes)
                expected = [verse["ref"], verse["book"], verse["chapter"], verse["verse"], verse["text"]]
                if not isinstance(record, list) or len(record) != 5 or record != expected:
                    raise RuntimeError(f"indexed source field mismatch: {target}/{edition}/{index}")
    for edition in EDITIONS:
        if (run / "App/Bible" / edition / "widgetVerses.json").exists() or (run / "Widget" / f"{edition}.json").exists():
            raise RuntimeError(f"full rotation JSON pool is staged: {edition}")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify-staging.py <run-1> <run-2>")
    paths = [(ROOT / item).resolve() for item in sys.argv[1:]]
    base = (EVIDENCE / "staged").resolve()
    if any(path == base or not path.is_relative_to(base) for path in paths):
        raise RuntimeError("both inputs must be output directories below build/native-evidence/L03/staged")
    left, right = paths
    if left == right:
        raise RuntimeError("staging inputs must be two different directories")
    for run in (left, right):
        manifest = json.loads((run / "manifest.json").read_text())
        for source_path, expected_hash in manifest["sourceProvenance"].items():
            source = (ROOT / source_path).resolve()
            if not source.is_relative_to(ROOT) or not source.is_file() or digest(source) != expected_hash:
                raise RuntimeError(f"source provenance hash mismatch: {source_path}")
        declared = {row["path"]: row["sha256"] for row in manifest["files"]}
        if len(declared) != len(manifest["files"]):
            raise RuntimeError(f"duplicate resource path in manifest: {run}")
        for rel_path, expected_hash in declared.items():
            candidate = (run / rel_path).resolve()
            if not candidate.is_relative_to(run) or not candidate.is_file():
                raise RuntimeError(f"missing or invalid staged resource: {rel_path}")
            if digest(candidate) != expected_hash:
                raise RuntimeError(f"staged resource hash mismatch: {rel_path}")
        for row in manifest["files"]:
            source_label = row["sourcePath"]
            source_path = (ROOT / source_label).resolve()
            if source_path.is_file():
                if not source_path.is_relative_to(ROOT) or digest(source_path) != row["sha256"]:
                    raise RuntimeError(f"copied source hash mismatch: {source_label}")
            elif " + " not in source_label:
                raise RuntimeError(f"copied source path cannot be resolved: {source_label}")
        expected_files = set(declared) | {"manifest.json", "app-target-files.json", "widget-target-files.json"}
        actual_files = {p.relative_to(run).as_posix() for p in run.rglob("*") if p.is_file()}
        if actual_files != expected_files:
            raise RuntimeError(f"unexpected or missing staging output files in {run}: {sorted(actual_files ^ expected_files)}")
        verify_rotation(run)
    left_files = {p.relative_to(left).as_posix(): digest(p) for p in left.rglob("*") if p.is_file()}
    right_files = {p.relative_to(right).as_posix(): digest(p) for p in right.rglob("*") if p.is_file()}
    if left_files != right_files:
        missing = sorted(set(left_files) ^ set(right_files))
        changed = sorted(path for path in left_files.keys() & right_files.keys() if left_files[path] != right_files[path])
        raise RuntimeError(f"staging runs differ; missing={missing}; changed={changed}")
    manifest_path = left / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    if digest(manifest_path) != digest(right / "manifest.json"):
        raise RuntimeError("staging manifests differ")
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    for name in ("manifest.json", "app-target-files.json", "widget-target-files.json"):
        (EVIDENCE / name).write_bytes((left / name).read_bytes())
    (EVIDENCE / "input-provenance.json").write_text(json.dumps({
        "sourceProvenance": manifest["sourceProvenance"],
        "files": [{"sourcePath": row["sourcePath"], "target": row["target"], "bytes": row["bytes"], "sha256": row["sha256"]}
                  for row in manifest["files"]],
    }, indent=2, ensure_ascii=False) + "\n")
    result = {
        "command": f"python3 scripts/native/resources/stage-resources.py {paths[0].relative_to(ROOT).as_posix()} && python3 scripts/native/resources/stage-resources.py {paths[1].relative_to(ROOT).as_posix()} && python3 scripts/native/resources/verify-staging.py {paths[0].relative_to(ROOT).as_posix()} {paths[1].relative_to(ROOT).as_posix()}",
        "comparison": "pass",
        "identicalFileCountPerRun": len(left_files),
        "comparedFileCountAcrossRuns": len(left_files),
        "allOutputFilesMatch": True,
        "manifestSha256": digest(manifest_path),
        "resourceCount": len(manifest["files"]),
        "targetBytes": {target: sum(row["bytes"] for row in manifest["files"] if row["target"] == target)
                        for target in ("app", "widget")},
        "requiredContentCounts": manifest["requiredContentCounts"],
        "targetCounts": {"app": len(json.loads((left / "app-target-files.json").read_text())),
                         "widget": len(json.loads((left / "widget-target-files.json").read_text()))},
    }
    (EVIDENCE / "results.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
