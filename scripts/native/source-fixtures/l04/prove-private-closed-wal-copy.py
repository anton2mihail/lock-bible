#!/usr/bin/env python3
"""Prove private normalization of a complete, closed SQLite WAL database."""

from __future__ import annotations

from hashlib import sha256
from pathlib import Path
import json
import shutil
import sqlite3
import sys


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def row_counts(connection: sqlite3.Connection) -> dict[str, int]:
    return {
        name: int(connection.execute(f"SELECT count(*) FROM {name}").fetchone()[0])
        for name in ("bookmarks", "highlights", "notes")
    }


def validate(connection: sqlite3.Connection) -> dict[str, object]:
    version = int(connection.execute("PRAGMA user_version").fetchone()[0])
    integrity = str(connection.execute("PRAGMA integrity_check").fetchone()[0])
    counts = row_counts(connection)
    if version != 1 or integrity != "ok" or counts != {"bookmarks": 2, "highlights": 1, "notes": 1}:
        raise RuntimeError(f"database validation failed: version={version}, integrity={integrity}, counts={counts}")
    return {"userVersion": version, "integrity": integrity, "rowCounts": counts}


def files_hashes(folder: Path) -> dict[str, str]:
    return {path.name: digest(path) for path in sorted(folder.iterdir()) if path.is_file()}


def require_new(path: Path) -> None:
    if path.exists():
        raise RuntimeError(f"output already exists: {path}")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: prove-private-closed-wal-copy.py <fixture-root> <new-output-dir>")
    fixture = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    require_new(output)
    source = fixture / "input/library"
    source_db = source / "user-library.db"
    if not source_db.is_file():
        raise RuntimeError(f"missing source database: {source_db}")
    source_files = [source_db, *[Path(f"{source_db}{suffix}") for suffix in ("-wal", "-shm", "-journal") if Path(f"{source_db}{suffix}").is_file()]]
    source_before = {path.name: digest(path) for path in source_files}

    output.mkdir(parents=True)
    closed_dir = output / "closed-source"
    closed_dir.mkdir()
    closed_db = closed_dir / "user-library.db"
    for path in source_files:
        shutil.copyfile(path, closed_dir / path.name)
    copied_hashes = files_hashes(closed_dir)
    if copied_hashes != source_before:
        raise RuntimeError("initial closed-source copy hashes do not match the fixture")

    writer = sqlite3.connect(closed_db, timeout=2.0)
    initial = validate(writer)
    checkpoint = tuple(int(value) for value in writer.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone())
    if len(checkpoint) != 3 or checkpoint[0] != 0 or checkpoint[1] != checkpoint[2]:
        writer.close()
        raise RuntimeError(f"closed-source checkpoint failed: {checkpoint}")
    writer.close()

    sidecars = {suffix: Path(f"{closed_db}{suffix}") for suffix in ("-wal", "-shm", "-journal")}
    if sidecars["-wal"].exists():
        if sidecars["-wal"].stat().st_size != 0:
            raise RuntimeError("closed source has non-empty WAL after checkpoint and close")
        sidecars["-wal"].unlink()
    if sidecars["-journal"].exists():
        raise RuntimeError("closed source has a rollback journal")
    if sidecars["-shm"].exists():
        sidecars["-shm"].unlink()
    if any(path.exists() for path in sidecars.values()):
        raise RuntimeError("closed source still has SQLite sidecars")
    closed_header = closed_db.read_bytes()[18:20].hex()
    if closed_header != "0202":
        raise RuntimeError(f"closed source header is not WAL mode: {closed_header}")
    closed_source_hash_before = digest(closed_db)

    private_dir = output / "private-copy"
    private_dir.mkdir()
    private_db = private_dir / "user-library.db"
    shutil.copyfile(closed_db, private_db)
    closed_source_hash = digest(closed_db)
    if digest(private_db) != closed_source_hash:
        raise RuntimeError("private main-file copy hash does not match closed source")

    private = sqlite3.connect(private_db, timeout=2.0)
    mode = str(private.execute("PRAGMA journal_mode=DELETE").fetchone()[0]).lower()
    if mode != "delete":
        private.close()
        raise RuntimeError(f"private copy did not enter DELETE mode: {mode}")
    private_validation = validate(private)
    private.close()

    private_sidecars = {suffix: Path(f"{private_db}{suffix}") for suffix in ("-wal", "-shm", "-journal")}
    if private_sidecars["-wal"].exists() and private_sidecars["-wal"].stat().st_size != 0:
        raise RuntimeError("private copy has a non-empty WAL after DELETE normalization")
    if private_sidecars["-journal"].exists():
        raise RuntimeError("private copy has a rollback journal after close")
    for suffix in ("-wal", "-shm"):
        if private_sidecars[suffix].exists():
            private_sidecars[suffix].unlink()
    if any(path.exists() for path in private_sidecars.values()):
        raise RuntimeError("private copy still has SQLite sidecars")
    private_header = private_db.read_bytes()[18:20].hex()
    if private_header != "0101":
        raise RuntimeError(f"private copy header is not DELETE mode: {private_header}")

    reader = sqlite3.connect(f"file:{private_db}?mode=ro", uri=True, timeout=2.0)
    readonly_validation = validate(reader)
    reader.close()

    closed_source_hash_after = digest(closed_db)
    if closed_source_hash_after != closed_source_hash_before:
        raise RuntimeError("generated closed source changed during private-copy normalization")
    source_after = {path.name: digest(path) for path in source_files if path.exists()}
    if source_after != source_before:
        raise RuntimeError("fixture source bytes changed during the proof")
    source_suffixes_after = sorted(path.name for path in source.iterdir() if path.name.startswith("user-library.db-"))
    if source_suffixes_after != sorted(name for name in source_before if name != source_db.name):
        raise RuntimeError("fixture source sidecar set changed during the proof")

    result = {
        "status": "passed",
        "sourceFixture": str(fixture),
        "sourceHashesBeforeAndAfter": source_before,
        "closedSource": {**initial, "checkpoint": checkpoint, "headerBytes18And19": closed_header,
                         "sidecarsAfterClose": [], "sha256": closed_source_hash,
                         "closedSourceHashBefore": closed_source_hash_before,
                         "closedSourceHashAfter": closed_source_hash_after},
        "privateCopy": {**private_validation, "readonlyReopen": readonly_validation,
                        "journalMode": mode, "headerBytes18And19": private_header,
                        "sidecarsAfterClose": [], "sha256": digest(private_db)},
        "sourceSidecarsAfter": source_suffixes_after,
        "sourceScriptSHA256": digest(Path(__file__).resolve()),
    }
    (output / "proof.json").write_text(json.dumps(result, indent=2) + "\n")
    (output / "proof.sha256").write_text(f"{digest(output / 'proof.json')}  proof.json\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
