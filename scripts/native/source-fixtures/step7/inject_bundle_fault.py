#!/usr/bin/env python3
"""Step 7 bundle fault injection for error-state checks. No app code changes.

It changes files inside the INSTALLED task-only development app bundle (com.nrsv.verse.dev) so that an error state
appears. It never touches com.nrsv.verse. It is a dry run by default. `apply` needs --apply and --confirm-app-stopped.
Every changed file is copied to the backup folder first. `restore` puts the original bytes back and checks the hashes.
A new install of the app also replaces the bundle and removes every fault.

Commands
  list                                  show the faults
  apply   --fault NAME [--edition E --book B --date D --year Y] --backup-dir NEW_DIR [--apply --confirm-app-stopped]
  restore --backup-dir DIR [--apply]

The app path must be the installed copy under /CoreSimulator/Devices/<UDID>/data/Containers/Bundle/Application/.
--allow-noninstalled-bundle is for host tests only and cannot be used with --udid. `restore` exits 1 on any hash mismatch.
The app location is --app-bundle PATH or --udid UDID (then `xcrun simctl get_app_container <udid> com.nrsv.verse.dev app`,
a read-only query). The tool never boots, installs, launches, or stops anything.
"""
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
EVIDENCE = (REPO / "build" / "native-evidence").resolve()
DEV_BUNDLE = "com.nrsv.verse.dev"

FAULTS = {
    "chapter-missing": "Reader shows 'Chapter unavailable' (ReaderView.swift:676, message ReaderScreenModel.swift:166). Needs --edition and --book.",
    "artwork-ivory-missing": "Scripture card shows the plain-background message (ScriptureCardView.swift:71). Warm ivory background.",
    "artwork-plum-missing": "Same for Evening plum.",
    "rosary-catalog-invalid": "Rosary home shows 'The Rosary catalog is not available right now.' (RosaryHomeView.swift:126).",
    "prayer-catalog-invalid": "Prayer home shows 'The prayer library is not available.' (PrayerHomeView.swift:118).",
    "works-catalog-missing": "Works library shows 'The library could not be opened on this device.' (WorksLibraryView.swift:75).",
    "reading-reference-invalid": "A daily reading row opens 'This reference could not be opened.' (CitationContextView.swift:99). Needs --date.",
    "search-db-missing": "Search shows 'Search could not be completed. Try a different phrase.' (SearchView.swift:199). Verify on the first run.",
    "widget-daily-year-missing": "Daily Reading widget falls back to its placeholder text for that year. Needs --year.",
    "widget-corpus-missing": "Verse widgets fall back to 'Open John 1:1 to begin.'. Needs --edition.",
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    sys.exit(2)


def resolve_app(args):
    """The app path must be the INSTALLED copy: .../CoreSimulator/Devices/<UDID>/data/Containers/Bundle/Application/<id>/<App>.app.
    Any other path (for example a DerivedData product) is refused, unless --allow-noninstalled-bundle is set for host tests.
    That flag cannot be used with --udid."""
    if args.allow_noninstalled_bundle and args.udid:
        fail("--allow-noninstalled-bundle cannot be used with --udid")
    app = args.app_bundle
    if not app:
        if not args.udid:
            fail("pass --app-bundle or --udid. Never use the booted alias.")
        result = subprocess.run(["xcrun", "simctl", "get_app_container", args.udid, DEV_BUNDLE, "app"], capture_output=True, text=True)
        if result.returncode != 0:
            fail("simctl get_app_container failed: " + result.stderr.strip())
        app = result.stdout.strip()
    app = Path(app).resolve()
    text = str(app)
    installed = "/CoreSimulator/Devices/" in text and "/data/Containers/Bundle/Application/" in text
    if not installed and not args.allow_noninstalled_bundle:
        fail("this is not an installed simulator app copy (.../CoreSimulator/Devices/<UDID>/data/Containers/Bundle/Application/...): %s" % text)
    if args.udid and "/Devices/%s/" % args.udid not in text:
        fail("the app path is not under /Devices/%s/" % args.udid)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != DEV_BUNDLE:
        fail("this bundle is %s. Only %s is allowed." % (info.get("CFBundleIdentifier"), DEV_BUNDLE))
    return app


def plan(fault, app, args):
    """Return a list of (relative path, kind, payload)."""
    if fault == "chapter-missing":
        if not (args.edition and args.book):
            fail("chapter-missing needs --edition and --book")
        return [("App/Bible/%s/%s.json" % (args.edition, args.book), "move", None)]
    if fault == "artwork-ivory-missing":
        return [("App/Artwork/share-ivory.jpg", "move", None)]
    if fault == "artwork-plum-missing":
        return [("App/Artwork/share-plum.jpg", "move", None)]
    if fault == "rosary-catalog-invalid":
        return [("App/Catalogs/devotional-catalogs.json", "json", ("rosary", "mediaEpisodes", []))]
    if fault == "prayer-catalog-invalid":
        return [("App/Catalogs/devotional-catalogs.json", "json", ("prayers", None, []))]
    if fault == "search-db-missing":
        return [("App/Databases/bible-search.db", "move", None)]
    if fault == "works-catalog-missing":
        return [("App/Catalogs/works-catalog.json", "move", None)]
    if fault == "reading-reference-invalid":
        if not args.date:
            fail("reading-reference-invalid needs --date YYYY-MM-DD")
        return [("App/Calendar/readings-us.json", "reading", args.date)]
    if fault == "widget-daily-year-missing":
        if not args.year:
            fail("widget-daily-year-missing needs --year")
        return [("PlugIns/JohnWidget.appex/Widget/daily-readings-%s.json" % args.year, "move", None)]
    if fault == "widget-corpus-missing":
        if not args.edition:
            fail("widget-corpus-missing needs --edition")
        return [("PlugIns/JohnWidget.appex/Widget/%s.dat" % args.edition, "move", None)]
    fail("unknown fault")


def cmd_apply(args):
    app = resolve_app(args)
    items = plan(args.fault, app, args)
    print("MODE: %s" % ("APPLY" if args.apply else "DRY RUN (nothing will change)"))
    print("App bundle: %s" % app)
    for relpath, kind, payload in items:
        target = app / relpath
        print("PLAN  %-6s %s %s" % (kind, relpath, "(exists)" if target.exists() else "(MISSING)"))
        if not target.exists():
            fail("target file is missing: %s" % relpath)
    if not args.apply:
        print("DRY RUN: nothing changed.")
        return 0
    if not args.confirm_app_stopped:
        fail("--apply needs --confirm-app-stopped")
    backup = Path(args.backup_dir).resolve()
    if not str(backup).startswith(str(EVIDENCE) + "/"):
        fail("--backup-dir must be below build/native-evidence")
    if backup.exists():
        fail("backup dir exists: %s" % backup)
    backup.mkdir(parents=True)
    record = {"fault": args.fault, "app": str(app), "files": []}
    for relpath, kind, payload in items:
        target = app / relpath
        saved = backup / "original" / relpath
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, saved)
        before = sha(target)
        if kind == "move":
            target.unlink()
            after = None
        elif kind == "json":
            data = json.loads(target.read_text())
            section, key, value = payload
            if key is None:
                data[section] = value
            else:
                data[section][key] = value
            target.write_text(json.dumps(data, ensure_ascii=False))
            after = sha(target)
        elif kind == "reading":
            data = json.loads(target.read_text())
            if payload not in data:
                fail("date not in the readings file: %s" % payload)
            data[payload]["readings"][0]["reference"] = "Nonexistent 99:1"
            target.write_text(json.dumps(data, ensure_ascii=False))
            after = sha(target)
        record["files"].append({"path": relpath, "kind": kind, "sha256Before": before, "sha256After": after})
    (backup / "fault-record.json").write_text(json.dumps(record, indent=2) + "\n")
    print("Applied. Record: %s" % (backup / "fault-record.json"))
    return 0


def cmd_restore(args):
    backup = Path(args.backup_dir).resolve()
    if not (backup / "fault-record.json").exists():
        fail("no fault-record.json in %s" % backup)
    record = json.loads((backup / "fault-record.json").read_text())
    app = Path(record["app"])
    text = str(app.resolve())
    if not ("/CoreSimulator/Devices/" in text and "/data/Containers/Bundle/Application/" in text) and not args.allow_noninstalled_bundle:
        fail("the recorded app path is not an installed simulator app copy: %s" % text)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != DEV_BUNDLE:
        fail("bundle is not %s" % DEV_BUNDLE)
    print("MODE: %s" % ("APPLY" if args.apply else "DRY RUN (nothing will change)"))
    problems = 0
    for item in record["files"]:
        source = backup / "original" / item["path"]
        ok = sha(source) == item["sha256Before"]
        print("PLAN  restore %s (backup hash %s)" % (item["path"], "ok" if ok else "BAD"))
        problems += 0 if ok else 1
        if args.apply and ok:
            shutil.copy2(source, app / item["path"])
            match = sha(app / item["path"]) == item["sha256Before"]
            print("%-5s %s hash %s" % ("OK" if match else "ERROR", item["path"], "match" if match else "MISMATCH"))
            problems += 0 if match else 1
    return 1 if problems else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    for name in ("apply", "restore"):
        p = sub.add_parser(name)
        p.add_argument("--backup-dir", required=True)
        p.add_argument("--apply", action="store_true")
        p.add_argument("--allow-noninstalled-bundle", action="store_true", help="host tests only; not with --udid")
        if name == "apply":
            p.add_argument("--fault", required=True, choices=sorted(FAULTS))
            p.add_argument("--app-bundle")
            p.add_argument("--udid")
            p.add_argument("--edition")
            p.add_argument("--book")
            p.add_argument("--date")
            p.add_argument("--year")
            p.add_argument("--confirm-app-stopped", action="store_true")
    args = parser.parse_args()
    if args.command == "list":
        for name, text in sorted(FAULTS.items()):
            print("%-28s %s" % (name, text))
        return 0
    return cmd_apply(args) if args.command == "apply" else cmd_restore(args)


if __name__ == "__main__":
    sys.exit(main())
