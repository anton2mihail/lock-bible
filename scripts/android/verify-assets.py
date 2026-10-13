#!/usr/bin/env python3
"""Verify staged Android content against the shared source corpus before packaging."""
from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    output = parser.parse_args().output.resolve()
    assets = output / "assets"
    manifest = json.loads((assets / "content-manifest.json").read_text())
    for record in manifest["files"]:
        path = output / record["path"]
        with path.open("rb") as source:
            assert hashlib.file_digest(source, "sha256").hexdigest() == record["sha256"], path
        assert path.stat().st_size == record["bytes"], path
    search = sqlite3.connect(f"file:{assets / 'Databases/bible-search.db'}?mode=ro", uri=True)
    total = 0
    for edition in manifest["editions"]:
        books = json.loads((assets / "Bible" / edition / "manifest.json").read_text())
        assert len(books) == 73
        chapters = verses = 0
        for book in books:
            name = book["code"] + ".json"
            staged = assets / "Bible" / edition / name
            assert staged.read_bytes() == (ROOT / "src/services/bible/data" / edition / name).read_bytes()
            corpus = json.loads(staged.read_text())
            assert len(corpus["chapters"]) == book["chapterCount"]
            assert [c["c"] for c in corpus["chapters"]] == list(range(1, book["chapterCount"] + 1))
            chapters += len(corpus["chapters"])
            for chapter in corpus["chapters"]:
                source_verses = [(v["n"], v["t"]) for v in chapter["verses"]]
                indexed = search.execute("SELECT verse,text FROM verses WHERE translation_id=? AND book_code=? AND chapter=? ORDER BY verse_order", (edition, book["code"], chapter["c"])).fetchall()
                assert source_verses == indexed, (edition, book["code"], chapter["c"])
                verses += len(source_verses)
        total += verses
        print(f"{edition}: {len(books)} books, {chapters} chapters, {verses} exact indexed verses")
    assert total == 106999
    assert search.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    assert search.execute("SELECT count(*) FROM verse_search WHERE verse_search MATCH ?", ('"beginning" AND "word"',)).fetchone()[0] > 0
    search.close()
    works = sqlite3.connect(f"file:{assets / 'Databases/works.db'}?mode=ro", uri=True)
    count = 0
    for work_id, index, blob in works.execute("SELECT work_id,idx,paragraphs FROM sections"):
        text = zlib.decompress(blob)
        assert len(text) <= 400000, (work_id, index)
        paragraphs = json.loads(text)
        assert isinstance(paragraphs, list) and all(isinstance(p, str) for p in paragraphs)
        count += 1
    assert count == 16146
    works.close()
    assert (assets / "Databases/works.db").read_bytes() == (ROOT / "assets/works/works.db").read_bytes()
    pinned = ROOT / "native/Android/content/companion.json"
    provenance = json.loads((pinned.parent / "companion-provenance.json").read_text())
    catalog_bytes = (assets / "Catalogs/devotional-catalogs.json").read_bytes()
    assert catalog_bytes == pinned.read_bytes(), "Staged companion catalog differs from the reviewed Android input"
    assert hashlib.sha256(catalog_bytes).hexdigest() == provenance["catalog"]["sha256"], "Companion provenance mismatch"
    catalogs = json.loads(catalog_bytes)
    for name, count in [("novenas", 7), ("prayers", 28), ("teachings", 5)]:
        assert len(catalogs[name]) == count
    assert len(catalogs["rosary"]["mysterySets"]) == 4
    for calendar, count in [("readings-us", 858), ("celebrations-us", 2922)]:
        path = assets / "Calendar" / (calendar + ".json")
        assert path.read_bytes() == (ROOT / "src/services/companion/data" / path.name).read_bytes()
        assert len(json.loads(path.read_text())) == count
    assert len(list((output / "res/font").glob("*.ttf"))) == 7
    assert (assets / "artwork/mary.jpg").is_file()
    # macOS source disks are often case-insensitive; inspect the actual entry name.
    assert "artwork" in {p.name for p in assets.iterdir()}
    assert "Artwork" not in {p.name for p in assets.iterdir()}
    print(f"Verified {len(manifest['files'])} staged files and all 16146 Works sections.")


if __name__ == "__main__":
    main()
