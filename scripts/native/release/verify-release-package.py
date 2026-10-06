#!/usr/bin/env python3
"""Read-only checks for a built app and embedded widget release package."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def required_path(value: str, label: str) -> Path:
    path = Path(value).expanduser().resolve(strict=True)
    if not path.exists():
        raise SystemExit(f"{label} does not exist: {path}")
    return path


def read_info(bundle: Path) -> tuple[dict[str, Any] | None, str | None]:
    info = bundle / "Info.plist"
    if not info.is_file():
        return None, "Info.plist missing"
    try:
        value = plistlib.loads(info.read_bytes())
        if not isinstance(value, dict):
            return None, "Info.plist root is not a dictionary"
        return value, None
    except Exception as error:  # Keep reports useful for malformed bundles.
        return None, f"Info.plist parse failed: {type(error).__name__}"


def bundle_facts(bundle: Path, target: str, report_errors: list[str]) -> dict[str, Any]:
    info, error = read_info(bundle)
    if error:
        report_errors.append(f"{target}: {error}")
        info = {}
    url_schemes: list[str] = []
    for item in info.get("CFBundleURLTypes", []) if isinstance(info, dict) else []:
        if isinstance(item, dict):
            url_schemes.extend(str(value) for value in item.get("CFBundleURLSchemes", []) if isinstance(value, str))
    fonts = info.get("UIAppFonts", []) if isinstance(info, dict) else []
    return {
        "bundlePath": str(bundle),
        "bundleID": info.get("CFBundleIdentifier") if isinstance(info, dict) else None,
        "version": info.get("CFBundleShortVersionString") if isinstance(info, dict) else None,
        "build": info.get("CFBundleVersion") if isinstance(info, dict) else None,
        "minimumOSVersion": info.get("MinimumOSVersion") if isinstance(info, dict) else None,
        "urlSchemes": sorted(set(url_schemes)),
        "appGroupIdentifierInfoKey": info.get("AppGroupIdentifier") if isinstance(info, dict) else None,
        "uiAppFonts": fonts if isinstance(fonts, list) else [],
    }


def signed_groups(bundle: Path) -> dict[str, Any]:
    codesign = shutil.which("codesign")
    if not codesign:
        return {"status": "unavailable", "appGroups": []}
    result = subprocess.run(
        [codesign, "-d", "--entitlements", ":-", str(bundle)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )
    output = result.stdout or ""
    start = output.find("<?xml")
    if start < 0:
        start = output.find("<plist")
    if result.returncode != 0 or start < 0:
        return {"status": "unavailable", "appGroups": [], "reason": "signed entitlements were not readable"}
    try:
        entitlements = plistlib.loads(output[start:].encode("utf-8"))
    except Exception:
        return {"status": "unavailable", "appGroups": [], "reason": "entitlements output was not valid plist data"}
    groups = entitlements.get("com.apple.security.application-groups", []) if isinstance(entitlements, dict) else []
    return {"status": "observed", "appGroups": sorted(value for value in groups if isinstance(value, str))}


def resource_digest_index(bundle: Path, wanted_names: set[str]) -> dict[str, list[dict[str, str]]]:
    index: dict[str, list[dict[str, str]]] = {}
    if not bundle.is_dir():
        return index
    for path in bundle.rglob("*"):
        relative_parts = path.relative_to(bundle).parts
        if any(part.endswith((".appex", ".app", ".framework", ".xpc")) for part in relative_parts[:-1]):
            continue
        if not path.is_file() or path.name not in wanted_names:
            continue
        try:
            digest = sha(path)
        except OSError:
            continue
        index.setdefault(path.name, []).append({"path": str(path.relative_to(bundle)), "sha256": digest})
    return index


def asset_report(app: Path, expected_icon_source_files: list[str], required_names: list[str]) -> dict[str, Any]:
    car = app / "Assets.car"
    empty = {"catalogNames": [], "requiredCatalogNames": required_names,
             "requiredIconVariants": ["light", "dark", "tinted"], "observedIconVariants": [],
             "expectedStagedIconFiles": expected_icon_source_files}
    if not car.is_file():
        return {"status": "missing", "path": "Assets.car", **empty}
    assetutil = shutil.which("assetutil")
    if not assetutil:
        return {"status": "unavailable", "path": "Assets.car", **empty}
    result = subprocess.run([assetutil, "--info", str(car)], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, check=False)
    if result.returncode != 0:
        return {"status": "error", "path": "Assets.car", **empty,
                "error": "assetutil could not read the compiled catalog"}
    try:
        rows = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"status": "error", "path": "Assets.car", **empty,
                "error": "assetutil output was not JSON"}
    names = sorted({row.get("Name") for row in rows if isinstance(row, dict) and isinstance(row.get("Name"), str)})
    missing_names = sorted(set(required_names) - set(names))
    icon_rows = [row for row in rows if isinstance(row, dict)
                 and row.get("Name") == "AppIcon" and row.get("AssetType") == "Icon Image"]
    variants: dict[str, list[dict[str, Any]]] = {"light": [], "dark": [], "tinted": []}
    for row in icon_rows:
        appearance = row.get("Appearance")
        variant = ("dark" if appearance == "UIAppearanceDark" else
                   "tinted" if appearance == "ISAppearanceTintable" else "light" if appearance is None else None)
        if variant is not None:
            variants[variant].append({
                "appearance": appearance,
                "renditionName": row.get("RenditionName"),
                "pixelWidth": row.get("PixelWidth"),
                "pixelHeight": row.get("PixelHeight"),
            })
    missing_variants = [name for name, values in variants.items() if not values]
    status = "verified" if not missing_names and not missing_variants else "missing-assets"
    return {
        "status": status,
        "path": "Assets.car",
        "catalogNames": names,
        "requiredCatalogNames": required_names,
        "missingCatalogNames": missing_names,
        "requiredIconVariants": ["light", "dark", "tinted"],
        "observedIconVariants": variants,
        "missingIconVariants": missing_variants,
        "expectedStagedIconFiles": expected_icon_source_files,
        "renditionNameNote": "Compiled rendition names are reported as observed. They are not compared with staged PNG filenames.",
    }


def storyboard_report(app: Path) -> dict[str, Any]:
    candidates = []
    for path in app.rglob("SplashScreen.storyboardc"):
        relative_parts = path.relative_to(app).parts
        if path.is_dir() and not any(part.endswith((".appex", ".app", ".framework", ".xpc"))
                                     for part in relative_parts[:-1]):
            candidates.append(path)
    expected = [path / "SplashScreenViewController.nib" for path in candidates]
    present = [str(path.relative_to(app)) for path in expected if path.is_file()]
    return {"status": "verified" if present else "missing", "compiledResources": present,
            "expectedControllerNib": "SplashScreen.storyboardc/SplashScreenViewController.nib"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, help="Path to the built .app bundle")
    parser.add_argument("--widget", required=True, help="Path to the embedded widget .appex bundle")
    parser.add_argument("--manifest", required=True, help="Accepted staged resource-manifest.json")
    parser.add_argument("--evidence-dir", required=True, help="New, empty directory for report.json")
    args = parser.parse_args()

    app = required_path(args.app, "app bundle")
    widget = required_path(args.widget, "widget bundle")
    manifest_path = required_path(args.manifest, "resource manifest")
    if app.suffix != ".app" or widget.suffix != ".appex" or not app.is_dir() or not widget.is_dir():
        raise SystemExit("--app must be a .app directory and --widget must be an .appex directory")
    if not inside(widget, app):
        raise SystemExit("the embedded widget path must be inside the app bundle")
    evidence = Path(args.evidence_dir).expanduser().resolve()
    if evidence.exists():
        raise SystemExit("--evidence-dir must be a new path that does not already exist")
    if inside(evidence, app) or inside(evidence, widget):
        raise SystemExit("evidence output must be outside app and widget bundles")
    if inside(evidence, manifest_path.parent) or inside(manifest_path.parent, evidence):
        raise SystemExit("evidence output must be separate from the staged manifest tree")
    for named in (app, widget, manifest_path):
        if named == evidence:
            raise SystemExit("evidence output must not overlap an input path")

    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    resources = manifest.get("resources")
    if manifest.get("formatVersion") != 1 or not isinstance(resources, list):
        raise SystemExit("resource manifest must use formatVersion 1 and contain resources")

    errors: list[str] = []
    app_facts = bundle_facts(app, "app", errors)
    widget_facts = bundle_facts(widget, "widget", errors)
    report: dict[str, Any] = {
        "formatVersion": 1,
        "check": "release-package-read-only-v1",
        "passScope": "resource presence, manifest hashes, and compiled launch/icon structure only",
        "checkedAtUTC": dt.datetime.now(dt.timezone.utc).isoformat(),
        "manifest": {"path": str(manifest_path), "sha256": hashlib.sha256(manifest_bytes).hexdigest(),
                     "sourceCommit": manifest.get("sourceCommit")},
        "toolchain": {"xcodeVersion": None, "xcodeBuild": None},
        "targets": {
            "app": {**app_facts, "signedEntitlements": signed_groups(app)},
            "widget": {**widget_facts, "signedEntitlements": signed_groups(widget)},
        },
        "resources": [],
        "manifestTargetMap": [],
        "compiledAssets": {},
        "compiledLaunchStoryboard": {},
        "limitations": [
            "Bundle IDs, versions, deployment floor, URL schemes, and App Group values are observed facts. They are not compared with a production release configuration.",
            "A passed result is not archive readiness, signing readiness, or release approval.",
            "Assets.car rendition presence does not prove source PNG byte identity or pixel identity.",
            "Signed App Group entitlements do not prove effective container access.",
            "This check does not inspect a live app container or change signing state.",
        ],
        "errors": errors,
    }

    expected_icon_source_files: list[str] = []
    expected_files = [row for row in resources if isinstance(row, dict) and row.get("kind") not in {
        "canonical-app-icon", "canonical-launch-mark", "canonical-launch-color",
        "asset-catalog-index", "asset-catalog-metadata", "canonical-launch-layout",
    }]
    app_names = {Path(row["staged"]).name for row in expected_files if not str(row.get("staged", "")).startswith("Widget/")}
    widget_names = {Path(row["staged"]).name for row in expected_files if str(row.get("staged", "")).startswith("Widget/")}
    digest_indexes = {"app": resource_digest_index(app, app_names),
                      "widget": resource_digest_index(widget, widget_names)}
    for row in resources:
        if not isinstance(row, dict):
            report["errors"].append("manifest contains a non-dictionary resource row")
            continue
        staged = str(row.get("staged", ""))
        kind = str(row.get("kind", ""))
        expected_hash = str(row.get("sha256", ""))
        target = "widget" if staged.startswith("Widget/") else "app"
        report["manifestTargetMap"].append({"stagedPath": staged, "target": target, "kind": kind})
        if kind == "canonical-app-icon":
            expected_icon_source_files.append(Path(staged).name)
            continue
        if kind in {"canonical-launch-mark", "canonical-launch-color", "asset-catalog-index", "asset-catalog-metadata"}:
            continue
        if kind == "canonical-launch-layout":
            continue
        bundle = widget if target == "widget" else app
        basename = Path(staged).name
        matches = [candidate for candidate in digest_indexes[target].get(basename, [])
                   if candidate["sha256"] == expected_hash]
        if kind == "shipped-font":
            font_path = next((value for value in app_facts.get("uiAppFonts", [])
                              if isinstance(value, str) and Path(value).name == basename), None)
            if font_path:
                candidate = (app / font_path).resolve()
                relative_candidate = candidate.relative_to(app).parts if inside(candidate, app) else ()
                nested_bundle = any(part.endswith((".appex", ".app", ".framework", ".xpc"))
                                    for part in relative_candidate[:-1])
                if inside(candidate, app) and not nested_bundle and candidate.is_file() and sha(candidate) == expected_hash:
                    matches = [{"path": str(candidate.relative_to(app)), "sha256": expected_hash}]
                else:
                    matches = []
            else:
                matches = []
        resource_row = {"stagedPath": staged, "target": target, "kind": kind,
                        "expectedSHA256": expected_hash, "matches": matches,
                        "status": "verified" if matches else "missing-or-hash-mismatch"}
        report["resources"].append(resource_row)
        if not matches:
            report["errors"].append(f"resource missing or hash differs: {target}:{basename}")

    for bundle_key, facts in (("app", app_facts), ("widget", widget_facts)):
        fonts = facts.get("uiAppFonts", [])
        if bundle_key == "app":
            required_fonts = [Path(row["staged"]).name for row in resources
                              if isinstance(row, dict) and row.get("kind") == "shipped-font"]
            listed = {Path(value).name for value in fonts if isinstance(value, str)}
            missing = sorted(set(required_fonts) - listed)
            if missing:
                report["errors"].append(f"UIAppFonts omits required font names: {', '.join(missing)}")
            report["targets"][bundle_key]["uiAppFontsMissing"] = missing
    report["compiledAssets"] = asset_report(
        app, expected_icon_source_files, ["AppIcon", "SplashScreenLogo", "SplashScreenBackground"]
    )
    if report["compiledAssets"].get("status") not in {"verified"}:
        report["errors"].append("compiled asset catalog or required icon renditions are missing")
    report["compiledLaunchStoryboard"] = storyboard_report(app)
    if report["compiledLaunchStoryboard"].get("status") != "verified":
        report["errors"].append("compiled launch storyboard resources are missing")

    version = subprocess.run(["xcodebuild", "-version"], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, text=True, check=False)
    version_lines = version.stdout.strip().splitlines() if version.returncode == 0 else []
    report["toolchain"]["xcodeVersion"] = version_lines[0] if version_lines else None
    report["toolchain"]["xcodeBuild"] = version_lines[1].removeprefix("Build version ") if len(version_lines) > 1 else None
    report["toolchain"]["assetutil"] = shutil.which("assetutil")
    report["passed"] = not report["errors"]

    evidence.mkdir(parents=True, exist_ok=False)
    output = evidence / "report.json"
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False, sort_keys=True) + "\n")
    print(json.dumps({"passed": report["passed"], "report": str(output), "errorCount": len(report["errors"])}))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
