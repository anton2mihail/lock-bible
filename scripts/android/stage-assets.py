#!/usr/bin/env python3
"""Stage the same offline content as iOS, with Android-compatible full-text search."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EDITIONS = ("web-ce", "douay-rheims", "vulgate")
FONTS = {
    "lora_regular": "lora/400Regular/Lora_400Regular.ttf",
    "lora_medium": "lora/500Medium/Lora_500Medium.ttf",
    "space_grotesk_light": "space-grotesk/300Light/SpaceGrotesk_300Light.ttf",
    "space_grotesk_regular": "space-grotesk/400Regular/SpaceGrotesk_400Regular.ttf",
    "space_grotesk_medium": "space-grotesk/500Medium/SpaceGrotesk_500Medium.ttf",
    "space_grotesk_semibold": "space-grotesk/600SemiBold/SpaceGrotesk_600SemiBold.ttf",
    "space_grotesk_bold": "space-grotesk/700Bold/SpaceGrotesk_700Bold.ttf",
}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def copy(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or digest(source) != digest(target):
        shutil.copyfile(source, target)


def search_database(target: Path) -> None:
    source = ROOT / "assets/bible/bible-search.db"
    signature = digest(source)
    stamp = target.with_suffix(".sha256")
    signature += "-android-fts4-v2"
    if target.exists() and stamp.exists() and stamp.read_text() == signature:
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".tmp")
    temporary.unlink(missing_ok=True)
    origin = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
    db = sqlite3.connect(temporary)
    try:
        db.execute("PRAGMA journal_mode=OFF")
        db.execute("PRAGMA synchronous=OFF")
        for table in ("books", "verses", "vocabulary"):
            sql = origin.execute("SELECT sql FROM sqlite_master WHERE name=?", (table,)).fetchone()[0]
            db.execute(sql)
            rows = origin.execute(f"SELECT * FROM {table}")
            marks = ",".join("?" for _ in rows.description)
            db.executemany(f"INSERT INTO {table} VALUES ({marks})", rows)
        db.execute("CREATE INDEX verses_location ON verses(translation_id,book_code,chapter,verse_order)")
        db.execute("CREATE VIRTUAL TABLE verse_search USING fts4(text,book_name,tokenize=unicode61)")
        db.execute("INSERT INTO verse_search(docid,text,book_name) SELECT id,text,book_name FROM verses ORDER BY id")
        db.execute("CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)")
        db.execute("INSERT INTO metadata VALUES ('sourceSha256',?)", (signature,))
        db.commit()
        assert db.execute("SELECT count(*) FROM verses").fetchone()[0] == 106999
        assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    finally:
        origin.close()
        db.close()
    temporary.replace(target)
    stamp.write_text(signature)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output.resolve()
    assets = output / "assets"
    # Remove only unchanged files recorded by the previous generated manifest.
    prior_manifest = assets / "content-manifest.json"
    if prior_manifest.exists():
        prior = json.loads(prior_manifest.read_text())
        for record in prior.get("files", []):
            if record["path"].startswith("assets/Artwork/"):
                old = output / record["path"]
                if old.is_file() and digest(old) == record["sha256"]:
                    old.unlink()
        old_artwork = assets / "Artwork"
        if old_artwork.exists():
            for directory in sorted((p for p in old_artwork.rglob("*") if p.is_dir()), reverse=True):
                if not any(directory.iterdir()):
                    directory.rmdir()
            if not any(old_artwork.iterdir()):
                old_artwork.rmdir()
    for edition in EDITIONS:
        source = ROOT / "src/services/bible/data" / edition
        manifest = json.loads((source / "manifest.json").read_text())
        assert len(manifest) == 73
        for name in ["meta.json", "manifest.json", "widgetVerses.json"] + [book["code"] + ".json" for book in manifest]:
            copy(source / name, assets / "Bible" / edition / name)
    for source, target in (
        ("assets/works/works.db", "Databases/works.db"),
        ("src/services/works/data/catalog.json", "Catalogs/works-catalog.json"),
        ("src/services/companion/data/readings-us.json", "Calendar/readings-us.json"),
        ("src/services/companion/data/celebrations-us.json", "Calendar/celebrations-us.json"),
        ("src/services/companion/data/saints-vatican.json", "Calendar/saints-vatican.json"),
        ("src/services/companion/data/saints-byzantine.json", "Calendar/saints-byzantine.json"),
        ("assets/CREDITS.md", "Credits/CREDITS.md"),
        ("assets/READINGS-LICENSE.txt", "Credits/READINGS-LICENSE.txt"),
        ("assets/ROMCAL-LICENSE.txt", "Credits/ROMCAL-LICENSE.txt"),
    ):
        copy(ROOT / source, assets / target)
    # Release content is reviewed and pinned independently of uncommitted iOS edits.
    companion = ROOT / "native/Android/content/companion.json"
    provenance = json.loads((companion.parent / "companion-provenance.json").read_text())
    if digest(companion) != provenance["catalog"]["sha256"]:
        raise ValueError("Pinned Android companion catalog does not match its provenance")
    copy(companion, assets / "Catalogs/devotional-catalogs.json")
    for folder in ("artwork", "icons", "images"):
        for source in sorted((ROOT / "assets" / folder).rglob("*")):
            if source.is_file():
                copy(source, assets / "artwork" / (source.relative_to(ROOT / "assets/artwork") if folder == "artwork" else source.relative_to(ROOT / "assets")))
    for name, source in FONTS.items():
        source = ROOT / "node_modules/@expo-google-fonts" / source
        copy(source, output / "res/font" / (name + ".ttf"))
        copy(source, assets / "Fonts" / source.name)
    for family in ("lora", "space-grotesk"):
        copy(ROOT / "node_modules/@expo-google-fonts" / family / "LICENSE_FONT", assets / "Credits" / (family + "-OFL.txt"))
    search_database(assets / "Databases/bible-search.db")
    records = [{"path": str(file.relative_to(output)), "bytes": file.stat().st_size, "sha256": digest(file)}
               for file in sorted(output.rglob("*")) if file.is_file() and file.name != "content-manifest.json"]
    (assets / "content-manifest.json").write_text(json.dumps({"formatVersion": 1, "editions": list(EDITIONS), "files": records}, indent=2) + "\n")
    print(f"Staged {len(records)} files in {output}")


if __name__ == "__main__":
    main()
