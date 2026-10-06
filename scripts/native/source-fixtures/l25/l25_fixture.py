#!/usr/bin/env python3
"""L25 matched capture fixture: prepare, check, verify, and seed.

This tool keeps the L25 paired-capture fixture apart from the L27 update fixture.
It uses only the Python standard library.

Commands
  prepare  Build a new fixture folder from copied evidence. Refuses an existing output folder.
  check    Compare the logical saved state of two copied data trees (old app and native app).
  verify   Compare the bytes and modes of the files in two app containers with the fixture manifest.
  seed     Copy the fixture into the two app containers. Dry run by default.

Simulator rules
  The tool never boots, installs, launches, or terminates anything.
  `seed` and `verify` change or read only the two data-container paths that Main supplies.
  The tool calls `xcrun simctl get_app_container` only when Main passes --udid.
  Main must stop both apps before `seed --apply`.
"""
import argparse
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
sys.path.insert(0, str(HERE))
import mmkv_decode  # noqa: E402

REPO = HERE.parents[3]
EVIDENCE = REPO / "build" / "native-evidence"
DEFAULT_FIXTURE = EVIDENCE / "L25" / "capture-fixture-01"
OLD_BUNDLE = "com.nrsv.verse"
NATIVE_BUNDLE = "com.nrsv.verse.dev"

# Frozen and observed inputs. Each hash was measured on 6 October 2026.
OLD_SOURCE_ROOT = EVIDENCE / "L00" / "synthetic-legacy-fixture"
OLD_INPUTS = {
    "Documents/SQLite/bible-search.db": "e2ee48c4edaeeaa5c6b340af35e32b228563c3191ca55453340dfd9b8fe1fd94",
    "Documents/SQLite/user-library.db": "827c7badbcf2315b1f2509cef0d22d2c05d6bb3717d086fd7dd27a161ab39e23",
    "Documents/mmkv/mmkv.default": "750151a47be02532926c160c6854b57b06ee117a9f7a0647f44d79856ca8cca4",
    "Documents/mmkv/mmkv.default.crc": "6f3e7ca99b9cd71f889aec7e824e1eb5b44f82da611f5eebe4ac8ea35d1f4262",
    "Library/Preferences/group.com.nrsv.verse.plist": "f61f300fd1b031110968e9317cdf1ec3ef03e5d7a8d602b07e1c0467503be7de",
}
NATIVE_SOURCE_ROOT = EVIDENCE / "L22" / "positive-notice-native-dev-02" / "data-after"
NATIVE_DB_SOURCE = NATIVE_SOURCE_ROOT / "AppData" / "Documents" / "SQLite" / "user-library.db"
NATIVE_DB_SOURCE_SHA = "12570cd7535e223f79d3f8cb0a6793d6dd8a64e91b683896c37b74ec356b257f"
NATIVE_ENVELOPE_SOURCE = NATIVE_SOURCE_ROOT / "AppData" / "Library" / "Application Support" / "John" / "native-state-v1.json"
NATIVE_ENVELOPE_SOURCE_SHA = "baba821db53b5fa456d75ec689d7756739804b11659095fd3c75abcc40f350c4"
NATIVE_GROUP_SOURCE = NATIVE_SOURCE_ROOT / "AppGroup" / "Library" / "Preferences" / "group.com.nrsv.verse.dev.plist"
NATIVE_GROUP_SOURCE_SHA = "f61f300fd1b031110968e9317cdf1ec3ef03e5d7a8d602b07e1c0467503be7de"

# The newest old-app and native evidence copies. They show the state before this fixture.
STALE_OLD_TREE = EVIDENCE / "L25" / "baseline-john1-parity-01" / "data-after"
STALE_NATIVE_TREE = NATIVE_SOURCE_ROOT / "AppData"

TABLES = ("bookmarks", "highlights", "notes")
TABLE_KEYS = {"bookmarks": "passage_key", "highlights": "verse_key", "notes": "passage_key"}

# Source defaults from src/services/bible/readingPreferences.ts and native defaults.
READER_DEFAULTS = {"textSize": "medium", "lineSpacing": "comfortable", "typeface": "serif", "layout": "paragraphs"}
NATIVE_CALENDAR_DEFAULT = {"enabled": False, "hour": 8, "minute": 0}
NATIVE_ROSARY_DEFAULT = {"enabled": False, "frequency": "daily", "hour": 20, "minute": 0, "weekday": 2}

# Every input copy that this tool read or hashed. Paths are relative to build/native-evidence.
INPUT_COPY_GLOBS = [
    "L00/synthetic-legacy-fixture/Documents/SQLite/*",
    "L00/synthetic-legacy-fixture/Documents/mmkv/mmkv.default*",
    "L00/synthetic-legacy-fixture/Library/Preferences/*.plist",
    "L25/baseline-navigation-recon-01/data-before/Documents/SQLite/*",
    "L25/baseline-navigation-recon-01/data-before/Documents/mmkv/mmkv.default*",
    "L25/baseline-navigation-recon-01/data-before/Library/Preferences/*.plist",
    "L25/baseline-navigation-recon-01/data-before/Library/Application Support/John/native-state-v1*.json",
    "L25/baseline-navigation-recon-01/data-after/Documents/SQLite/*",
    "L25/baseline-navigation-recon-01/data-after/Documents/mmkv/mmkv.default*",
    "L25/baseline-navigation-recon-01/data-after/Library/Preferences/*.plist",
    "L25/baseline-navigation-recon-01/data-after/Library/Application Support/John/native-state-v1*.json",
    "L25/baseline-john1-parity-01/data-before/Documents/SQLite/*",
    "L25/baseline-john1-parity-01/data-before/Documents/mmkv/mmkv.default*",
    "L25/baseline-john1-parity-01/data-after/Documents/SQLite/*",
    "L25/baseline-john1-parity-01/data-after/Documents/mmkv/mmkv.default*",
    "L25/baseline-l00-preflight-01/InstalledDataBeforeSeed/Library/Application Support/John/native-state-v1*.json",
    "L25/preserve-prod-native-before-baseline-01/DataContainer/Library/Application Support/John/native-state-v1*.json",
    "L25/preserve-prod-native-before-baseline-01/manifest.sha256",
    "L25/preserve-prod-native-before-baseline-01/files.sha256",
    "L25/preserve-prod-native-before-baseline-01/key-hashes.sha256",
    "L25/preserve-prod-native-before-baseline-01/run.txt",
    "L25/native-john1-preflight-export-01/*.json",
    "L25/native-john1-preflight-export-01/*.png",
    "L22/positive-notice-native-dev-02/data-after/AppData/Documents/SQLite/*",
    "L22/positive-notice-native-dev-02/data-after/AppData/Library/Application Support/John/native-state-v1*.json",
    "L22/positive-notice-native-dev-02/data-after/AppGroup/Library/Preferences/*.plist",
    "L22/positive-notice-native-dev-01/before/AppData/Documents/SQLite/*",
    "L22/positive-notice-native-dev-01/before/AppData/Library/Application Support/John/native-state-v1*.json",
    "L20/mixed-clear-metric-02/installed-seed/*",
    "L20/mixed-clear-metric-02/before-container/*",
    "L20/mixed-clear-metric-02/final/*",
]


def write_input_copies(dest):
    import glob
    rows = []
    for pattern in INPUT_COPY_GLOBS:
        for match in sorted(glob.glob(str(EVIDENCE / pattern))):
            path = Path(match)
            if path.is_file():
                rows.append((rel(path), sha256_file(path), "%04o" % mode_of(path), path.stat().st_size))
    with open(dest, "w") as handle:
        handle.write("path\tsha256\tmode\tsize\n")
        for row in rows:
            handle.write("\t".join(str(v) for v in row) + "\n")
    return len(rows)


# Fixture file layout. "container" is the path inside the app data container.
FIXTURE_FILES = [
    # app, fixture-relative path, container path, mode, action, purpose
    ("old", "old/com.nrsv.verse/Documents/SQLite/bible-search.db", "Documents/SQLite/bible-search.db", 0o600,
     "copy-if-different", "Old app Bible search database. Same bytes as the bundled copy. Needs owner write mode."),
    ("old", "old/com.nrsv.verse/Documents/SQLite/user-library.db", "Documents/SQLite/user-library.db", 0o644,
     "copy", "Old app saved library: one bookmark, one gold highlight, one note on WEB-CE John 1:1."),
    ("old", "old/com.nrsv.verse/Documents/mmkv/mmkv.default", "Documents/mmkv/mmkv.default", 0o700,
     "copy", "Old app MMKV data. Reader location John 1 at the top, text size medium, selection hint dismissed."),
    ("old", "old/com.nrsv.verse/Documents/mmkv/mmkv.default.crc", "Documents/mmkv/mmkv.default.crc", 0o700,
     "copy", "Old app MMKV meta and CRC file. Copy it together with mmkv.default."),
    ("old", "old/com.nrsv.verse/Library/Preferences/group.com.nrsv.verse.plist", "Library/Preferences/group.com.nrsv.verse.plist",
     0o600, "copy", "Old app widget scalar values: WEB-CE, 1440 minutes, full scope, schema 2."),
    ("native", "native/com.nrsv.verse.dev/Documents/SQLite/user-library.db", "Documents/SQLite/user-library.db", 0o644,
     "copy", "Native saved library with the same three rows as the old app. Closed file, DELETE journal mode."),
    ("native", "native/com.nrsv.verse.dev/Library/Application Support/John/native-state-v1.json",
     "Library/Application Support/John/native-state-v1.json", 0o600, "copy",
     "Native versioned JSON envelope. Reader location John 1 at the top with no anchor. Same preferences as the old app."),
    ("reference", "reference/native-group-prefs-expected.plist", None, 0o644, "verify-only",
     "Expected native widget scalar values (observed group.com.nrsv.verse.dev.plist). Do not copy. Compare only."),
]
# Files to remove from a task container before the copy. They are stale and would mix with the new files.
REMOVE_BEFORE_COPY = {
    "old": ["Documents/SQLite/user-library.db-wal", "Documents/SQLite/user-library.db-shm",
            "Documents/SQLite/user-library.db-journal"],
    "native": ["Documents/SQLite/user-library.db-wal", "Documents/SQLite/user-library.db-shm",
               "Documents/SQLite/user-library.db-journal", "Library/Application Support/John/native-state-v1.previous.json"],
}
# Files that the old app container may hold from the earlier native production app. They are not seeded or removed.
STALE_OLD_PATHS = ["Library/Application Support/John/native-state-v1.json",
                   "Library/Application Support/John/native-state-v1.previous.json"]
CONTAINER_BUNDLE = {"old": OLD_BUNDLE, "native": NATIVE_BUNDLE}
WRITABLE_DIRS = {
    "old": ["Documents", "Documents/SQLite", "Documents/mmkv", "Library", "Library/Preferences"],
    "native": ["Documents", "Documents/SQLite", "Library", "Library/Application Support", "Library/Application Support/John"],
}

# Facts that come from run records, not from files. The tool copies them into the report as recorded values.
RECORDED_FACTS = {
    "device": "iPhone 17 Pro, 402 x 874 points, 1206 x 2622 pixels, iOS 26.5 (23F77)",
    "simulator": "37D1870B-F16D-488A-8F20-959201F970D9",
    "effectiveDeviceAppearance": "Light (baseline-l00-preflight-01/run.txt)",
    "statusBar": "9:41, Wi-Fi 3 bars, cellular 4 bars, battery 100%",
    "deviceTimeZone": "America/Toronto (baseline-l00-preflight-01/run.txt; host zone is the same)",
    "dateInput": "Actual device clock for both apps. Do not pass -L14FeatureDate or -L14FeatureTimeZone to the native app.",
}


# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

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


def read_rows(db_main_path):
    """Read all rows from a copy of the database. The copy keeps WAL and SHM files, so WAL rows count."""
    src = Path(db_main_path)
    with tempfile.TemporaryDirectory(prefix="l25-db-") as tmp:
        for suffix in ("", "-wal", "-shm"):
            candidate = Path(str(src) + suffix)
            if candidate.exists():
                shutil.copyfile(candidate, Path(tmp) / ("user-library.db" + suffix))
        con = sqlite3.connect(str(Path(tmp) / "user-library.db"))
        try:
            con.row_factory = sqlite3.Row
            result = {"userVersion": con.execute("PRAGMA user_version").fetchone()[0],
                      "integrity": con.execute("PRAGMA integrity_check").fetchone()[0]}
            for table in TABLES:
                rows = [dict(row) for row in con.execute("SELECT * FROM %s ORDER BY %s" % (table, TABLE_KEYS[table]))]
                result[table] = rows
            return result
        finally:
            con.close()


def parse_json_value(text):
    try:
        return json.loads(text)
    except (TypeError, ValueError):
        return text


# ---------------------------------------------------------------------------------------------
# Describe the two sides
# ---------------------------------------------------------------------------------------------

KNOWN_OLD_KEYS = {
    "ignite.themeScheme", "bible.translationId", "bible.rotationInterval", "bible.verseScope",
    "bible.reader.location", "bible.reader.textSize", "bible.reader.lineSpacing", "bible.reader.typeface",
    "bible.reader.layout", "bible.widgetGuideDismissed", "bible.reader.selectionHintDismissed",
    "vesper.prayer.favorites", "john.calendar-notifications.v1", "rosary.reminder.v1", "works.position.v1",
}


def describe_old(root):
    root = Path(root)
    mmkv = mmkv_decode.decode(str(root / "Documents/mmkv/mmkv.default"), str(root / "Documents/mmkv/mmkv.default.crc"))
    keys = mmkv["keys"]
    parsed = {k: parse_json_value(v) for k, v in keys.items()}
    group_path = root / "Library/Preferences/group.com.nrsv.verse.plist"
    group = plistlib.loads(group_path.read_bytes()) if group_path.exists() else None
    db = read_rows(root / "Documents/SQLite/user-library.db")
    prefs = {}
    for name in READER_DEFAULTS:
        key = "bible.reader." + name
        prefs[name] = parsed[key] if key in parsed else READER_DEFAULTS[name]
    unknown = sorted(k for k in keys if k not in KNOWN_OLD_KEYS and not k.startswith(("novena.", "vesper.sunday.")))
    return {
        "mmkvReport": {k: v for k, v in mmkv.items() if k not in ("appendLog", "keys")},
        "mmkvKeys": keys,
        "mmkvAppendLog": mmkv["appendLog"],
        "db": db,
        "readerLocation": parsed.get("bible.reader.location"),
        "readingPreferences": prefs,
        "readingPreferenceSources": {n: ("mmkv" if ("bible.reader." + n) in parsed else "default") for n in READER_DEFAULTS},
        # Missing MMKV keys use the old-app source defaults (src/services/bible/preferences.ts and verseOfDay.ts).
        # The old app does not read the group prefs for these values. The group prefs are compared as a separate row.
        "translationID": parsed.get("bible.translationId", "web-ce"),
        "translationSource": "mmkv" if "bible.translationId" in parsed else "default",
        "themeScheme": keys.get("ignite.themeScheme"),
        "selectionHintDismissed": parsed.get("bible.reader.selectionHintDismissed") is True,
        "widgetGuideDismissed": parsed.get("bible.widgetGuideDismissed") is True,
        "rotationIntervalMinutes": parsed.get("bible.rotationInterval", 1440),
        "verseScope": parsed.get("bible.verseScope", "full"),
        "favoritePrayerIDs": parsed.get("vesper.prayer.favorites"),
        "calendarNotifications": parsed.get("john.calendar-notifications.v1"),
        "rosaryReminder": parsed.get("rosary.reminder.v1"),
        "worksPositions": parsed.get("works.position.v1"),
        "reflectionKeys": sorted(k for k in keys if k.startswith("vesper.sunday.")),
        "novenaKeys": sorted(k for k in keys if k.startswith("novena.")),
        "unknownKeys": unknown,
        "widgetScalars": group,
    }


def describe_native(root, group_plist=None):
    root = Path(root)
    envelope_path = root / "Library/Application Support/John/native-state-v1.json"
    envelope = json.loads(envelope_path.read_text())
    state = envelope["state"]
    group = None
    if group_plist and Path(group_plist).exists():
        group = plistlib.loads(Path(group_plist).read_bytes())
    db = read_rows(root / "Documents/SQLite/user-library.db")
    return {
        "envelopeRevision": envelope["revision"],
        "envelopeFormatVersion": envelope["formatVersion"],
        "envelopeImportVersion": envelope["importVersion"],
        "envelopeIssues": envelope["issues"],
        "db": db,
        "readerLocation": state.get("readerLocation"),
        "readingPreferences": state.get("readingPreferences"),
        "translationID": state.get("translationID"),
        "themeScheme": state.get("themeScheme"),
        "selectionHintDismissed": state.get("selectionHintDismissed"),
        "widgetGuideDismissed": state.get("widgetGuideDismissed"),
        "rotationIntervalMinutes": state.get("rotationIntervalMinutes"),
        "verseScope": state.get("verseScope"),
        "favoritePrayerIDs": state.get("favoritePrayerIDs"),
        "calendarNotifications": state.get("calendarNotifications"),
        "rosaryReminder": state.get("rosaryReminder"),
        "worksPositions": state.get("worksPositions"),
        "reflections": state.get("reflections"),
        "novenaProgress": state.get("novenaProgress"),
        "widgetScalars": group,
    }


# ---------------------------------------------------------------------------------------------
# Compare
# ---------------------------------------------------------------------------------------------

def brief_rows(table, rows):
    if table == "highlights":
        return [{"key": r["verse_key"], "color": r["color"], "edition": r["translation_id"]} for r in rows]
    if table == "notes":
        return [{"key": r["passage_key"], "note": r["note_text"], "edition": r["translation_id"]} for r in rows]
    return [{"key": r["passage_key"], "edition": r["translation_id"]} for r in rows]


def compare(old, native):
    out = []

    def add(category, old_value, native_value, match, note=""):
        out.append({"category": category, "old": old_value, "native": native_value, "match": match, "note": note})

    for table in TABLES:
        o, n = old["db"][table], native["db"][table]
        add(table, brief_rows(table, o), brief_rows(table, n), o == n,
            "Full row comparison, all %d columns." % (len(o[0]) if o else (len(n[0]) if n else 0)))
    add("library schema/integrity", {"userVersion": old["db"]["userVersion"], "integrity": old["db"]["integrity"]},
        {"userVersion": native["db"]["userVersion"], "integrity": native["db"]["integrity"]},
        old["db"]["userVersion"] == native["db"]["userVersion"] == 1 and old["db"]["integrity"] == native["db"]["integrity"] == "ok")

    ol, nl = old["readerLocation"], native["readerLocation"]
    ol_view = None if ol is None else {"book": ol.get("book"), "chapter": ol.get("chapter"), "scrollY": ol.get("scrollY"),
                                       "updatedAt": ol.get("updatedAt")}
    nl_view = None if nl is None else {"book": nl.get("bookCode"), "chapter": nl.get("chapter"), "scrollY": nl.get("scrollY"),
                                       "anchor": nl.get("anchor"), "updatedAt": nl.get("updatedAt")}
    location_match = (ol_view is not None and nl_view is not None and ol_view["book"] == nl_view["book"]
                      and ol_view["chapter"] == nl_view["chapter"] and ol_view["scrollY"] == nl_view["scrollY"]
                      and nl_view["anchor"] is None) or (ol_view is None and nl_view is None)
    add("Reader location/progress", ol_view, nl_view, location_match,
        "Match needs equal book, chapter, scrollY, and no native anchor. updatedAt is shown and not compared.")

    for name in READER_DEFAULTS:
        add("typography: " + name,
            "%s (%s)" % (old["readingPreferences"][name], old["readingPreferenceSources"][name]),
            (native["readingPreferences"] or {}).get(name),
            old["readingPreferences"][name] == (native["readingPreferences"] or {}).get(name))
    add("edition", "%s (%s)" % (old["translationID"], old["translationSource"]), native["translationID"],
        old["translationID"] == native["translationID"])
    add("appearance preference", old["themeScheme"] or "absent (System)", native["themeScheme"] or "absent (System)",
        (old["themeScheme"] or None) == (native["themeScheme"] or None))
    add("selection hint dismissed", old["selectionHintDismissed"], native["selectionHintDismissed"],
        old["selectionHintDismissed"] == native["selectionHintDismissed"])
    add("widget guide dismissed", old["widgetGuideDismissed"], native["widgetGuideDismissed"],
        old["widgetGuideDismissed"] == native["widgetGuideDismissed"])
    add("rotation interval / scope",
        {"minutes": old["rotationIntervalMinutes"], "scope": old["verseScope"]},
        {"minutes": native["rotationIntervalMinutes"], "scope": native["verseScope"]},
        old["rotationIntervalMinutes"] == native["rotationIntervalMinutes"] and old["verseScope"] == native["verseScope"])
    add("prayer favorites", old["favoritePrayerIDs"] if old["favoritePrayerIDs"] is not None else "absent",
        native["favoritePrayerIDs"], (old["favoritePrayerIDs"] or []) == native["favoritePrayerIDs"])
    add("Sunday reflections", old["reflectionKeys"], sorted((native["reflections"] or {}).keys()),
        old["reflectionKeys"] == sorted((native["reflections"] or {}).keys()))
    add("novena progress", old["novenaKeys"], sorted((native["novenaProgress"] or {}).keys()),
        len(old["novenaKeys"]) == len(native["novenaProgress"] or {}))
    add("calendar notification setting", old["calendarNotifications"] if old["calendarNotifications"] is not None else "absent (default off 08:00)",
        native["calendarNotifications"], (old["calendarNotifications"] is None and native["calendarNotifications"] == NATIVE_CALENDAR_DEFAULT)
        or old["calendarNotifications"] == native["calendarNotifications"])
    nr = {k: v for k, v in (native["rosaryReminder"] or {}).items() if k != "notificationID"}
    add("Rosary reminder setting", old["rosaryReminder"] if old["rosaryReminder"] is not None else "absent (default off daily 20:00)",
        native["rosaryReminder"], (old["rosaryReminder"] is None and nr == NATIVE_ROSARY_DEFAULT
                                  and (native["rosaryReminder"] or {}).get("notificationID") is None))
    add("Works positions", old["worksPositions"] if old["worksPositions"] is not None else "absent",
        native["worksPositions"], (old["worksPositions"] in (None, {})) and not native["worksPositions"])
    add("unknown legacy keys", old["unknownKeys"], "n/a", len(old["unknownKeys"]) == 0,
        "No unknown key in old MMKV. Unknown keys would have no native side.")
    ow, nw = old["widgetScalars"], native["widgetScalars"]
    add("widget scalar values (group prefs)", ow, nw if nw is not None else "not supplied", (ow == nw) if nw is not None else None,
        "Native value comes from the observed group.com.nrsv.verse.dev.plist." if nw is not None else "")
    return out


def format_table(rows):
    lines = []
    for row in rows:
        flag = {True: "MATCH", False: "MISMATCH", None: "n/a"}[row["match"]]
        lines.append("%-9s %-34s old=%s | native=%s" % (flag, row["category"], json.dumps(row["old"], ensure_ascii=False, default=str)[:110],
                                                          json.dumps(row["native"], ensure_ascii=False, default=str)[:110]))
    return "\n".join(lines)


def run_check(old_root, native_root, group_plist=None):
    old = describe_old(old_root)
    native = describe_native(native_root, group_plist)
    return old, native, compare(old, native)


# ---------------------------------------------------------------------------------------------
# prepare
# ---------------------------------------------------------------------------------------------

def build_native_db(dest, old_db_source):
    """Copy the native closed database and insert the old rows. Column shapes must match."""
    with tempfile.TemporaryDirectory(prefix="l25-build-") as tmp:
        work = Path(tmp) / "user-library.db"
        old_copy = Path(tmp) / "old.db"
        shutil.copyfile(NATIVE_DB_SOURCE, work)
        shutil.copyfile(old_db_source, old_copy)
        con = sqlite3.connect(str(work))
        try:
            con.execute("ATTACH DATABASE ? AS old", (str(old_copy),))
            for table in TABLES:
                main_shape = [(r[1], r[2].upper(), r[3], r[5]) for r in con.execute("PRAGMA main.table_info(%s)" % table)]
                old_shape = [(r[1], r[2].upper(), r[3], r[5]) for r in con.execute("PRAGMA old.table_info(%s)" % table)]
                if main_shape != old_shape:
                    fail("table shape differs for %s" % table)
                if con.execute("SELECT COUNT(*) FROM main.%s" % table).fetchone()[0] != 0:
                    fail("native source table %s is not empty" % table)
            for table in TABLES:
                con.execute("INSERT INTO main.%s SELECT * FROM old.%s" % (table, table))
            con.commit()
            mode = con.execute("PRAGMA journal_mode").fetchone()[0]
            integrity = con.execute("PRAGMA integrity_check").fetchone()[0]
            version = con.execute("PRAGMA user_version").fetchone()[0]
            if mode != "delete" or integrity != "ok" or version != 1:
                fail("built native database failed checks: %s %s %s" % (mode, integrity, version))
        finally:
            con.close()
        for leftover in ("-journal", "-wal", "-shm"):
            if Path(str(work) + leftover).exists():
                fail("built native database left a %s file" % leftover)
        shutil.copyfile(work, dest)


def build_envelope(old_location):
    state = {
        "calendarNotifications": dict(NATIVE_CALENDAR_DEFAULT),
        "favoritePrayerIDs": [],
        "novenaProgress": {},
        "readerLocation": {"bookCode": old_location["book"], "chapter": old_location["chapter"],
                           "scrollY": old_location["scrollY"], "updatedAt": old_location["updatedAt"]},
        "readingPreferences": {"layout": READER_DEFAULTS["layout"], "lineSpacing": READER_DEFAULTS["lineSpacing"],
                               "textSize": "medium", "typeface": READER_DEFAULTS["typeface"]},
        "reflections": {},
        "rosaryReminder": dict(NATIVE_ROSARY_DEFAULT),
        "rotationIntervalMinutes": 1440,
        "selectionHintDismissed": True,
        "translationID": "web-ce",
        "verseScope": "full",
        "widgetGuideDismissed": False,
        "worksPositions": {},
    }
    envelope = {"formatVersion": 1, "importSourceHashes": {}, "importVersion": 1, "issues": [], "revision": 28, "state": state}
    return json.dumps(envelope, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def cmd_prepare(args):
    out = Path(args.out).resolve()
    if out.exists():
        fail("output folder exists. Use a new path: %s" % out)
    # 1. Verify inputs by hash.
    problems = []
    for relpath, expected in OLD_INPUTS.items():
        path = OLD_SOURCE_ROOT / relpath
        actual = sha256_file(path) if path.exists() else "missing"
        if actual != expected:
            problems.append("%s: expected %s got %s" % (path, expected, actual))
    for path, expected in ((NATIVE_DB_SOURCE, NATIVE_DB_SOURCE_SHA), (NATIVE_ENVELOPE_SOURCE, NATIVE_ENVELOPE_SOURCE_SHA),
                           (NATIVE_GROUP_SOURCE, NATIVE_GROUP_SOURCE_SHA)):
        actual = sha256_file(path) if path.exists() else "missing"
        if actual != expected:
            problems.append("%s: expected %s got %s" % (path, expected, actual))
    if problems:
        fail("input hash mismatch:\n  " + "\n  ".join(problems))

    # 2. Compare the stale evidence pair first. It shows the mismatches this fixture removes.
    before_old, before_native, before_rows = run_check(STALE_OLD_TREE, STALE_NATIVE_TREE, NATIVE_GROUP_SOURCE)

    # 3. Build the fixture tree.
    out.mkdir(parents=True)
    os.chmod(out, 0o755)
    old_decoded = mmkv_decode.decode(str(OLD_SOURCE_ROOT / "Documents/mmkv/mmkv.default"),
                                     str(OLD_SOURCE_ROOT / "Documents/mmkv/mmkv.default.crc"))
    old_location = json.loads(old_decoded["keys"]["bible.reader.location"])
    sources = {}

    def place(fixture_rel, source_path, mode):
        dest = out / fixture_rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_path, dest)
        os.chmod(dest, mode)
        return dest

    for app, fixture_rel, container, mode, action, purpose in FIXTURE_FILES:
        if app == "old":
            source = OLD_SOURCE_ROOT / container
            place(fixture_rel, source, mode)
            sources[fixture_rel] = {"path": rel(source), "sha256": sha256_file(source), "transform": "byte copy"}
        elif fixture_rel.endswith("native-state-v1.json"):
            dest = out / fixture_rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(build_envelope(old_location))
            os.chmod(dest, mode)
            sources[fixture_rel] = {"path": rel(NATIVE_ENVELOPE_SOURCE), "sha256": sha256_file(NATIVE_ENVELOPE_SOURCE),
                                    "transform": "Based on revision 27 envelope. Revision 28. Reader location reset to the decoded old "
                                                 "MMKV value (John 1, scrollY 0, no anchor). Other fields equal the old app values."}
        elif fixture_rel.endswith("user-library.db"):
            dest = out / fixture_rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            build_native_db(dest, OLD_SOURCE_ROOT / "Documents/SQLite/user-library.db")
            os.chmod(dest, mode)
            sources[fixture_rel] = {"path": rel(NATIVE_DB_SOURCE), "sha256": sha256_file(NATIVE_DB_SOURCE),
                                    "transform": "Native closed DB (zero rows) plus the 3 old rows inserted by SQL. Same values."}
        else:
            place(fixture_rel, NATIVE_GROUP_SOURCE, mode)
            sources[fixture_rel] = {"path": rel(NATIVE_GROUP_SOURCE), "sha256": sha256_file(NATIVE_GROUP_SOURCE), "transform": "byte copy"}
    for directory in [out] + [p for p in out.rglob("*") if p.is_dir()]:
        os.chmod(directory, 0o755)

    # 4. Check the new pair (the fixture trees themselves).
    new_old_root = out / "old" / OLD_BUNDLE
    new_native_root = out / "native" / NATIVE_BUNDLE
    after_old, after_native, after_rows = run_check(new_old_root, new_native_root, out / "reference/native-group-prefs-expected.plist")

    # 5. Write expected data and reports.
    expected = out / "expected"
    expected.mkdir()
    (expected / "old-mmkv-decoded.json").write_text(json.dumps(old_decoded, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    (expected / "db-rows.json").write_text(json.dumps({"old": after_old["db"], "native": after_native["db"]}, indent=2,
                                                      sort_keys=True, ensure_ascii=False) + "\n")
    (expected / "native-envelope.json").write_text(json.dumps(json.loads((new_native_root / "Library/Application Support/John/native-state-v1.json").read_text()),
                                                              indent=2, sort_keys=True) + "\n")
    report = {
        "recordedFacts": RECORDED_FACTS,
        "before": {"oldTree": rel(STALE_OLD_TREE), "nativeTree": rel(STALE_NATIVE_TREE), "rows": before_rows},
        "after": {"oldTree": rel(new_old_root), "nativeTree": rel(new_native_root), "rows": after_rows},
    }
    (expected / "alignment.json").write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False, default=str) + "\n")
    for directory in [expected]:
        os.chmod(directory, 0o755)
    for path in expected.iterdir():
        os.chmod(path, 0o644)

    write_input_copies(expected / "input-copies.tsv")
    os.chmod(expected / "input-copies.tsv", 0o644)

    # 6. Manifest.
    entries = []
    for app, fixture_rel, container, mode, action, purpose in FIXTURE_FILES:
        path = out / fixture_rel
        entries.append({
            "app": app,
            "bundleId": CONTAINER_BUNDLE.get(app),
            "path": fixture_rel,
            "containerPath": container,
            "sha256": sha256_file(path),
            "size": path.stat().st_size,
            "mode": "%04o" % mode_of(path),
            "action": action,
            "purpose": purpose,
            "source": sources[fixture_rel],
        })
    for path in sorted(expected.iterdir()):
        entries.append({"app": "evidence", "bundleId": None, "path": str(path.relative_to(out)), "containerPath": None,
                        "sha256": sha256_file(path), "size": path.stat().st_size, "mode": "%04o" % mode_of(path),
                        "action": "evidence-only", "purpose": "Decoded or compared values for review. Do not copy.", "source": None})
    manifest = {
        "formatVersion": 1,
        "fixtureId": out.name,
        "createdUtc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "scope": "L25 paired Reader and route capture. Not the L27 update fixture.",
        "tool": rel(Path(__file__)),
        "toolSha256": sha256_file(Path(__file__)),
        "mmkvDecoderSha256": sha256_file(HERE / "mmkv_decode.py"),
        "removeBeforeCopy": REMOVE_BEFORE_COPY,
        "staleOldContainerPaths": STALE_OLD_PATHS,
        "recordedFacts": RECORDED_FACTS,
        "files": entries,
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    os.chmod(out / "manifest.json", 0o644)
    with open(out / "manifest.tsv", "w") as handle:
        handle.write("path\tsha256\tmode\tsize\taction\tcontainerPath\tpurpose\n")
        for e in entries:
            handle.write("\t".join([e["path"], e["sha256"], e["mode"], str(e["size"]), e["action"], e["containerPath"] or "-", e["purpose"]]) + "\n")
    os.chmod(out / "manifest.tsv", 0o644)

    print("Fixture written: %s" % out)
    print("\nBEFORE (newest existing evidence copies):")
    print(format_table(before_rows))
    print("\nAFTER (new fixture):")
    print(format_table(after_rows))
    bad = [r for r in after_rows if r["match"] is False]
    if bad:
        fail("%d category mismatch in the new fixture" % len(bad))
    print("\nAll categories match in the new fixture.")
    return 0


# ---------------------------------------------------------------------------------------------
# check / verify / seed
# ---------------------------------------------------------------------------------------------

def cmd_check(args):
    old, native, rows = run_check(args.old_data, args.native_data, args.native_group_plist)
    print(format_table(rows))
    if args.json_out:
        Path(args.json_out).write_text(json.dumps({"rows": rows, "recordedFacts": RECORDED_FACTS}, indent=2, sort_keys=True,
                                                  ensure_ascii=False, default=str) + "\n")
    return 1 if any(r["match"] is False for r in rows) else 0


def load_manifest(fixture):
    path = Path(fixture) / "manifest.json"
    if not path.exists():
        fail("manifest not found: %s" % path)
    return json.loads(path.read_text())


def check_fixture_integrity(fixture, manifest):
    bad = []
    for entry in manifest["files"]:
        path = Path(fixture) / entry["path"]
        if not path.exists():
            bad.append("missing fixture file " + entry["path"])
        elif sha256_file(path) != entry["sha256"]:
            bad.append("fixture hash changed " + entry["path"])
    return bad


def resolve_roots(args):
    roots = {"old": args.old_data_root, "native": args.native_data_root}
    if args.udid:
        for app in ("old", "native"):
            if roots[app] or (args.only and args.only != app):
                continue
            result = subprocess.run(["xcrun", "simctl", "get_app_container", args.udid, CONTAINER_BUNDLE[app], "data"],
                                    capture_output=True, text=True)
            if result.returncode != 0:
                fail("simctl get_app_container failed for %s: %s" % (CONTAINER_BUNDLE[app], result.stderr.strip()))
            roots[app] = result.stdout.strip()
    apps = [args.only] if args.only else ["old", "native"]
    selected = {}
    for app in apps:
        if not roots[app]:
            fail("no data root for the %s app. Pass --%s-data-root or --udid." % (app, app))
        root = Path(roots[app]).resolve()
        if not root.is_dir():
            fail("data root is not a folder: %s" % root)
        if not args.allow_nonsimulator_root and "/CoreSimulator/Devices/" not in str(root):
            fail("data root is not under CoreSimulator/Devices: %s" % root)
        metadata = root / ".com.apple.mobile_container_manager.metadata.plist"
        if not metadata.exists():
            fail("container metadata plist not found in %s" % root)
        identifier = plistlib.loads(metadata.read_bytes()).get("MCMMetadataIdentifier")
        if identifier != CONTAINER_BUNDLE[app]:
            fail("container %s belongs to %s, expected %s" % (root, identifier, CONTAINER_BUNDLE[app]))
        selected[app] = root
    return selected


def status_for(entry, root):
    target = root / entry["containerPath"]
    if not target.exists():
        return "absent", None, None
    return ("match" if sha256_file(target) == entry["sha256"] else "different"), sha256_file(target), "%04o" % mode_of(target)


def cmd_verify(args):
    fixture = Path(args.fixture)
    manifest = load_manifest(fixture)
    bad = check_fixture_integrity(fixture, manifest)
    if bad:
        fail("fixture integrity: " + "; ".join(bad))
    roots = resolve_roots(args)
    problems = 0
    for entry in manifest["files"]:
        if entry["app"] not in roots or entry["containerPath"] is None:
            continue
        state, digest, mode = status_for(entry, roots[entry["app"]])
        mode_ok = mode == entry["mode"] if mode else False
        ok = state == "match" and mode_ok
        problems += 0 if ok else 1
        print("%-8s %-6s %-10s mode=%s (want %s)  %s" % ("OK" if ok else "PROBLEM", entry["app"], state, mode, entry["mode"], entry["containerPath"]))
    for app, root in roots.items():
        for relpath in manifest["removeBeforeCopy"][app]:
            if (root / relpath).exists():
                problems += 1
                print("PROBLEM  %-6s stale file still present: %s" % (app, relpath))
        if app == "old":
            for relpath in manifest["staleOldContainerPaths"]:
                if (root / relpath).exists():
                    print("NOTE     old    stale native file present (not used by the old app; remove before any L27 update test): %s" % relpath)
    print("Byte check only. Run it before the first launch. The first launch changes MMKV and the envelope.")
    return 1 if problems else 0


def backup_and_remember(app, root, relpath, backup_dir, log):
    source = root / relpath
    if not source.exists():
        return
    dest = Path(backup_dir) / app / relpath
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest)
    log.append({"app": app, "path": relpath, "sha256": sha256_file(source), "mode": "%04o" % mode_of(source), "backup": str(dest)})


def cmd_seed(args):
    fixture = Path(args.fixture)
    manifest = load_manifest(fixture)
    bad = check_fixture_integrity(fixture, manifest)
    if bad:
        fail("fixture integrity: " + "; ".join(bad))
    roots = resolve_roots(args)
    apply = args.apply
    if apply and not args.confirm_apps_stopped:
        fail("--apply needs --confirm-apps-stopped. Main must stop both apps first.")
    if apply and not args.report_dir:
        fail("--apply needs --report-dir (a new folder for the backup and report).")
    report_dir = Path(args.report_dir) if args.report_dir else None
    if apply and report_dir.exists():
        fail("report dir exists. Use a new path: %s" % report_dir)
    print("MODE: %s" % ("APPLY" if apply else "DRY RUN (nothing will change)"))
    plan = []
    for app, root in roots.items():
        for relpath in manifest["removeBeforeCopy"][app]:
            if (root / relpath).exists():
                plan.append(("remove", app, root, relpath, None))
        for entry in manifest["files"]:
            if entry["app"] != app or entry["containerPath"] is None:
                continue
            state, _, mode = status_for(entry, root)
            if state == "match":
                if mode != entry["mode"]:
                    plan.append(("chmod", app, root, entry["containerPath"], entry))
                continue
            plan.append(("copy", app, root, entry["containerPath"], entry))
        for dirname in WRITABLE_DIRS[app]:
            path = root / dirname
            if path.exists() and not os.access(path, os.W_OK):
                plan.append(("chmod-dir", app, root, dirname, None))
    for action, app, root, relpath, entry in plan:
        print("PLAN  %-9s %-6s %s" % (action, app, relpath))
    if "old" in roots:
        for relpath in manifest["staleOldContainerPaths"]:
            if (roots["old"] / relpath).exists():
                print("NOTE  old container holds a stale native file (left in place): %s" % relpath)
    if not apply:
        print("DRY RUN: nothing changed. Add --apply --confirm-apps-stopped --report-dir <new folder> to copy.")
        return 0

    report_dir.mkdir(parents=True)
    backup_log = []
    done = []
    for action, app, root, relpath, entry in plan:
        if action == "chmod-dir":
            os.chmod(root / relpath, mode_of(root / relpath) | 0o700)
            done.append({"action": action, "app": app, "path": relpath})
    for app, root in roots.items():
        for dirname in WRITABLE_DIRS[app]:
            (root / dirname).mkdir(parents=True, exist_ok=True)
    for action, app, root, relpath, entry in plan:
        if action in ("remove", "copy", "chmod"):
            backup_and_remember(app, root, relpath, report_dir / "before", backup_log)
        if action == "remove":
            os.remove(root / relpath)
        elif action == "chmod":
            os.chmod(root / relpath, int(entry["mode"], 8))
        elif action == "copy":
            target = root / relpath
            temp = target.with_name(target.name + ".l25tmp")
            shutil.copyfile(fixture / entry["path"], temp)
            os.chmod(temp, int(entry["mode"], 8))
            os.replace(temp, target)
        done.append({"action": action, "app": app, "path": relpath})
    # Verify.
    results = []
    problems = 0
    for entry in manifest["files"]:
        if entry["app"] not in roots or entry["containerPath"] is None:
            continue
        state, digest, mode = status_for(entry, roots[entry["app"]])
        ok = state == "match" and mode == entry["mode"]
        problems += 0 if ok else 1
        results.append({"app": entry["app"], "path": entry["containerPath"], "state": state, "sha256": digest, "mode": mode,
                        "wantMode": entry["mode"], "ok": ok})
        print("%-8s %-6s %-9s mode=%s %s" % ("OK" if ok else "PROBLEM", entry["app"], state, mode, entry["containerPath"]))
    for app, root in roots.items():
        for relpath in manifest["removeBeforeCopy"][app]:
            if (root / relpath).exists():
                problems += 1
                print("PROBLEM  stale file still present: %s %s" % (app, relpath))
    (report_dir / "seed-report.json").write_text(json.dumps({
        "fixture": str(fixture), "manifestSha256": sha256_file(fixture / "manifest.json"),
        "dataRoots": {k: str(v) for k, v in roots.items()}, "operations": done, "backups": backup_log, "verify": results,
        "utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}, indent=2, sort_keys=True) + "\n")
    print("Report: %s" % (report_dir / "seed-report.json"))
    return 1 if problems else 0


# ---------------------------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("prepare", help="build a new fixture folder from copied evidence")
    p.add_argument("--out", default=str(DEFAULT_FIXTURE))
    p.set_defaults(func=cmd_prepare)

    p = sub.add_parser("check", help="compare logical saved state of two copied data trees")
    p.add_argument("--old-data", required=True, help="copied old app data container (has Documents and Library)")
    p.add_argument("--native-data", required=True, help="copied native app data container")
    p.add_argument("--native-group-plist", help="copied group.com.nrsv.verse.dev.plist (optional)")
    p.add_argument("--json-out")
    p.set_defaults(func=cmd_check)

    for name, helptext, func in (("verify", "byte and mode check of live containers (read only)", cmd_verify),
                                 ("seed", "copy the fixture into the containers (dry run by default)", cmd_seed)):
        p = sub.add_parser(name, help=helptext)
        p.add_argument("--fixture", default=str(DEFAULT_FIXTURE))
        p.add_argument("--old-data-root")
        p.add_argument("--native-data-root")
        p.add_argument("--udid", help="simulator UDID. Only then the tool runs `xcrun simctl get_app_container` (read only query).")
        p.add_argument("--only", choices=["old", "native"])
        p.add_argument("--allow-nonsimulator-root", action="store_true", help="for tests on a fake container tree")
        if name == "seed":
            p.add_argument("--apply", action="store_true")
            p.add_argument("--confirm-apps-stopped", action="store_true")
            p.add_argument("--report-dir")
        p.set_defaults(func=func)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
