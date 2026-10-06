#!/usr/bin/env python3
"""L28 package inspection. Source only. Read only. Writes report.json and report.md to a new folder.

Run it on a built or archived John.app (for example Product.xcarchive/Products/Applications/John.app) or on the
app inside an exported IPA. It checks the facts that Gate E and L28 list. It does not sign, archive, upload or launch.

Status values:
  PASS        the observed value matches the expected value.
  FAIL        the observed value does not match, or a forbidden item is present.
  REVIEW      a person must read the observed facts (for example required-reason API hits).
  USER-GATED  the check needs a signed package, a signing identity, or App Store Connect. Not evaluated here.

Usage:
  l28_inspect_package.py --app PATH/John.app --out-dir NEW_DIR --stage unsigned|archive|export
                         [--platform device|simulator] [--expect-version 1.5.0 --expect-build 19]
                         [--team QZ44N522NQ] [--source-root REPO] [--extended-debug-args]
Stages:  unsigned = built with signing off. archive = inside .xcarchive (development signature allowed).
         export = App Store export (distribution signature, no get-task-allow).
"""
import argparse
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

EXPECT = {"appId": "com.nrsv.verse", "widgetId": "com.nrsv.verse.widget", "group": "group.com.nrsv.verse",
          "scheme": "nrsv", "minOS": "26.0"}

# Sol ruling 2 (Step7-remaining-feature-checks-review.md) with the correction in Step7-app-side-review.md:
# recordProbe is removed because Swift symbol names are mangled.
EXCLUDED_STRINGS = ["-L29MediaFailureURI", "-L29SharedProbeRelativePath", "l29-widget-probe", "l29.widgetProbe",
                    "commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                    "www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"]
FORBIDDEN_FILES = ("*.debug.dylib", "__preview.dylib", "*.xctest", "*.dSYM", "XC*.framework", "libXCTest*", "*.swiftmodule")

# Required-reason API categories. Symbol hints are undefined symbols or Objective-C/Swift names in the executable.
CATEGORIES = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": ["_stat", "_fstat", "_lstat", "_fstatat", "_getattrlist", "_fgetattrlist",
                                                  "NSFileCreationDate", "NSFileModificationDate", "creationDate"],
    "NSPrivacyAccessedAPICategorySystemBootTime": ["systemUptime", "_mach_absolute_time", "_mach_continuous_time"],
    "NSPrivacyAccessedAPICategoryDiskSpace": ["_statfs", "_statvfs", "_fstatfs", "volumeAvailableCapacity",
                                              "NSFileSystemFreeSize", "NSURLVolumeAvailableCapacity"],
    "NSPrivacyAccessedAPICategoryActiveKeyboards": ["activeInputModes"],
    "NSPrivacyAccessedAPICategoryUserDefaults": ["NSUserDefaults", "12UserDefaults"],
}

results = []


def record(check_id, status, title, detail):
    results.append({"id": check_id, "status": status, "title": title, "detail": detail})


def run(args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


def read_plist(path):
    try:
        return plistlib.loads(Path(path).read_bytes())
    except Exception:
        return None


def macho_files(root):
    found = []
    for path in sorted(Path(root).rglob("*")):
        if path.is_file() and not path.is_symlink():
            with path.open("rb") as handle:
                magic = handle.read(4)
            if magic in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xfe\xed\xfa\xcf"):
                found.append(path)
    return found


def build_version(path):
    out = run(["vtool", "-show-build", str(path)]).stdout
    platform = re.search(r"platform\s+(\S+)", out)
    minos = re.search(r"minos\s+(\S+)", out)
    return (platform.group(1) if platform else None, minos.group(1) if minos else None)


def signed_entitlements(bundle):
    result = run(["codesign", "-d", "--entitlements", ":-", str(bundle)])
    text = result.stdout
    start = text.find("<?xml")
    if result.returncode != 0 or start < 0:
        return None
    try:
        return plistlib.loads(text[start:].encode())
    except Exception:
        return None


def signature_facts(bundle):
    out = run(["codesign", "-dvv", str(bundle)]).stderr
    team = re.search(r"TeamIdentifier=(\S+)", out)
    authority = re.findall(r"Authority=(.+)", out)
    adhoc = "Signature=adhoc" in out
    return {"team": team.group(1) if team and team.group(1) != "not" else None, "authority": authority, "adhoc": adhoc}


def profile_summary(bundle):
    path = Path(bundle) / "embedded.mobileprovision"
    if not path.is_file():
        return None
    decoded = run(["security", "cms", "-D", "-i", str(path)]).stdout
    if not decoded:
        return {"readable": False}
    data = plistlib.loads(decoded.encode())
    entitlements = data.get("Entitlements", {})
    return {"readable": True, "teamIdentifiers": data.get("TeamIdentifier"), "expires": str(data.get("ExpirationDate")),
            "appGroups": entitlements.get("com.apple.security.application-groups"),
            "applicationIdentifier": entitlements.get("application-identifier"),
            "getTaskAllow": entitlements.get("get-task-allow"),
            "provisionedDevicesCount": len(data.get("ProvisionedDevices", [])) if "ProvisionedDevices" in data else None,
            "provisionsAllDevices": data.get("ProvisionsAllDevices", False)}  # no device IDs, no profile UUID


def undefined_symbol_set(path):
    """Exact undefined-symbol names of one Mach-O file. A '$...' suffix (for example $INODE64) is removed."""
    names = set()
    for line in run(["nm", "-u", str(path)]).stdout.splitlines():
        tokens = line.split()
        if tokens and not line.rstrip().endswith(":"):
            names.add(tokens[0].split("$")[0])
    return names


def scan_bytes(root, needles):
    hits = {n: [] for n in needles}
    encoded = {n: n.encode() for n in needles}
    for path in sorted(Path(root).rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        data = path.read_bytes()
        for needle, raw in encoded.items():
            if raw in data:
                hits[needle].append(str(path.relative_to(root)))
    return hits


def extended_debug_args(source_root):
    found = set()
    for path in Path(source_root, "native/John").rglob("*.swift"):
        if "SimulatorSupport" in path.parts:
            continue
        for match in re.finditer(r'"(-L\d\d[A-Za-z0-9]+)"', path.read_text(errors="replace")):
            found.add(match.group(1))
    return sorted(found)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--app", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--stage", required=True, choices=["unsigned", "archive", "export"])
    parser.add_argument("--platform", choices=["device", "simulator"], default="device")
    parser.add_argument("--expect-version")
    parser.add_argument("--expect-build")
    parser.add_argument("--team", default="QZ44N522NQ")
    parser.add_argument("--source-root", default=str(Path(__file__).resolve().parents[4]))
    parser.add_argument("--extended-debug-args", action="store_true")
    args = parser.parse_args()
    app = Path(args.app).resolve(strict=True)
    out = Path(args.out_dir)
    if out.exists():
        sys.exit(f"--out-dir already exists: {out}")
    widgets = sorted(app.glob("PlugIns/*.appex"))
    app_info = read_plist(app / "Info.plist") or {}
    record("C00", "PASS" if len(widgets) == 1 else "FAIL", "One embedded widget extension",
           f"found {[w.name for w in widgets]}")
    widget = widgets[0] if widgets else None
    widget_info = read_plist(widget / "Info.plist") if widget else {}
    widget_info = widget_info or {}

    # Identifiers
    record("C01", "PASS" if app_info.get("CFBundleIdentifier") == EXPECT["appId"] else "FAIL", "App bundle ID",
           f"observed {app_info.get('CFBundleIdentifier')}, expected {EXPECT['appId']}")
    record("C02", "PASS" if widget_info.get("CFBundleIdentifier") == EXPECT["widgetId"] else "FAIL", "Widget bundle ID",
           f"observed {widget_info.get('CFBundleIdentifier')}, expected {EXPECT['widgetId']}")
    versions = {k: (app_info.get(k), widget_info.get(k)) for k in ("CFBundleShortVersionString", "CFBundleVersion")}
    same = all(a == b for a, b in versions.values())
    detail = f"app/widget {versions}"
    ok = same
    if args.expect_version:
        ok = ok and app_info.get("CFBundleShortVersionString") == args.expect_version
    if args.expect_build:
        ok = ok and app_info.get("CFBundleVersion") == args.expect_build
    record("C03", "PASS" if ok else "FAIL", "Version and build equal in app and widget (and expected values)", detail)

    # Deployment floor
    floors = {"appInfo": app_info.get("MinimumOSVersion"), "widgetInfo": widget_info.get("MinimumOSVersion")}
    expected_platform = "IOS" if args.platform == "device" else "IOSSIMULATOR"
    machos = {}
    for label, bundle in (("app", app), ("widget", widget)):
        if bundle is None:
            continue
        executable = (read_plist(bundle / "Info.plist") or {}).get("CFBundleExecutable")
        if executable and (bundle / executable).is_file():
            machos[label] = build_version(bundle / executable)
    for path in app.glob("*.dylib"):
        machos[path.name] = build_version(path)
    floor_ok = all(v == EXPECT["minOS"] for v in floors.values()) and all(
        p == expected_platform and m == EXPECT["minOS"] for p, m in machos.values())
    record("C04", "PASS" if floor_ok and machos else "FAIL", "Deployment floor 26.0 (Info.plist and Mach-O) and platform",
           f"Info {floors}; Mach-O (platform, minos) {machos}; expected platform {expected_platform}")
    archs = {}
    for label, bundle in (("app", app), ("widget", widget)):
        if bundle is None:
            continue
        executable = (read_plist(bundle / "Info.plist") or {}).get("CFBundleExecutable")
        archs[label] = run(["lipo", "-archs", str(bundle / executable)]).stdout.strip() if executable else None
    record("C05", "PASS" if all(v == "arm64" for v in archs.values()) else "REVIEW", "Architectures", f"{archs}")

    # URL scheme
    schemes = sorted({s for t in app_info.get("CFBundleURLTypes", []) for s in t.get("CFBundleURLSchemes", [])})
    record("C06", "PASS" if schemes == [EXPECT["scheme"]] else "FAIL", "URL scheme", f"observed {schemes}")

    # App Group
    group_info = (app_info.get("AppGroupIdentifier"), widget_info.get("AppGroupIdentifier"))
    record("C07", "PASS" if group_info == (EXPECT["group"],) * 2 else "FAIL", "AppGroupIdentifier Info.plist value",
           f"app/widget {group_info}, expected {EXPECT['group']}")
    source_ent = {}
    for name in ("John-App-Update", "John-Widget-Update"):
        plist = read_plist(Path(args.source_root) / "native/John/Config" / f"{name}.entitlements") or {}
        source_ent[name] = plist.get("com.apple.security.application-groups")
    record("C08", "PASS" if all(v == [EXPECT["group"]] for v in source_ent.values()) else "FAIL",
           "Source Release entitlement files", f"{source_ent}")

    # Signing
    if args.stage == "unsigned":
        record("C09", "USER-GATED", "Signed IDs, App Group, team, profile",
               "Package is not signed with a distribution identity. Run again with --stage archive or export after the "
               "user provides the signing identity and team.")
    else:
        facts = {}
        failures = []
        for label, bundle in (("app", app), ("widget", widget)):
            ent = signed_entitlements(bundle) or {}
            sig = signature_facts(bundle)
            groups = ent.get("com.apple.security.application-groups")
            appid = ent.get("application-identifier")
            facts[label] = {"groups": groups, "applicationIdentifier": appid, "team": sig["team"],
                            "adhoc": sig["adhoc"], "getTaskAllow": ent.get("get-task-allow")}
            expected_id = EXPECT["appId" if label == "app" else "widgetId"]
            if groups != [EXPECT["group"]]:
                failures.append(f"{label}: signed App Group {groups}")
            if appid != f"{args.team}.{expected_id}":
                failures.append(f"{label}: application-identifier {appid}")
            if sig["team"] != args.team:
                failures.append(f"{label}: team {sig['team']}")
            if sig["adhoc"]:
                failures.append(f"{label}: ad hoc signature")
            if args.stage == "export" and ent.get("get-task-allow"):
                failures.append(f"{label}: get-task-allow is true in an export")
        verify = [run(["codesign", "--verify", "--deep", "--strict", str(app)]).returncode]
        if verify[0] != 0:
            failures.append("codesign --verify --deep --strict failed")
        record("C09", "FAIL" if failures else "PASS", "Signed IDs, App Group, team, signature validity",
               f"{facts}; failures {failures}")
        profiles = {label: profile_summary(bundle) for label, bundle in (("app", app), ("widget", widget)) if bundle}
        record("C10", "REVIEW", "Embedded provisioning profile summary (no device IDs, no profile UUID)", f"{profiles}")

    # Privacy manifests
    privacy_detail = {}
    privacy_fail = []
    declared = {}
    for label, bundle in (("app", app), ("widget", widget)):
        manifest = read_plist(bundle / "PrivacyInfo.xcprivacy") if bundle else None
        if manifest is None:
            privacy_fail.append(f"{label}: PrivacyInfo.xcprivacy missing or unreadable")
            continue
        types = {item.get("NSPrivacyAccessedAPIType"): item.get("NSPrivacyAccessedAPITypeReasons")
                 for item in manifest.get("NSPrivacyAccessedAPITypes", [])}
        declared[label] = types
        privacy_detail[label] = {"tracking": manifest.get("NSPrivacyTracking"),
                                 "trackingDomains": manifest.get("NSPrivacyTrackingDomains"),
                                 "collectedDataTypes": manifest.get("NSPrivacyCollectedDataTypes"),
                                 "accessedApiTypes": types}
        if manifest.get("NSPrivacyTracking") not in (False, None) or manifest.get("NSPrivacyTrackingDomains"):
            privacy_fail.append(f"{label}: tracking declared")
        if manifest.get("NSPrivacyCollectedDataTypes"):
            privacy_fail.append(f"{label}: collected data types declared")
    record("C11", "FAIL" if privacy_fail else "PASS", "Privacy manifests present; no tracking, no collected data",
           f"{privacy_detail}; failures {privacy_fail}")
    observed = {}       # label -> category -> sorted hints (union over files)
    observed_files = {}  # label -> relative file -> category -> hints
    for label, bundle in (("app", app), ("widget", widget)):
        if bundle is None:
            continue
        files = [p for p in macho_files(bundle) if label == "widget" or "PlugIns" not in p.relative_to(bundle).parts]
        per_file = {}
        for path in files:
            symbols = undefined_symbol_set(path)
            text = path.read_bytes()
            hits = {}
            for category, hints in CATEGORIES.items():
                names = [h for h in hints if (h in symbols if h.startswith("_") else h.encode() in text)]
                if names:
                    hits[category] = names
            if hits:
                per_file[str(path.relative_to(bundle))] = hits
        observed_files[label] = per_file
        merged = {}
        for hits in per_file.values():
            for category, names in hits.items():
                merged.setdefault(category, set()).update(names)
        observed[label] = {c: sorted(n) for c, n in merged.items()}
    missing = {label: sorted(set(hits) - set(declared.get(label, {}))) for label, hits in observed.items()}
    record("C12", "REVIEW" if any(missing.values()) else "PASS",
           "Required-reason API symbol hits versus declared categories (hints only)",
           f"observed (union) {observed}; per file {observed_files}; hit but not declared {missing}. Underscore hints "
           f"match exact undefined-symbol names (a $INODE64-style suffix is removed). A hint is not proof of use. Read Xcode's Privacy Report "
           "(Organizer, user step) and the source audit in native/John/Resources/Release/README.md.")

    # Debug exclusion
    hits = scan_bytes(app, EXCLUDED_STRINGS)
    bad = {k: v for k, v in hits.items() if v}
    record("C13", "FAIL" if bad else "PASS", "Debug exclusion: excluded strings in every file of the bundle",
           f"strings {EXCLUDED_STRINGS}; hits {bad or 'none'}")
    forbidden = sorted({str(p.relative_to(app)) for pattern in FORBIDDEN_FILES for p in app.rglob(pattern)})
    record("C14", "FAIL" if forbidden else "PASS", "Debug exclusion: debug dylibs and test frameworks absent",
           f"found {forbidden or 'none'}")
    if args.extended_debug_args:
        names = extended_debug_args(args.source_root)
        ext = {k: v for k, v in scan_bytes(app, names).items() if v}
        record("C15", "REVIEW" if ext else "PASS", "Extended DEBUG launch-argument names found in source (informational)",
               f"names {names}; hits in package {ext or 'none'}")

    # Icon and launch resources
    icons = app_info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {}).get("CFBundleIconName")
    record("C16", "PASS" if icons == "AppIcon" and (app / "Assets.car").is_file() else "FAIL",
           "Icon name and compiled catalog", f"CFBundleIconName {icons}; Assets.car present {(app / 'Assets.car').is_file()}. "
           "Run verify-release-package.py for the three AppIcon renditions.")
    launch = app_info.get("UILaunchStoryboardName")
    record("C17", "PASS" if launch == "SplashScreen" and (app / "SplashScreen.storyboardc").is_dir() else "FAIL",
           "Launch storyboard", f"UILaunchStoryboardName {launch}; compiled storyboard present "
           f"{(app / 'SplashScreen.storyboardc').is_dir()}; UILaunchScreen key {app_info.get('UILaunchScreen', 'absent')}")

    # Store metadata keys
    enc = app_info.get("ITSAppUsesNonExemptEncryption")
    record("C18", "PASS" if enc is False else "FAIL", "Export compliance key ITSAppUsesNonExemptEncryption = false",
           f"observed {enc}. The Expo app declared usesNonExemptEncryption false (app.json). The user must confirm the answer.")
    record("C19", "REVIEW", "Device family and orientations",
           f"UIDeviceFamily {app_info.get('UIDeviceFamily')}; orientations {app_info.get('UISupportedInterfaceOrientations')}; "
           f"iPad orientations {app_info.get('UISupportedInterfaceOrientations~ipad')}")

    out.mkdir(parents=True)
    report = {"formatVersion": 1, "app": str(app), "stage": args.stage, "results": results}
    (out / "report.json").write_text(json.dumps(report, indent=2, default=str) + "\n")
    lines = [f"# L28 package inspection ({args.stage})", "", f"Package: `{app}`", "",
             "| ID | Status | Check |", "| --- | --- | --- |"]
    lines += [f"| {r['id']} | {r['status']} | {r['title']} |" for r in results]
    lines += ["", "## Detail", ""] + [f"- **{r['id']} {r['status']}** {r['title']}: {r['detail']}" for r in results]
    (out / "report.md").write_text("\n".join(lines) + "\n")
    counts = {s: sum(r["status"] == s for r in results) for s in ("PASS", "FAIL", "REVIEW", "USER-GATED")}
    print(counts, "->", out)
    return 1 if counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
