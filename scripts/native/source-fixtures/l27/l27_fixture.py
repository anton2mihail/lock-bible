#!/usr/bin/env python3
"""L27 full same-ID update fixture: prepare, seed, verify, and export helpers.

The fixture holds old-app data in the old Expo app's own storage formats:
MMKV (mmkv.default and .crc), user-library.db with a committed WAL, and the App Group widget prefs plist.
It holds no native file. Use it only for the L27 same-ID update rehearsal. The L25 fixture is separate.

Commands
  prepare       Build a new fixture folder (host only). Refuses an existing output folder.
  seed          Put the fixture into the OLD app container. Dry run by default.
  verify        Compare the old container bytes and modes with the manifest. Read only.
  export-old    Make old-source-before/after.json (comparator input) from a COPIED container tree.
  wrap-envelope Make native-envelope.json (comparator input) from a COPIED native envelope file.
  inspect-recovery  Make recovery-inspect.json (comparator input) from a COPIED recovery database.
  mapping       Make an expectation mapping from a COPIED before export, for the values that old app actions change.
  host-run      Run the real JohnCore importer on macOS against fixture copies (no simulator) and run the comparator.

Simulator rules
  This tool never boots, installs, launches, or terminates anything.
  `seed` and `verify` touch only the data container path that Main supplies.
  The tool calls `xcrun simctl get_app_container` only when Main passes --udid.
  Main must stop the old app before `seed --apply`.
  `export-old`, `wrap-envelope`, `inspect-recovery`, and `mapping` read copies below build/native-evidence/L27.
"""
import argparse
import base64
import datetime
import hashlib
import json
import os
import plistlib
import shutil
import sqlite3
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sys.path.insert(0, str(HERE.parent / "l25"))
import mmkv_decode  # noqa: E402

EVIDENCE = REPO / "build" / "native-evidence"
L27 = EVIDENCE / "L27"
DEFAULT_FIXTURE = L27 / "full-fixture-01"
OLD_BUNDLE = "com.nrsv.verse"
SEARCH_DB_SOURCE = EVIDENCE / "L00" / "synthetic-legacy-fixture" / "Documents" / "SQLite" / "bible-search.db"
SEARCH_DB_SHA = "e2ee48c4edaeeaa5c6b340af35e32b228563c3191ca55453340dfd9b8fe1fd94"
VENDOR_MMKV = REPO / "native" / "John" / "LegacyAdapter" / "Vendor" / "MMKVCore"
TABLES = ("bookmarks", "highlights", "notes")

# fixture-relative path, container path, mode, action, purpose
FIXTURE_FILES = [
    ("old/com.nrsv.verse/Documents/SQLite/bible-search.db", "Documents/SQLite/bible-search.db", 0o600,
     "copy-if-different", "Old app Bible search database. Same bytes as the bundled copy."),
    ("old/com.nrsv.verse/Documents/SQLite/user-library.db", "Documents/SQLite/user-library.db", 0o644,
     "copy", "Old library main file. WAL journal mode. Holds 3 bookmarks and 8 highlights. The 3 notes are only in the WAL."),
    ("old/com.nrsv.verse/Documents/SQLite/user-library.db-wal", "Documents/SQLite/user-library.db-wal", 0o644,
     "copy", "Old library WAL with committed frames: 3 notes and one note edit (3 rows after replay)."),
    ("old/com.nrsv.verse/Documents/SQLite/user-library.db-shm", "Documents/SQLite/user-library.db-shm", 0o644,
     "copy", "Old library shared-memory file, as left by a killed app."),
    ("old/com.nrsv.verse/Documents/mmkv/mmkv.default", "Documents/mmkv/mmkv.default", 0o700,
     "copy", "Old app MMKV data: 45 keys in the old source formats (15 preference keys, 27 novena keys, 3 reflections)."),
    ("old/com.nrsv.verse/Documents/mmkv/mmkv.default.crc", "Documents/mmkv/mmkv.default.crc", 0o700,
     "copy", "Old app MMKV meta and CRC file. Copy it together with mmkv.default."),
    ("old/com.nrsv.verse/Library/Preferences/group.com.nrsv.verse.plist", "Library/Preferences/group.com.nrsv.verse.plist", 0o600,
     "copy", "Old app widget scalars (App Group defaults): schema 2, 60 minutes, scope nt, Douay-Rheims."),
]
# Removed from the old container before the copy. They would mix with the seed or hide it.
REMOVE_BEFORE_COPY = ["Documents/SQLite/user-library.db-journal"]
# The native state folder. A native build under the same bundle ID loads these files first and skips the import.
STALE_NATIVE_DIR = "Library/Application Support/John"
WRITABLE_DIRS = ["Documents", "Documents/SQLite", "Documents/mmkv", "Library", "Library/Preferences"]


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def mode_of(path):
    return stat.S_IMODE(os.stat(path).st_mode)


def rel(path):
    try:
        return str(Path(path).resolve().relative_to(REPO))
    except ValueError:
        return str(path)


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    sys.exit(2)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def require_under_l27(path, label):
    resolved = Path(path).resolve()
    if resolved != L27.resolve() and not str(resolved).startswith(str(L27.resolve()) + "/"):
        fail("%s must be a copied file below build/native-evidence/L27: %s" % (label, resolved))
    return resolved


def run(cmd, log, cwd=None, env=None):
    with open(log, "w") as handle:
        result = subprocess.run(cmd, stdout=handle, stderr=subprocess.STDOUT, cwd=cwd, env=env)
    if result.returncode != 0:
        fail("command failed (%s). See %s" % (" ".join(map(str, cmd[:3])), log))


# ---------------------------------------------------------------------------------------------
# SQLite helpers (always on temporary copies)
# ---------------------------------------------------------------------------------------------

def snapshot_library(db_main_path, with_sidecars=True):
    """Read user_version, integrity, journal mode (from the header), and all rows. WAL frames count."""
    src = Path(db_main_path)
    header = src.read_bytes()[:100]
    header_mode = {1: "delete", 2: "wal"}.get(header[18], "unknown") if len(header) >= 100 else "short"
    with tempfile.TemporaryDirectory(prefix="l27-db-") as tmp:
        for suffix in ("", "-wal", "-shm"):
            candidate = Path(str(src) + suffix)
            if candidate.exists() and (with_sidecars or suffix == ""):
                shutil.copyfile(candidate, Path(tmp) / ("user-library.db" + suffix))
        con = sqlite3.connect(str(Path(tmp) / "user-library.db"))
        try:
            con.row_factory = sqlite3.Row
            result = {
                "schemaVersion": con.execute("PRAGMA user_version").fetchone()[0],
                "integrityCheck": con.execute("PRAGMA integrity_check").fetchone()[0],
                "journalMode": header_mode,
                "tables": {},
            }
            for table in TABLES:
                cursor = con.execute("SELECT * FROM %s" % table)
                columns = [d[0] for d in cursor.description]
                rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
                result["tables"][table] = {"columns": columns, "rows": rows}
            return result
        finally:
            con.close()


# ---------------------------------------------------------------------------------------------
# prepare
# ---------------------------------------------------------------------------------------------

def build_mmkv(work, tsv):
    """Build MMKV Core v2.0.0 for the host and write the MMKV files with the pinned core (same as the old app uses)."""
    derived = work / "MMKVCore-mac"
    run(["xcodebuild", "-project", str(VENDOR_MMKV / "Core.xcodeproj"), "-scheme", "Core", "-configuration", "Debug",
         "-destination", "generic/platform=macOS", "-derivedDataPath", str(derived),
         "GCC_PREPROCESSOR_DEFINITIONS=DEBUG=1 FORCE_POSIX=1 $(inherited)", "build"], work / "mmkv-core-host.log")
    lib = derived / "Build" / "Products" / "Debug" / "libMMKVCore.a"
    if not lib.exists():
        fail("MMKV Core host library was not built")
    creator = work / "create-mmv2-fixture"
    run(["xcrun", "clang++", "-std=c++20", "-DFORCE_POSIX=1", "-I", str(VENDOR_MMKV),
         str(REPO / "scripts/native/source-fixtures/l04/create-mmk-v2-fixture.cpp"), str(lib),
         "-framework", "Foundation", "-lz", "-o", str(creator)], work / "mmkv-creator-build.log")
    root = work / "mmkv-root"
    run([str(creator), str(root), str(tsv)], work / "mmkv-create.log")
    return root


def read_tsv(path):
    values = {}
    for line in Path(path).read_text().splitlines():
        if not line:
            continue
        key_hex, value_hex = line.split("\t")
        values[bytes.fromhex(key_hex).decode("utf-8")] = bytes.fromhex(value_hex).decode("utf-8")
    return values


def category_table(expectations, citations):
    """One row per persistent category: old format, old value, and the expected result at each update stage."""
    raw = expectations["rawLegacyMMKVStrings"]
    state = expectations["expectedNativeState"]
    cite = lambda *names: [citations[n] for n in names]  # noqa: E731
    novena_keys = sorted(k for k in raw if k.startswith("novena."))
    sunday_keys = sorted(k for k in raw if k.startswith("vesper.sunday."))
    rows = counts = expectations["sourceLibrary"]["rowCounts"]
    after = lambda value: {"firstImport": value, "nativeWinsRestart": "unchanged", "repeatUpdate": "unchanged",  # noqa: E731
                           "interruptedImportThenRestart": "same as first import"}
    table = [
        {"category": "Library: bookmarks, highlights, notes (3 editions, overlapping highlight batches)",
         "oldFormat": "SQLite user-library.db, WAL mode, schema 1; rows from the old source functions", "citations": cite("library.open", "library.version", "library.bookmark", "library.highlight", "library.note"),
         "oldValue": {"rowCounts": counts, "notesOnlyInWAL": True},
         "expected": after("No import. Main file and WAL unchanged. A new recovery backup holds all rows, WAL rows included (3/8/3). SHM can change.")},
        {"category": "Appearance", "oldFormat": "MMKV ignite.themeScheme, raw string (not JSON)", "citations": cite("theme.rawString", "theme.systemClears"),
         "oldValue": {"ignite.themeScheme": raw["ignite.themeScheme"]}, "expected": after({"/themeScheme": state["themeScheme"]})},
        {"category": "Edition, cadence, scope", "oldFormat": "MMKV bible.translationId, bible.rotationInterval, bible.verseScope (JSON)",
         "citations": cite("bible.keys", "bible.translationId", "bible.rotationInterval", "bible.verseScope"),
         "oldValue": {k: raw[k] for k in ("bible.translationId", "bible.rotationInterval", "bible.verseScope")},
         "expected": after({"/translationID": state["translationID"], "/rotationIntervalMinutes": state["rotationIntervalMinutes"], "/verseScope": state["verseScope"]})},
        {"category": "Reader typography", "oldFormat": "MMKV bible.reader.textSize, lineSpacing, typeface, layout (JSON strings)",
         "citations": cite("reader.keys", "reader.textSize", "reader.lineSpacing", "reader.typeface", "reader.layout"),
         "oldValue": {k: raw[k] for k in raw if k.startswith("bible.reader.") and k.split(".")[-1] in ("textSize", "lineSpacing", "typeface", "layout")},
         "expected": after({"/readingPreferences": state["readingPreferences"]})},
        {"category": "Reader position", "oldFormat": "MMKV bible.reader.location, JSON {book, chapter, scrollY, updatedAt}",
         "citations": cite("reader.location"), "oldValue": {"bible.reader.location": raw["bible.reader.location"]},
         "expected": after({"/readerLocation": state["readerLocation"], "note": "no native anchor; the comparator allows an absent or null anchor"})},
        {"category": "Guide and selection flags", "oldFormat": "MMKV bible.widgetGuideDismissed, bible.reader.selectionHintDismissed (JSON true)",
         "citations": cite("reader.widgetGuide", "reader.selectionHint"),
         "oldValue": {k: raw[k] for k in ("bible.widgetGuideDismissed", "bible.reader.selectionHintDismissed")},
         "expected": after({"/widgetGuideDismissed": True, "/selectionHintDismissed": True})},
        {"category": "Prayer favorites (order kept)", "oldFormat": "MMKV vesper.prayer.favorites, JSON array", "citations": cite("favorites.save"),
         "oldValue": {"vesper.prayer.favorites": raw["vesper.prayer.favorites"]}, "expected": after({"/favoritePrayerIDs": state["favoritePrayerIDs"]})},
        {"category": "Sunday reflections (%d dates)" % len(sunday_keys), "oldFormat": "MMKV vesper.sunday.<date>, JSON {before, after}", "citations": cite("reflection.save"),
         "oldValue": {k: raw[k] for k in sunday_keys}, "expected": after({"/reflections": state["reflections"]})},
        {"category": "Novena intentions and completion (%d novenas)" % len(novena_keys), "oldFormat": "MMKV novena.<id>.progress.v1, JSON {completedDays, selectedDay, intention}",
         "citations": cite("novena.key", "novena.save", "novena.model"), "oldValue": {"keys": len(novena_keys), "sample": {novena_keys[0]: raw[novena_keys[0]], novena_keys[1]: raw[novena_keys[1]]}},
         "expected": after({"/novenaProgress": "27 entries equal to the old values (includes full completion, an empty intention, and a multi-line intention with an emoji)"})},
        {"category": "Works positions (Reader of Works)", "oldFormat": "MMKV works.position.v1, JSON map workId -> {workId, sectionIndex, pageIndex, updatedAt}",
         "citations": cite("works.key", "works.save"), "oldValue": {"works.position.v1": raw["works.position.v1"]},
         "expected": after({"/worksPositions": state["worksPositions"], "note": "the old app writes no paragraph anchor"})},
        {"category": "Calendar notification setting", "oldFormat": "MMKV john.calendar-notifications.v1, JSON {enabled, hour, minute}. No request IDs are stored.",
         "citations": cite("calendar.key", "calendar.save", "calendar.requestIDs"), "oldValue": {"john.calendar-notifications.v1": raw["john.calendar-notifications.v1"]},
         "expected": after({"/calendarNotifications": state["calendarNotifications"],
                            "osState": "Pending requests john-calendar:<ms> exist only if the old app scheduled them. A host seed cannot create them."})},
        {"category": "Rosary reminder setting and ID", "oldFormat": "MMKV rosary.reminder.v1, JSON {enabled, frequency, hour, minute, weekday, notificationId}",
         "citations": cite("rosary.key", "rosary.save", "rosary.notificationId"), "oldValue": {"rosary.reminder.v1": raw["rosary.reminder.v1"]},
         "expected": after({"/rosaryReminder": state["rosaryReminder"],
                            "osState": "The seeded ID is a host text value. A real ID is a UUID made by the OS call in the old app. See the OS supplement."})},
        {"category": "Widget preferences (App Group defaults)", "oldFormat": "group.com.nrsv.verse defaults: widgetSchemaVersion (string), intervalMinutes (number), scope, translationId, abbreviation, attribution (strings)",
         "citations": cite("widget.group", "widget.scalars", "widget.intervalIsNumber"), "oldValue": expectations["appGroupWidgetScalars"],
         "expected": after({"widgetScalars": "names, types, and values unchanged (the comparator checks this)"})},
        {"category": "Widget configurations (installed widgets)", "oldFormat": "Static widget kinds only. No per-widget user configuration exists.", "citations": cite("widget.static"),
         "oldValue": "not seedable on the host", "expected": after("observation only: record which widget kinds are installed, if the simulator can show it")},
    ]
    if state.get("legacyUnknownKeys"):
        table.append({"category": "Unknown legacy key (probe, not an old-app format)", "oldFormat": "MMKV l27.unknown.preserved", "citations": [],
                      "oldValue": {k: raw[k] for k in state["legacyUnknownKeys"]}, "expected": after("raw string stays byte for byte in MMKV")})
    return table


def cmd_prepare(args):
    out = Path(args.out).resolve()
    if out.exists():
        fail("output folder exists. Use a new path: %s" % out)
    if not str(out).startswith(str(L27.resolve()) + "/"):
        fail("output must be below build/native-evidence/L27")
    if shutil.which("bun") is None:
        fail("bun is required")
    if sha256_file(SEARCH_DB_SOURCE) != SEARCH_DB_SHA:
        fail("frozen bible-search.db hash changed")
    out.mkdir(parents=True)
    work = out.parent / (out.name + "-work")
    if work.exists():
        fail("work folder exists: %s" % work)
    work.mkdir()

    # 1. Data: MMKV rows, library files, widget scalars, expectations (bun, old source functions).
    data = work / "data"
    command = ["bun", str(HERE / "build-full-fixture-data.ts"), str(data)] + (["--probes"] if args.probes else [])
    run(command, work / "data-build.log", cwd=REPO)
    legacy = read_tsv(data / "legacy-values.tsv")
    expectations = json.loads((data / "source-expectations.json").read_text())

    # 2. MMKV files from the pinned MMKV Core.
    mmkv_root = build_mmkv(work, data / "legacy-values.tsv")

    # 3. Assemble the fixture tree.
    old = out / "old" / OLD_BUNDLE
    for sub in ("Documents/SQLite", "Documents/mmkv", "Library/Preferences"):
        (old / sub).mkdir(parents=True)
    shutil.copyfile(SEARCH_DB_SOURCE, old / "Documents/SQLite/bible-search.db")
    shutil.copyfile(data / "library/user-library.db.copy", old / "Documents/SQLite/user-library.db")
    shutil.copyfile(data / "library/user-library.db-wal.copy", old / "Documents/SQLite/user-library.db-wal")
    shutil.copyfile(data / "library/user-library.db-shm.copy", old / "Documents/SQLite/user-library.db-shm")
    shutil.copyfile(mmkv_root / "mmkv.default", old / "Documents/mmkv/mmkv.default")
    shutil.copyfile(mmkv_root / "mmkv.default.crc", old / "Documents/mmkv/mmkv.default.crc")
    scalars = json.loads((data / "group-prefs.json").read_text())
    plist = {k: v["value"] for k, v in scalars.items()}
    with open(old / "Library/Preferences/group.com.nrsv.verse.plist", "wb") as handle:
        plistlib.dump(plist, handle, fmt=plistlib.FMT_BINARY)
    for _, container, mode, _, _ in FIXTURE_FILES:
        os.chmod(out / "old" / OLD_BUNDLE / container, mode)
    for directory in [out] + [p for p in out.rglob("*") if p.is_dir()]:
        os.chmod(directory, 0o755)

    # 4. Checks: the written files decode to the intended values.
    decoded = mmkv_decode.decode(str(old / "Documents/mmkv/mmkv.default"), str(old / "Documents/mmkv/mmkv.default.crc"))
    checks = []

    def check(name, ok, detail=""):
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("mmkv.crc", decoded["crcOK"])
    check("mmkv.keys equal source rows", decoded["keys"] == legacy, "%d keys" % len(legacy))
    check("mmkv.key count", len(legacy) == len(decoded["keys"]) == (46 if args.probes else 45))
    snap = snapshot_library(old / "Documents/SQLite/user-library.db")
    snap_main = snapshot_library(old / "Documents/SQLite/user-library.db", with_sidecars=False)
    expected_rows = expectations["sourceLibrary"]["finalRows"]
    sort_rows = lambda rows, t: sorted(rows, key=lambda r: json.dumps(r, sort_keys=True))  # noqa: E731
    for table in TABLES:
        check("library.%s rows equal source rows (with WAL)" % table,
              sort_rows(snap["tables"][table]["rows"], table) == sort_rows(expected_rows[table], table),
              "%d rows" % len(snap["tables"][table]["rows"]))
    check("library.user_version", snap["schemaVersion"] == 1)
    check("library.integrity", snap["integrityCheck"] == "ok")
    check("library.journal header", snap["journalMode"] == "wal")
    check("library.notes only in WAL", len(snap_main["tables"]["notes"]["rows"]) == 0 and len(snap["tables"]["notes"]["rows"]) == 3,
          "main file notes=%d; with WAL notes=%d" % (len(snap_main["tables"]["notes"]["rows"]), len(snap["tables"]["notes"]["rows"])))
    reread = plistlib.loads((old / "Library/Preferences/group.com.nrsv.verse.plist").read_bytes())
    check("group plist equals widget scalars", reread == plist and isinstance(reread["intervalMinutes"], int)
          and not isinstance(reread["intervalMinutes"], bool))
    check("search db hash", sha256_file(old / "Documents/SQLite/bible-search.db") == SEARCH_DB_SHA)
    failed = [c for c in checks if not c["ok"]]
    if failed:
        fail("fixture checks failed: " + "; ".join(c["name"] for c in failed))

    # 5. Evidence files.
    expected = out / "expected"
    expected.mkdir()
    for name in ("source-expectations.json", "format-sources.json", "group-prefs.json", "legacy-values.tsv"):
        shutil.copyfile(data / name, expected / name)
    (expected / "old-mmkv-decoded.json").write_text(json.dumps(
        {k: v for k, v in decoded.items() if k != "appendLog"}, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    (expected / "library-rows.json").write_text(json.dumps(snap, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    (expected / "prepare-checks.json").write_text(json.dumps(checks, indent=2) + "\n")
    (expected / "category-expectations.json").write_text(json.dumps(
        category_table(expectations, json.loads((data / "format-sources.json").read_text())["citations"]), indent=2, ensure_ascii=False) + "\n")
    for path in expected.iterdir():
        os.chmod(path, 0o644)

    # 6. Manifest.
    entries = []
    for fixture_rel, container, mode, action, purpose in FIXTURE_FILES:
        path = out / fixture_rel
        entries.append({"path": fixture_rel, "containerPath": container, "sha256": sha256_file(path), "size": path.stat().st_size,
                        "mode": "%04o" % mode_of(path), "action": action, "purpose": purpose})
    for path in sorted(expected.iterdir()):
        entries.append({"path": str(path.relative_to(out)), "containerPath": None, "sha256": sha256_file(path),
                        "size": path.stat().st_size, "mode": "%04o" % mode_of(path), "action": "evidence-only",
                        "purpose": "Source expectation or decoded value for review. Do not copy."})
    manifest = {
        "formatVersion": 1, "fixtureId": out.name, "createdUtc": utc_now(),
        "scope": "L27 full same-ID update rehearsal. Old-app formats only. Not the L25 fixture.",
        "probes": bool(args.probes),
        "tool": rel(Path(__file__)), "toolSha256": sha256_file(Path(__file__)),
        "dataBuilderSha256": sha256_file(HERE / "build-full-fixture-data.ts"),
        "mmkvCreatorSha256": sha256_file(REPO / "scripts/native/source-fixtures/l04/create-mmk-v2-fixture.cpp"),
        "mmkvDecoderSha256": sha256_file(HERE.parent / "l25" / "mmkv_decode.py"),
        "workFolder": rel(work),
        "removeBeforeCopy": REMOVE_BEFORE_COPY, "staleNativeDir": STALE_NATIVE_DIR,
        "files": entries,
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    with open(out / "manifest.tsv", "w") as handle:
        handle.write("path\tsha256\tmode\tsize\taction\tcontainerPath\tpurpose\n")
        for e in entries:
            handle.write("\t".join([e["path"], e["sha256"], e["mode"], str(e["size"]), e["action"], e["containerPath"] or "-", e["purpose"]]) + "\n")
    for name in ("manifest.json", "manifest.tsv"):
        os.chmod(out / name, 0o644)
    print("Fixture written: %s" % out)
    print("Work folder (build products, logs, not part of the manifest): %s" % work)
    for c in checks:
        print("%-6s %s %s" % ("OK" if c["ok"] else "FAIL", c["name"], c["detail"]))
    return 0


# ---------------------------------------------------------------------------------------------
# seed / verify
# ---------------------------------------------------------------------------------------------

def load_manifest(fixture):
    path = Path(fixture) / "manifest.json"
    if not path.exists():
        fail("manifest not found: %s" % path)
    return json.loads(path.read_text())


def check_manifest_pin(fixture, expected):
    if expected and sha256_file(Path(fixture) / "manifest.json") != expected:
        fail("manifest.json hash differs from --expect-manifest-sha256. Stop.")


def check_fixture_integrity(fixture, manifest):
    bad = []
    for entry in manifest["files"]:
        path = Path(fixture) / entry["path"]
        if not path.exists():
            bad.append("missing " + entry["path"])
        elif sha256_file(path) != entry["sha256"]:
            bad.append("changed " + entry["path"])
    return bad


def resolve_root(args):
    root = args.old_data_root
    app_bundle = args.app_bundle
    if args.udid:
        if not root:
            result = subprocess.run(["xcrun", "simctl", "get_app_container", args.udid, OLD_BUNDLE, "data"], capture_output=True, text=True)
            if result.returncode != 0:
                fail("simctl get_app_container (data) failed: %s" % result.stderr.strip())
            root = result.stdout.strip()
        if not app_bundle:
            result = subprocess.run(["xcrun", "simctl", "get_app_container", args.udid, OLD_BUNDLE, "app"], capture_output=True, text=True)
            if result.returncode != 0:
                fail("simctl get_app_container (app) failed: %s" % result.stderr.strip())
            app_bundle = result.stdout.strip()
        if "/Devices/%s/" % args.udid not in root:
            fail("data root is not under /Devices/%s/: %s" % (args.udid, root))
    if not root:
        fail("pass --old-data-root or --udid")
    root = Path(root).resolve()
    if not root.is_dir():
        fail("data root is not a folder: %s" % root)
    if not args.allow_nonsimulator_root and "/CoreSimulator/Devices/" not in str(root):
        fail("data root is not under CoreSimulator/Devices: %s" % root)
    metadata = root / ".com.apple.mobile_container_manager.metadata.plist"
    if not metadata.exists():
        fail("container metadata plist not found in %s" % root)
    identifier = plistlib.loads(metadata.read_bytes()).get("MCMMetadataIdentifier")
    if identifier != OLD_BUNDLE:
        fail("container belongs to %s, expected %s" % (identifier, OLD_BUNDLE))
    return root, (Path(app_bundle) if app_bundle else None)


def check_old_app_bundle(app_bundle, skip):
    """The installed app must be the old Expo build. A native build would load native state, not the seed."""
    if skip:
        return "skipped (--skip-app-check)"
    if app_bundle is None:
        fail("pass --udid or --app-bundle so the tool can check that the installed app is the old Expo build, or pass --skip-app-check")
    info = app_bundle / "Info.plist"
    if not info.exists():
        fail("installed app Info.plist not found: %s" % info)
    version = plistlib.loads(info.read_bytes())
    if not (app_bundle / "main.jsbundle").exists():
        fail("installed app has no main.jsbundle. It is not the old Expo build. Do not seed after the native install.")
    if (app_bundle / "App").exists() and (app_bundle / "App" / "Catalogs").exists():
        fail("installed app has native resources (App/Catalogs). Do not seed after the native install.")
    return "old Expo build %s (%s)" % (version.get("CFBundleShortVersionString"), version.get("CFBundleVersion"))


def container_state(root, entry):
    target = root / entry["containerPath"]
    if not target.exists():
        return "absent", None, None
    digest = sha256_file(target)
    return ("match" if digest == entry["sha256"] else "different"), digest, "%04o" % mode_of(target)


def stale_native_listing(root):
    folder = root / STALE_NATIVE_DIR
    if not folder.exists():
        return []
    return [{"path": str(p.relative_to(root)), "sha256": sha256_file(p), "mode": "%04o" % mode_of(p), "size": p.stat().st_size}
            for p in sorted(folder.rglob("*")) if p.is_file()]


def cmd_verify(args):
    fixture = Path(args.fixture)
    check_manifest_pin(fixture, args.expect_manifest_sha256)
    manifest = load_manifest(fixture)
    bad = check_fixture_integrity(fixture, manifest)
    if bad:
        fail("fixture integrity: " + "; ".join(bad))
    root, app_bundle = resolve_root(args)
    print("Installed app: %s" % check_old_app_bundle(app_bundle, args.skip_app_check))
    problems = 0
    for entry in manifest["files"]:
        if entry["containerPath"] is None:
            continue
        state, _, mode = container_state(root, entry)
        ok = state == "match" and mode == entry["mode"]
        problems += 0 if ok else 1
        print("%-8s %-10s mode=%s (want %s)  %s" % ("OK" if ok else "PROBLEM", state, mode, entry["mode"], entry["containerPath"]))
    for relpath in manifest["removeBeforeCopy"]:
        if (root / relpath).exists():
            problems += 1
            print("PROBLEM  stale file present: %s" % relpath)
    stale = stale_native_listing(root)
    if (root / STALE_NATIVE_DIR).exists():
        problems += 1
        print("PROBLEM  stale native state folder present (%d files). A native build would load it: %s" % (len(stale), STALE_NATIVE_DIR))
        for item in stale:
            print("         %s %s %s" % (item["sha256"][:12], item["mode"], item["path"]))
    else:
        print("OK       native state folder absent: %s" % STALE_NATIVE_DIR)
    print("Byte check only. Run it before the first launch of the old app. A launch changes MMKV, the WAL, and the SHM.")
    return 1 if problems else 0


def cmd_seed(args):
    fixture = Path(args.fixture)
    if args.apply and not args.expect_manifest_sha256:
        fail("--apply needs --expect-manifest-sha256.")
    if args.apply and args.skip_app_check and not args.allow_nonsimulator_root:
        fail("--skip-app-check is not allowed with --apply on a simulator container.")
    check_manifest_pin(fixture, args.expect_manifest_sha256)
    manifest = load_manifest(fixture)
    bad = check_fixture_integrity(fixture, manifest)
    if bad:
        fail("fixture integrity: " + "; ".join(bad))
    root, app_bundle = resolve_root(args)
    print("MODE: %s" % ("APPLY" if args.apply else "DRY RUN (nothing will change)"))
    print("Installed app: %s" % check_old_app_bundle(app_bundle, args.skip_app_check))
    if args.apply and not args.confirm_apps_stopped:
        fail("--apply needs --confirm-apps-stopped. Main must stop the old app first.")
    if args.apply and not args.report_dir:
        fail("--apply needs --report-dir (a new folder for the backup and report).")
    report_dir = Path(args.report_dir).resolve() if args.report_dir else None
    if args.apply:
        if report_dir.exists():
            fail("report dir exists. Use a new path: %s" % report_dir)
        require_under_l27(report_dir, "--report-dir")
    plan = []
    stale = stale_native_listing(root)
    if (root / STALE_NATIVE_DIR).exists():
        plan.append(("move-stale-native-dir", STALE_NATIVE_DIR, None))
    for relpath in manifest["removeBeforeCopy"]:
        if (root / relpath).exists():
            plan.append(("remove", relpath, None))
    for entry in manifest["files"]:
        if entry["containerPath"] is None:
            continue
        state, _, mode = container_state(root, entry)
        if state == "match":
            if mode != entry["mode"]:
                plan.append(("chmod", entry["containerPath"], entry))
            continue
        plan.append(("copy", entry["containerPath"], entry))
    for dirname in WRITABLE_DIRS:
        path = root / dirname
        if path.exists() and not os.access(path, os.W_OK):
            plan.append(("chmod-dir", dirname, None))
    for action, relpath, _ in plan:
        print("PLAN  %-22s %s" % (action, relpath))
    if stale:
        print("STALE NATIVE STATE (%d files) will be moved to the report folder and recorded:" % len(stale))
        for item in stale:
            print("      %s %s %s" % (item["sha256"][:12], item["mode"], item["path"]))
    if not args.apply:
        print("DRY RUN: nothing changed. Add --apply --confirm-apps-stopped --report-dir <new folder below build/native-evidence/L27>.")
        return 0

    report_dir.mkdir(parents=True)
    backups = []
    done = []

    def backup(relpath):
        source = root / relpath
        if not source.exists():
            return
        dest = report_dir / "before" / relpath
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        backups.append({"path": relpath, "sha256": sha256_file(source), "mode": "%04o" % mode_of(source), "size": source.stat().st_size,
                        "backup": rel(dest)})

    for action, relpath, _ in plan:
        if action == "chmod-dir":
            os.chmod(root / relpath, mode_of(root / relpath) | 0o700)
            done.append({"action": action, "path": relpath})
    for dirname in WRITABLE_DIRS:
        (root / dirname).mkdir(parents=True, exist_ok=True)
    for action, relpath, entry in plan:
        if action == "move-stale-native-dir":
            for item in stale:
                backup(item["path"])
            shutil.rmtree(root / STALE_NATIVE_DIR)
        elif action == "remove":
            backup(relpath)
            os.remove(root / relpath)
        elif action == "chmod":
            os.chmod(root / relpath, int(entry["mode"], 8))
        elif action == "copy":
            backup(relpath)
            target = root / relpath
            temp = target.with_name(target.name + ".l27tmp")
            shutil.copyfile(fixture / entry["path"], temp)
            os.chmod(temp, int(entry["mode"], 8))
            os.replace(temp, target)
        done.append({"action": action, "path": relpath})
    results = []
    problems = 0
    for entry in manifest["files"]:
        if entry["containerPath"] is None:
            continue
        state, digest, mode = container_state(root, entry)
        ok = state == "match" and mode == entry["mode"]
        problems += 0 if ok else 1
        results.append({"path": entry["containerPath"], "state": state, "sha256": digest, "mode": mode, "wantMode": entry["mode"], "ok": ok})
        print("%-8s %-9s mode=%s %s" % ("OK" if ok else "PROBLEM", state, mode, entry["containerPath"]))
    if (root / STALE_NATIVE_DIR).exists():
        problems += 1
        print("PROBLEM  stale native state folder still present")
    else:
        print("OK       native state folder absent")
    (report_dir / "seed-report.json").write_text(json.dumps({
        "fixture": rel(fixture), "manifestSha256": sha256_file(fixture / "manifest.json"), "toolSha256": sha256_file(Path(__file__)),
        "dataRoot": str(root), "utc": utc_now(), "operations": done, "backups": backups,
        "staleNativeFilesMovedAway": stale, "verify": results}, indent=2, sort_keys=True) + "\n")
    print("Report: %s" % (report_dir / "seed-report.json"))
    return 1 if problems else 0


# ---------------------------------------------------------------------------------------------
# comparator input helpers (copies only)
# ---------------------------------------------------------------------------------------------

def file_meta(path):
    if not path.exists():
        return {"exists": False, "sha256": None, "sizeBytes": None}
    return {"exists": True, "sha256": sha256_file(path), "sizeBytes": path.stat().st_size}


def cmd_export_old(args):
    tree = require_under_l27(args.data_tree, "--data-tree")
    out = Path(args.out).resolve()
    require_under_l27(out.parent, "--out parent")
    if out.exists():
        fail("output exists: %s" % out)
    for path in (tree / "Documents/mmkv/mmkv.default", tree / "Documents/mmkv/mmkv.default.crc", tree / "Documents/SQLite/user-library.db"):
        if not path.exists():
            fail("missing in copied tree: %s" % path)
    decoded = mmkv_decode.decode(str(tree / "Documents/mmkv/mmkv.default"), str(tree / "Documents/mmkv/mmkv.default.crc"))
    if not decoded["crcOK"]:
        fail("MMKV CRC does not match in the copied tree")
    plist_path = tree / "Library/Preferences/group.com.nrsv.verse.plist"
    widget = {}
    if plist_path.exists():
        for key, value in plistlib.loads(plist_path.read_bytes()).items():
            kind = "string" if isinstance(value, str) else "boolean" if isinstance(value, bool) else "number" if isinstance(value, (int, float)) else "other"
            widget[key] = {"type": kind, "value": value}
    library = snapshot_library(tree / "Documents/SQLite/user-library.db")
    pending = json.loads(Path(args.pending_requests).read_text()) if args.pending_requests else []
    data = {
        "formatVersion": 1, "kind": "l27-copied-old-source-export", "capturedAt": args.captured_at or utc_now(),
        "provenance": {
            "captureKind": args.capture_kind, "bundleID": args.bundle_id, "appVersion": args.app_version, "appBuild": args.app_build,
            "processID": args.process_id, "appGroupIdentifier": args.app_group,
            "signedEntitlementGroups": [g for g in (args.signed_groups or "").split(",") if g],
            "mmkvRoot": "Documents/mmkv",
        },
        "protectedFiles": {
            "user-library.db": file_meta(tree / "Documents/SQLite/user-library.db"),
            "user-library.db-wal": file_meta(tree / "Documents/SQLite/user-library.db-wal"),
            "user-library.db-shm": file_meta(tree / "Documents/SQLite/user-library.db-shm"),
            "mmkv/data": file_meta(tree / "Documents/mmkv/mmkv.default"),
            "mmkv/crc": file_meta(tree / "Documents/mmkv/mmkv.default.crc"),
        },
        "rawMMKVStrings": decoded["keys"],
        "widgetScalars": widget,
        "pendingRequests": pending,
        "library": library,
    }
    if any(isinstance(v, str) and v.startswith("rawHex:") for v in decoded["keys"].values()):
        fail("MMKV holds a non-string value. The comparator needs string values.")
    out.write_text(json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    print("Wrote %s (%d MMKV keys, rows: %s)" % (out, len(decoded["keys"]),
          {t: len(library["tables"][t]["rows"]) for t in TABLES}))
    return 0


def cmd_wrap_envelope(args):
    source = require_under_l27(args.envelope, "--envelope")
    out = Path(args.out).resolve()
    require_under_l27(out.parent, "--out parent")
    if out.exists():
        fail("output exists: %s" % out)
    raw = source.read_bytes()
    envelope = json.loads(raw)
    reminder = (envelope.get("state", {}).get("rosaryReminder") or {}).get("notificationID")
    if not reminder:
        fail("the envelope has no rosaryReminder.notificationID")
    unknown = [k for k in (args.unknown_keys or "").split(",") if k]
    data = {"formatVersion": 1, "kind": "l27-copied-native-envelope", "envelopeSHA256": hashlib.sha256(raw).hexdigest(),
            "rawEnvelopeBase64": base64.b64encode(raw).decode("ascii"), "envelope": envelope,
            "importedReminderID": reminder, "preservedUnknownLegacyKeys": unknown}
    out.write_text(json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    print("Wrote %s (envelope sha256 %s, revision %s)" % (out, data["envelopeSHA256"][:12], envelope.get("revision")))
    return 0


def cmd_inspect_recovery(args):
    source = require_under_l27(args.recovery_db, "--recovery-db")
    out = Path(args.out).resolve()
    require_under_l27(out.parent, "--out parent")
    if out.exists():
        fail("output exists: %s" % out)
    for suffix in ("-wal", "-shm", "-journal"):
        if Path(str(source) + suffix).exists():
            fail("the recovery copy has a %s sidecar" % suffix)
    snap = snapshot_library(source, with_sidecars=False)
    data = {"formatVersion": 1, "kind": "l27-recovery-inspection", "recovery": {
        "pathRelative": str(source.relative_to(L27.resolve())),
        "fileSHA256": sha256_file(source), "schemaVersion": snap["schemaVersion"], "journalMode": snap["journalMode"],
        "integrityCheck": snap["integrityCheck"], "tables": snap["tables"]}}
    out.write_text(json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    print("Wrote %s (journal %s, integrity %s)" % (out, snap["journalMode"], snap["integrityCheck"]))
    return 0


# Values that a real old-app action changes. Each maps to one native path and one native value.
def native_value_for(key, raw):
    parsed = json.loads(raw)
    if key == "bible.reader.location":
        return "/readerLocation", {"bookCode": parsed["book"], "chapter": parsed["chapter"], "scrollY": parsed["scrollY"],
                                   "updatedAt": parsed.get("updatedAt", 0), "anchor": None}
    if key == "rosary.reminder.v1":
        return "/rosaryReminder", {"enabled": parsed["enabled"], "frequency": parsed["frequency"], "hour": parsed["hour"],
                                   "minute": parsed["minute"], "weekday": parsed["weekday"],
                                   "notificationID": parsed.get("notificationId")}
    if key == "john.calendar-notifications.v1":
        return "/calendarNotifications", {"enabled": parsed["enabled"], "hour": parsed["hour"], "minute": parsed["minute"]}
    if key == "works.position.v1":
        return "/worksPositions", parsed
    return None


def cmd_mapping(args):
    source = json.loads(require_under_l27(args.source_expectations, "--source-expectations").read_text())
    before = json.loads(require_under_l27(args.before_export, "--before-export").read_text())
    out = Path(args.out).resolve()
    require_under_l27(out.parent, "--out parent")
    if out.exists():
        fail("output exists: %s" % out)
    expected = source["rawLegacyMMKVStrings"]
    actual = before["rawMMKVStrings"]
    state_overrides, raw_overrides, refused = [], [], []
    for key in sorted(set(expected) | set(actual)):
        if expected.get(key) == actual.get(key):
            continue
        mapped = native_value_for(key, actual[key]) if key in actual else None
        if mapped is None:
            refused.append(key)
            continue
        path, value = mapped
        reason = args.reason
        state_overrides.append({"sourceKey": key, "expectedRawValue": actual[key], "nativePath": path, "expectedNativeValue": value,
                                "reason": reason, "authority": args.review_authority})
        raw_overrides.append({"key": key, "expectedBefore": actual[key], "reason": reason, "authority": args.review_authority})
    if refused:
        fail("these keys differ and have no allowed mapping: %s" % ", ".join(refused))
    # Native-wins changes: a value that the native app changed after the import. The legacy raw value stays as it was.
    for item in args.native_override or []:
        try:
            key, path, value = item.split("::", 2)
            native_value = json.loads(value)
        except ValueError:
            fail("--native-override needs KEY::/native/path::JSON_VALUE")
        if key not in actual:
            fail("native override key is not in the before export: %s" % key)
        state_overrides.append({"sourceKey": key, "expectedRawValue": actual[key], "nativePath": path,
                                "expectedNativeValue": native_value,
                                "reason": "Native-wins change after the import. The legacy raw value stays unchanged.",
                                "authority": args.review_authority})
    data = {"formatVersion": 1, "kind": "l27-reviewed-expectation-mapping", "reviewAuthority": args.review_authority,
            "stateOverrides": state_overrides, "rawLegacyOverrides": raw_overrides}
    if args.stage and args.revision is not None:
        data["envelopeRevisionExpectation"] = {"stage": args.stage, "expectedRevision": args.revision, "authority": args.review_authority}
    out.write_text(json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    print("Wrote %s (%d overrides: %s)" % (out, len(state_overrides), ", ".join(o["sourceKey"] for o in state_overrides) or "none"))
    return 0


# ---------------------------------------------------------------------------------------------
# host-run: the real JohnCore importer on macOS, on copies of the fixture (no simulator)
# ---------------------------------------------------------------------------------------------

DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer"
DEFAULT_RESOURCES = EVIDENCE / "L03" / "staged" / "run-10" / "App"
INTERRUPT_CHECKPOINTS = ["beforeStaging", "beforeDurableCommit", "afterPrimaryRename", "afterDurableCommit"]


def tool_env():
    env = dict(os.environ)
    env["DEVELOPER_DIR"] = DEVELOPER_DIR
    return env


def run_json(cmd, log, env=None, expect_rc=0):
    with open(log, "w") as handle:
        result = subprocess.run(cmd, stdout=handle, stderr=subprocess.STDOUT, env=env)
    if result.returncode != expect_rc:
        fail("command returned %s, expected %s (%s). See %s" % (result.returncode, expect_rc, cmd[1] if len(cmd) > 1 else cmd[0], log))
    return result.returncode


def copy_container(source, dest):
    # The importer never reads bible-search.db. Skip the 33 MB copy.
    shutil.copytree(source, dest, copy_function=shutil.copy2, ignore=shutil.ignore_patterns("bible-search.db"))
    for directory in [dest] + [p for p in dest.rglob("*") if p.is_dir()]:
        os.chmod(directory, 0o755)


def state_listing(container):
    folder = container / STALE_NATIVE_DIR
    files = {}
    for name in ("native-state-v1.json", "native-state-v1.previous.json"):
        path = folder / name
        files[name] = sha256_file(path) if path.exists() else "absent"
    recovery = folder / "recovery"
    return {"stateFiles": files, "recoveryFiles": sorted(p.name for p in recovery.glob("*")) if recovery.exists() else []}


def project_state(state):
    """Same projection as the comparator: no null anchor, unwrap Works fields."""
    state = json.loads(json.dumps(state))
    state.pop("legacyUnknownKeys", None)
    if state.get("themeScheme") is None:
        state.pop("themeScheme", None)
    loc = state.get("readerLocation")
    if loc is not None and loc.get("anchor") is None:
        loc.pop("anchor", None)
    for work, position in (state.get("worksPositions") or {}).items():
        if isinstance(position, dict) and "fields" in position:
            state["worksPositions"][work] = position["fields"]
    return state


def cmd_host_run(args):
    fixture = Path(args.fixture).resolve()
    manifest = load_manifest(fixture)
    bad = check_fixture_integrity(fixture, manifest)
    if bad:
        fail("fixture integrity: " + "; ".join(bad))
    out = Path(args.out).resolve()
    require_under_l27(out.parent, "--out parent")
    if out.exists():
        fail("output exists: %s" % out)
    resources = Path(args.resources).resolve()
    catalog = resources / "Catalogs" / "devotional-catalogs.json"
    if not catalog.exists():
        fail("resource folder has no Catalogs/devotional-catalogs.json: %s" % resources)
    out.mkdir(parents=True)
    expectations = json.loads((fixture / "expected/source-expectations.json").read_text())
    expected_state = expectations["expectedNativeState"]
    legacy = fixture / "expected/old-mmkv-decoded.json"
    base = fixture / "old" / OLD_BUNDLE

    # Build the harness. The scratch path stays outside the repository package folder.
    scratch = L27 / "_host-importer-build"  # shared build products; not part of any evidence
    run(["/usr/bin/xcrun", "swift", "build", "--package-path", str(HERE / "host-importer"), "--scratch-path", str(scratch)],
        out / "swift-build.log", env=tool_env())
    harness = scratch / "debug" / "L27HostImporter"
    if not harness.exists():
        fail("harness binary not found")
    common = ["--resources", str(resources), "--legacy", str(legacy)]
    summary = {"harnessSha256": sha256_file(harness), "resources": rel(resources), "resourceCatalogSha256": sha256_file(catalog),
               "fixtureManifestSha256": sha256_file(fixture / "manifest.json"), "toolSha256": sha256_file(Path(__file__)),
               "hostOnly": True, "simulatorUsed": False}

    # ---- Main sequence: first import, restart, native change, restart, repeat update.
    main_dir = out / "main"
    main_dir.mkdir()
    copy_container(base, main_dir / "before-tree")
    copy_container(base, main_dir / "container")
    run_json([str(harness), "stages", "--container", str(main_dir / "container"), "--out", str(main_dir / "stages")] + common,
             main_dir / "stages.log", env=tool_env())
    report = json.loads((main_dir / "stages" / "stages-report.json").read_text())
    pristine = {name: sha256_file(base / name.replace("Documents/", "Documents/")) for name in report["beforeProtected"]}
    envelopes = {n: json.loads((main_dir / "stages" / ("stage%d-native-state-v1.json" % n)).read_text()) for n in (1, 2, 3, 4)}
    mmkv_hashes = {"mmkv.default": pristine["Documents/mmkv/mmkv.default"], "mmkv.default.crc": pristine["Documents/mmkv/mmkv.default.crc"]}
    expected_rows = expectations["sourceLibrary"]["rowCounts"]
    checks = []

    def check(name, ok, detail=""):
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    s1, s2, s3, s4 = (report[k] for k in ("stage1FirstImport", "stage2NativeWinsRestart", "stage3AfterChangeRestart", "stage4RepeatUpdate"))
    check("stage1 revision 1", s1["revision"] == 1 and envelopes[1]["revision"] == 1 and envelopes[1]["importVersion"] == 1)
    check("stage1 state equals source expectation", project_state(envelopes[1]["state"]) == project_state(expected_state))
    check("stage1 importSourceHashes equal MMKV file hashes", envelopes[1]["importSourceHashes"] == mmkv_hashes)
    check("stage1 issues empty", envelopes[1]["issues"] == [])
    check("stage1 one recovery backup", len(s1["recoveryFiles"]) == 1)
    check("stage1 no previous envelope", s1["stateFiles"]["native-state-v1.previous.json"] == "absent")
    check("stage2 restart keeps revision 1 and the same envelope bytes",
          s2["revision"] == 1 and s2["stateFiles"] == s1["stateFiles"] and s2["recoveryFiles"] == s1["recoveryFiles"])
    expected_after_change = json.loads(json.dumps(project_state(expected_state)))
    expected_after_change["readingPreferences"]["textSize"] = "large"
    check("stage3 native change: revision 2, only textSize changed",
          s3["revision"] == 2 and project_state(envelopes[3]["state"]) == expected_after_change and report["stage3NativeChangeRevision"] == 2)
    check("stage3 previous envelope equals stage1 primary", s3["stateFiles"]["native-state-v1.previous.json"] == s1["stateFiles"]["native-state-v1.json"])
    check("stage3 importSourceHashes unchanged", envelopes[3]["importSourceHashes"] == mmkv_hashes)
    check("stage4 repeat update: same envelope bytes, no new backup",
          s4["revision"] == 2 and s4["stateFiles"] == s3["stateFiles"] and s4["recoveryFiles"] == s1["recoveryFiles"])
    after = report["afterProtected"]
    changed = sorted(n for n in after if after[n] != report["beforeProtected"][n])
    check("protected files: only the SHM changed", changed in ([], ["Documents/SQLite/user-library.db-shm"]), "changed: %s" % changed)
    summary["protectedFilesChanged"] = changed

    # ---- Interruption boundaries (child process killed with SIGKILL at each checkpoint).
    interrupts = {}
    for checkpoint in INTERRUPT_CHECKPOINTS:
        folder = out / "interrupt" / checkpoint
        folder.mkdir(parents=True)
        container = folder / "container"
        copy_container(base, container)
        with open(folder / "die.log", "w") as handle:
            result = subprocess.run([str(harness), "die-at", "--checkpoint", checkpoint, "--container", str(container)] + common,
                                    stdout=handle, stderr=subprocess.STDOUT, env=tool_env())
        killed = result.returncode == -9
        after_kill = state_listing(container)
        run_json([str(harness), "resume", "--container", str(container), "--out", str(folder / "resume-1.json")] + common,
                 folder / "resume-1.log", env=tool_env())
        run_json([str(harness), "resume", "--container", str(container), "--out", str(folder / "resume-2.json")] + common,
                 folder / "resume-2.log", env=tool_env())
        r1 = json.loads((folder / "resume-1.json").read_text())
        r2 = json.loads((folder / "resume-2.json").read_text())
        envelope = json.loads((container / STALE_NATIVE_DIR / "native-state-v1.json").read_text())
        interrupts[checkpoint] = {
            "processKilledBySIGKILL": killed, "afterKill": after_kill,
            "resume1": {k: r1[k] for k in ("revision", "hasEnvelope", "stateFiles", "recoveryFiles", "nativeStateCapability")},
            "resume2": {k: r2[k] for k in ("revision", "hasEnvelope", "stateFiles", "recoveryFiles")},
            "finalStateEqualsExpectation": project_state(envelope["state"]) == project_state(expected_state),
            "finalRevision": envelope["revision"],
        }
        check("interrupt %s: killed" % checkpoint, killed)
        check("interrupt %s: final revision 1 and state equals expectation" % checkpoint,
              envelope["revision"] == 1 and interrupts[checkpoint]["finalStateEqualsExpectation"])
        check("interrupt %s: second start is stable" % checkpoint, r2["stateFiles"] == r1["stateFiles"] and r2["recoveryFiles"] == r1["recoveryFiles"])
    folder = out / "interrupt" / "failureAfterPrimaryRename"
    folder.mkdir(parents=True)
    copy_container(base, folder / "container")
    run_json([str(harness), "resume", "--container", str(folder / "container"), "--inject-after-rename", "--out", str(folder / "resume-1.json")] + common,
             folder / "resume-1.log", env=tool_env())
    run_json([str(harness), "resume", "--container", str(folder / "container"), "--out", str(folder / "resume-2.json")] + common,
             folder / "resume-2.log", env=tool_env())
    f1 = json.loads((folder / "resume-1.json").read_text())
    f2 = json.loads((folder / "resume-2.json").read_text())
    envelope = json.loads((folder / "container" / STALE_NATIVE_DIR / "native-state-v1.json").read_text())
    interrupts["failureAfterPrimaryRename"] = {
        "resume1": {k: f1[k] for k in ("revision", "hasEnvelope", "stateFiles", "recoveryFiles", "nativeStateCapability")},
        "resume2": {k: f2[k] for k in ("revision", "hasEnvelope", "stateFiles", "recoveryFiles")},
        "finalRevision": envelope["revision"], "finalStateEqualsExpectation": project_state(envelope["state"]) == project_state(expected_state)}
    check("failure after primary rename: restart loads revision 1 and equals expectation",
          envelope["revision"] == 1 and interrupts["failureAfterPrimaryRename"]["finalStateEqualsExpectation"] and f2["revision"] == 1)

    # ---- Stale native state: the blocker. A native build loads it and skips the import.
    stale_dir = out / "stale-state-probe"
    stale_dir.mkdir()
    stale_container = stale_dir / "container"
    copy_container(base, stale_container)
    stale_source = EVIDENCE / "L25" / "preserve-prod-native-before-baseline-01" / "DataContainer" / STALE_NATIVE_DIR
    target = stale_container / STALE_NATIVE_DIR
    target.mkdir(parents=True)
    for name in ("native-state-v1.json", "native-state-v1.previous.json"):
        shutil.copyfile(stale_source / name, target / name)
        os.chmod(target / name, 0o600)
    run_json([str(harness), "resume", "--container", str(stale_container), "--out", str(stale_dir / "resume.json")] + common,
             stale_dir / "resume.log", env=tool_env())
    probe = json.loads((stale_dir / "resume.json").read_text())
    stale_env = json.loads((target / "native-state-v1.json").read_text())
    summary["staleStateProbe"] = {
        "staleFilesCopiedFrom": rel(stale_source),
        "revisionLoaded": probe["revision"], "importSourceHashesKeys": sorted(probe["importSourceHashes"].keys()),
        "readerLocationLoaded": stale_env["state"].get("readerLocation"), "recoveryFiles": probe["recoveryFiles"],
        "recoveryFilesAfterProbe": probe["recoveryFiles"],
    }
    check("stale native state is loaded instead of the import (probe)",
          project_state(stale_env["state"]).get("readerLocation", {}).get("bookCode") == "PSA")

    # ---- Comparator wiring.
    compare = out / "compare"
    compare.mkdir()
    py = [sys.executable, str(Path(__file__))]
    run_json(py + ["export-old", "--data-tree", str(main_dir / "before-tree"), "--out", str(compare / "old-source-before.json"),
                   "--capture-kind", "helper-only-synthetic", "--app-version", "host-run", "--app-build", "0",
                   "--process-id", str(os.getpid())], compare / "export-before.log")
    run_json(py + ["export-old", "--data-tree", str(main_dir / "container"), "--out", str(compare / "old-source-after.json"),
                   "--capture-kind", "helper-only-synthetic", "--app-version", "host-run", "--app-build", "0",
                   "--process-id", str(os.getpid())], compare / "export-after.log")
    recovery_name = s1["recoveryFiles"][0]
    recovery_dir = compare / "recovery"
    recovery_dir.mkdir()
    shutil.copyfile(main_dir / "container" / STALE_NATIVE_DIR / "recovery" / recovery_name, recovery_dir / "user-library.backup.db")
    run_json(py + ["inspect-recovery", "--recovery-db", str(recovery_dir / "user-library.backup.db"),
                   "--out", str(compare / "recovery-inspect.json")], compare / "inspect-recovery.log")
    mapping_path = compare / "mapping-native-change.json"
    run_json(py + ["mapping", "--source-expectations", str(fixture / "expected/source-expectations.json"),
                   "--before-export", str(compare / "old-source-before.json"), "--out", str(mapping_path),
                   "--review-authority", "host-run helper-only (no review)", "--stage", "native-wins revision 2", "--revision", "2",
                   "--native-override", 'bible.reader.textSize::/readingPreferences/textSize::"large"'], compare / "mapping.log")
    results = {}
    stage_inputs = {"stage1FirstImport": (1, None, "strict"), "stage1FirstImportShmVolatile": (1, None, "volatile"),
                    "stage2NativeWinsRestart": (2, None, "volatile"), "stage3NativeChange": (3, mapping_path, "volatile"),
                    "stage4RepeatUpdate": (4, mapping_path, "volatile")}
    for label, (number, mapping_file, policy) in stage_inputs.items():
        env_dir = compare / ("envelope-%s.json" % label)
        run_json(py + ["wrap-envelope", "--envelope", str(main_dir / "stages" / ("stage%d-native-state-v1.json" % number)),
                       "--out", str(env_dir), "--unknown-keys", ",".join(expected_state.get("legacyUnknownKeys", []))], compare / ("wrap-%s.log" % label))
        cmd = ["bun", str(HERE / "compare-update-evidence.ts"), "--source-expectations", str(fixture / "expected/source-expectations.json"),
               "--before-export", str(compare / "old-source-before.json"), "--after-export", str(compare / "old-source-after.json"),
               "--native-envelope", str(env_dir), "--recovery-db", str(recovery_dir / "user-library.backup.db"),
               "--recovery-inspect", str(compare / "recovery-inspect.json"), "--output", str(compare / ("report-%s" % label)),
               "--shm-policy", policy]
        if mapping_file:
            cmd += ["--expectation-mapping", str(mapping_file)]
        with open(compare / ("compare-%s.log" % label), "w") as handle:
            rc = subprocess.run(cmd, stdout=handle, stderr=subprocess.STDOUT, cwd=REPO).returncode
        report_json = json.loads((compare / ("report-%s" % label) / "comparison-report.json").read_text())
        results[label] = {"exitCode": rc, "result": report_json["result"], "shmPolicy": report_json.get("shmPolicy", "strict"),
                          "counts": report_json["counts"], "failed": report_json["failedRequiredChecks"]}
    summary["comparator"] = results
    summary["checks"] = checks
    summary["interruptions"] = interrupts
    summary["stages"] = {"stage1FirstImport": s1, "stage2NativeWinsRestart": s2, "stage3AfterChangeRestart": s3, "stage4RepeatUpdate": s4}
    (out / "host-run-summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    print("Host run written: %s" % out)
    for c in checks:
        print("%-6s %s %s" % ("OK" if c["ok"] else "FAIL", c["name"], c["detail"]))
    for label, r in results.items():
        print("comparator %-30s %s (required failed or unavailable: %s) %s" % (
            label, r["result"], r["counts"]["requiredFailedOrUnavailableCount"], [f["id"] for f in r["failed"]]))
    return 0 if all(c["ok"] for c in checks) else 1


# ---------------------------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("prepare")
    p.add_argument("--out", default=str(DEFAULT_FIXTURE))
    p.add_argument("--probes", action="store_true", help="add two non-old-app preservation probes (extra Works field, unknown key)")
    p.set_defaults(func=cmd_prepare)

    for name, func in (("verify", cmd_verify), ("seed", cmd_seed)):
        p = sub.add_parser(name)
        p.add_argument("--fixture", default=str(DEFAULT_FIXTURE))
        p.add_argument("--old-data-root")
        p.add_argument("--app-bundle", help="installed old app .app folder (for the old-build check)")
        p.add_argument("--udid", help="simulator UDID. Only then the tool runs `xcrun simctl get_app_container` (read only query).")
        p.add_argument("--skip-app-check", action="store_true")
        p.add_argument("--expect-manifest-sha256", help="stop if manifest.json has another SHA-256")
        p.add_argument("--allow-nonsimulator-root", action="store_true", help="for tests on a fake container tree")
        if name == "seed":
            p.add_argument("--apply", action="store_true")
            p.add_argument("--confirm-apps-stopped", action="store_true")
            p.add_argument("--report-dir")
        p.set_defaults(func=func)

    p = sub.add_parser("export-old")
    p.add_argument("--data-tree", required=True, help="COPIED old container tree below build/native-evidence/L27")
    p.add_argument("--out", required=True)
    p.add_argument("--capture-kind", choices=["main-copied-old-app", "helper-only-synthetic"], required=True)
    p.add_argument("--bundle-id", default=OLD_BUNDLE)
    p.add_argument("--app-version", required=True)
    p.add_argument("--app-build", required=True)
    p.add_argument("--process-id", type=int, required=True)
    p.add_argument("--app-group", default="group.com.nrsv.verse")
    p.add_argument("--signed-groups", help="comma separated; observation only")
    p.add_argument("--pending-requests", help="JSON file with observed pending requests (optional)")
    p.add_argument("--captured-at")
    p.set_defaults(func=cmd_export_old)

    p = sub.add_parser("wrap-envelope")
    p.add_argument("--envelope", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--unknown-keys", default="")
    p.set_defaults(func=cmd_wrap_envelope)

    p = sub.add_parser("inspect-recovery")
    p.add_argument("--recovery-db", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(func=cmd_inspect_recovery)

    p = sub.add_parser("mapping")
    p.add_argument("--source-expectations", required=True)
    p.add_argument("--before-export", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--review-authority", required=True)
    p.add_argument("--reason", default="The old app changed this value during a recorded action before the update.")
    p.add_argument("--stage")
    p.add_argument("--revision", type=int)
    p.add_argument("--native-override", action="append", help="KEY::/native/path::JSON_VALUE (repeatable)")
    p.set_defaults(func=cmd_mapping)

    p = sub.add_parser("host-run", help="run the real JohnCore importer on macOS against fixture copies (no simulator)")
    p.add_argument("--fixture", default=str(DEFAULT_FIXTURE))
    p.add_argument("--out", required=True, help="new folder below build/native-evidence/L27")
    p.add_argument("--resources", default=str(DEFAULT_RESOURCES), help="staged App resource folder (needs Catalogs/devotional-catalogs.json)")
    p.set_defaults(func=cmd_host_run)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
