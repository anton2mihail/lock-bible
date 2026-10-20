#!/usr/bin/env python3
"""Create deterministic source resource trees for the native app and widget."""
from __future__ import annotations

import hashlib
import json
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT_BASE = (ROOT / "build/native-evidence/L03/staged").resolve()
EDITIONS = ("web-ce", "douay-rheims", "vulgate")
FONT_ALIASES = {
    "loraRegular": ("node_modules/@expo-google-fonts/lora/400Regular/Lora_400Regular.ttf", "Lora-Regular"),
    "loraMedium": ("node_modules/@expo-google-fonts/lora/500Medium/Lora_500Medium.ttf", "Lora-Medium"),
    "spaceGroteskLight": ("node_modules/@expo-google-fonts/space-grotesk/300Light/SpaceGrotesk_300Light.ttf", "SpaceGrotesk-Light"),
    "spaceGroteskRegular": ("node_modules/@expo-google-fonts/space-grotesk/400Regular/SpaceGrotesk_400Regular.ttf", "SpaceGrotesk-Regular"),
    "spaceGroteskMedium": ("node_modules/@expo-google-fonts/space-grotesk/500Medium/SpaceGrotesk_500Medium.ttf", "SpaceGrotesk-Medium"),
    "spaceGroteskSemiBold": ("node_modules/@expo-google-fonts/space-grotesk/600SemiBold/SpaceGrotesk_600SemiBold.ttf", "SpaceGrotesk-SemiBold"),
    "spaceGroteskBold": ("node_modules/@expo-google-fonts/space-grotesk/700Bold/SpaceGrotesk_700Bold.ttf", "SpaceGrotesk-Bold"),
}
WIDGET_FILES = sorted(
    [f"targets/widget/{edition}.{suffix}" for edition in EDITIONS for suffix in ("dat", "offsets", "ot", "nt", "meta.json")]
    + [f"targets/widget/daily-readings-{year}.json" for year in range(2025, 2033)]
)
ROTATION_FILES = sorted(f"targets/widget/{edition}.{suffix}" for edition in EDITIONS for suffix in ("dat", "offsets", "ot", "nt", "meta.json"))
DEVOTIONAL_SOURCES = [
    "src/services/companion/prayers.ts", "src/services/companion/teaching.ts",
    "src/services/novena/catalog.ts", "src/services/novena/expandedNovenas.ts",
    "src/services/novena/padrePioNovena.ts", "src/services/novena/perpetualHelpNovena.ts",
    "src/services/novena/stJosephNovena.ts", "src/services/novena/stJudeNovena.ts",
    "src/services/novena/stPeregrineNovena.ts", "src/services/novena/stThereseNovena.ts",
    "src/services/rosary/catalog.ts", "src/services/rosary/prayers.ts",
    "src/services/works/data/catalog.json", "scripts/native/resources/export-catalogs.ts",
]
ROTATION_SOURCES = [
    *(f"src/services/bible/data/{edition}/widgetVerses.json" for edition in EDITIONS),
    "scripts/widget-data-format.mjs", "scripts/build-widget-data.mjs",
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else str(path)


def copy_file(source_rel: str, output_rel: str, target: str, records: list[dict]) -> None:
    source = ROOT / source_rel
    if not source.is_file():
        raise RuntimeError(f"missing source: {source_rel}")
    destination = output / output_rel
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    records.append({"path": output_rel, "sourcePath": source_rel, "target": target,
                    "bytes": source.stat().st_size, "sha256": sha256(source)})


def sqlite_metadata(source_rel: str) -> dict:
    path = ROOT / source_rel
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        tables = []
        for name, sql in db.execute("SELECT name, sql FROM sqlite_master WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%' ORDER BY name"):
            rows = db.execute(f'SELECT count(*) FROM "{name}"').fetchone()[0] if name not in {"verse_search"} else db.execute("SELECT count(*) FROM verse_search").fetchone()[0]
            tables.append({"name": name, "sql": sql, "rows": rows})
        metadata_table = "metadata"
        metadata = dict(db.execute(f"SELECT key, value FROM {metadata_table}"))
        user_version = db.execute("PRAGMA user_version").fetchone()[0]
        return {"sourcePath": source_rel, "bytes": path.stat().st_size, "sha256": sha256(path), "userVersion": user_version,
                "tables": tables, "metadata": metadata}
    finally:
        db.close()


def main() -> None:
    global output
    if len(sys.argv) != 2:
        raise SystemExit("usage: stage-resources.py build/native-evidence/L03/staged/<new-name>")
    output = (ROOT / sys.argv[1]).resolve()
    if not output.is_relative_to(OUT_BASE) or output == OUT_BASE:
        raise RuntimeError("output must be a new child of build/native-evidence/L03/staged")
    if output.exists():
        raise RuntimeError(f"output already exists; refusing to remove or replace it: {relative(output)}")
    output.mkdir(parents=True)
    records: list[dict] = []
    counts: dict = {}
    provenance: dict[str, str] = {}

    for edition in EDITIONS:
        base = f"src/services/bible/data/{edition}"
        manifest = json.loads((ROOT / base / "manifest.json").read_text())
        meta = json.loads((ROOT / base / "meta.json").read_text())
        if meta.get("id") != edition or len(manifest) != 73:
            raise RuntimeError(f"unexpected Bible edition metadata for {edition}")
        for name in ("meta.json", "manifest.json"):
            copy_file(f"{base}/{name}", f"App/Bible/{edition}/{name}", "app", records)
        widget_payload = json.loads((ROOT / base / "widgetVerses.json").read_text())
        counts[f"rotationPool:{edition}"] = len(widget_payload["verses"])
        seen = set()
        for book in manifest:
            code = book["code"]
            if code in seen:
                raise RuntimeError(f"duplicate book code {edition}/{code}")
            seen.add(code)
            copy_file(f"{base}/{code}.json", f"App/Bible/{edition}/{code}.json", "app", records)
        counts[f"bibleBooks:{edition}"] = len(seen)

    for source, target in (
        ("assets/bible/bible-search.db", "App/Databases/bible-search.db"),
        ("assets/works/works.db", "App/Databases/works.db"),
        ("src/services/works/data/catalog.json", "App/Catalogs/works-catalog.json"),
        ("src/services/companion/data/readings-us.json", "App/Calendar/readings-us.json"),
        ("src/services/companion/data/celebrations-us.json", "App/Calendar/celebrations-us.json"),
        ("src/services/companion/data/my-saints.json", "App/Calendar/my-saints.json"),
        ("src/services/companion/data/saints-vatican.json", "App/Calendar/saints-vatican.json"),
        ("src/services/companion/data/saints-byzantine.json", "App/Calendar/saints-byzantine.json"),
    ):
        copy_file(source, target, "app", records)

    catalog_path = output / "App/Catalogs/devotional-catalogs.json"
    subprocess.run([str(ROOT / "node_modules/.bin/tsx"), str(ROOT / "scripts/native/resources/export-catalogs.ts"), str(catalog_path)],
                   cwd=ROOT, check=True, capture_output=True, text=True)
    catalog_obj = json.loads(catalog_path.read_text())
    for key, value in sorted({"novenas": len(catalog_obj["novenas"]), "prayers": len(catalog_obj["prayers"]),
                              "teachings": len(catalog_obj["teachings"]), "mysterySets": len(catalog_obj["rosary"]["mysterySets"]),
                              "mediaEpisodes": len(catalog_obj["rosary"]["mediaEpisodes"]),
                              "worksCollections": len(json.loads((ROOT / "src/services/works/data/catalog.json").read_text())["collections"])}.items()):
        counts[key] = value
    expected_catalogs = {"novenas": 7, "prayers": 28, "teachings": 5, "mysterySets": 4, "mediaEpisodes": 6, "worksCollections": 26}
    if any(counts[key] != value for key, value in expected_catalogs.items()):
        raise RuntimeError(f"unexpected source catalog counts: {counts}")
    for p in DEVOTIONAL_SOURCES + ROTATION_SOURCES:
        provenance[p] = sha256(ROOT / p)
    records.append({"path": "App/Catalogs/devotional-catalogs.json", "sourcePath": "scripts/native/resources/export-catalogs.ts + source catalogs",
                    "target": "app", "bytes": catalog_path.stat().st_size, "sha256": sha256(catalog_path)})

    readings = json.loads((ROOT / "src/services/companion/data/readings-us.json").read_text())
    celebrations = json.loads((ROOT / "src/services/companion/data/celebrations-us.json").read_text())
    counts["dailyReadings"] = len(readings)
    counts["celebrations"] = len(celebrations)
    counts["readingsCoverage"] = [min(readings), max(readings)] if isinstance(readings, dict) else [readings[0]["date"], readings[-1]["date"]]
    counts["celebrationsCoverage"] = [min(celebrations), max(celebrations)] if isinstance(celebrations, dict) else [celebrations[0]["date"], celebrations[-1]["date"]]
    if counts["dailyReadings"] != 858 or counts["celebrations"] != 2922:
        raise RuntimeError("unexpected calendar source counts")

    for item in sorted((ROOT / "assets/artwork").iterdir()):
        if item.is_file():
            copy_file(relative(item), f"App/Artwork/{item.name}", "app", records)
    for folder in ("assets/icons", "assets/images"):
        for item in sorted((ROOT / folder).iterdir()):
            if item.is_file():
                copy_file(relative(item), f"App/Artwork/{folder.split('/')[-1]}/{item.name}", "app", records)

    font_info = {}
    for alias, (source, postscript) in sorted(FONT_ALIASES.items()):
        source_path = ROOT / source
        copy_file(source, f"App/Fonts/{source_path.name}", "app", records)
        font_info[alias] = {"path": f"App/Fonts/{source_path.name}", "sourcePath": source, "postScriptName": postscript,
                            "bytes": source_path.stat().st_size, "sha256": sha256(source_path)}
    for source in WIDGET_FILES:
        copy_file(source, f"Widget/{Path(source).name}", "widget", records)
    for source in ROTATION_FILES:
        copy_file(source, f"App/Rotation/{Path(source).name}", "app", records)
    if len(WIDGET_FILES) != 23 or len({Path(path).name for path in WIDGET_FILES}) != len(WIDGET_FILES):
        raise RuntimeError("unexpected widget file count or basename collision")

    databases = {name: sqlite_metadata(path) for name, path in (("search", "assets/bible/bible-search.db"), ("works", "assets/works/works.db"))}
    if databases["works"]["metadata"].get("schemaVersion") != "2" or databases["works"]["metadata"].get("paragraphEncoding") != "zlib-json":
        raise RuntimeError("unexpected works DB metadata")
    if databases["works"]["metadata"].get("sectionCount") != "16146":
        raise RuntimeError("unexpected works DB section count")
    if databases["search"]["metadata"].get("schema_version") != "1" or "verse_search" not in {table["name"] for table in databases["search"]["tables"]}:
        raise RuntimeError("unexpected search DB metadata")
    if databases["search"]["metadata"].get("translation_ids") != "vulgate,web-ce,douay-rheims" or databases["search"]["metadata"].get("verse_count") != "106999":
        raise RuntimeError("unexpected search DB edition metadata")

    records.sort(key=lambda row: (row["target"], row["path"]))
    if len({row["path"] for row in records}) != len(records):
        raise RuntimeError("staged path collision")
    app_files = sorted(row["path"] for row in records if row["target"] == "app")
    widget_files = sorted(row["path"] for row in records if row["target"] == "widget")
    manifest = {"schemaVersion": 1, "files": records, "requiredContentCounts": dict(sorted(counts.items())),
                "editionIds": list(EDITIONS), "fontAliases": font_info, "sqlite": databases,
                "calendarCoverage": {"readings": counts["readingsCoverage"], "celebrations": counts["celebrationsCoverage"]},
                "sourceProvenance": dict(sorted(provenance.items()))}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    (output / "app-target-files.json").write_text(json.dumps(app_files, indent=2) + "\n")
    (output / "widget-target-files.json").write_text(json.dumps(widget_files, indent=2) + "\n")
    print(json.dumps({"output": relative(output), "appFiles": len(app_files), "widgetFiles": len(widget_files), "allFiles": len(records),
                      "counts": counts, "manifestSha256": sha256(output / "manifest.json")}, indent=2))


if __name__ == "__main__":
    main()
