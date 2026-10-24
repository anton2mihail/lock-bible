#!/usr/bin/env python3
"""Stage source-owned iOS release resources and write SHA-256 provenance."""

from __future__ import annotations

import hashlib
import json
import argparse
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUT = ROOT / "native/John/Resources/Release/Resources"
OUT = DEFAULT_OUT


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def copy(source: str, destination: str, kind: str) -> dict[str, str]:
    src = ROOT / source
    dst = OUT / destination
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    return {"source": source, "staged": destination, "sha256": sha(src), "kind": kind}


def write(destination: str, data: bytes, kind: str) -> dict[str, str]:
    dst = OUT / destination
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)
    return {"source": "scripts/native/release/prepare-release-resources.py", "staged": destination,
            "sha256": sha(dst), "kind": kind}


def privacy_manifest(reasons: list[tuple[str, list[str]]]) -> bytes:
    api_types = []
    for category, values in reasons:
        api_types.append({
            "NSPrivacyAccessedAPIType": category,
            "NSPrivacyAccessedAPITypeReasons": values,
        })
    value = {
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": api_types,
    }
    return plistlib.dumps(value, fmt=plistlib.FMT_XML, sort_keys=False)


def asset_contents(name: str) -> bytes:
    if name == "AppIcon":
        images = [
            {"filename": "App-Icon-1024x1024@1x.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"filename": "App-Icon-dark-1024x1024@1x.png", "idiom": "universal", "platform": "ios", "size": "1024x1024", "appearances": [{"appearance": "luminosity", "value": "dark"}]},
            {"filename": "App-Icon-tinted-1024x1024@1x.png", "idiom": "universal", "platform": "ios", "size": "1024x1024", "appearances": [{"appearance": "luminosity", "value": "tinted"}]},
        ]
        result = {"images": images, "info": {"author": "xcode", "version": 1}}
    else:
        result = {"images": [
            {"idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "filename": "image@3x.png", "scale": "3x"},
        ], "info": {"author": "xcode", "version": 1}}
    return (json.dumps(result, indent=2) + "\n").encode()


def main() -> None:
    global OUT
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--fresh-output", action="store_true",
                        help="Require a path that does not exist and publish only after verification.")
    parser.add_argument("--verify", type=Path, help="Verify an existing resource tree and exit.")
    args = parser.parse_args()
    if args.verify:
        verify_tree(args.verify.resolve())
        print(f"verified {args.verify.resolve()}")
        return
    requested_out = args.output_root.resolve()
    if args.fresh_output and requested_out.exists():
        raise SystemExit(f"fresh output already exists: {requested_out}")
    if not args.fresh_output and requested_out.exists() and any(requested_out.iterdir()):
        raise SystemExit(f"output directory is not empty: {requested_out}")
    requested_out.parent.mkdir(parents=True, exist_ok=True)
    temp_context = tempfile.TemporaryDirectory(prefix=f".{requested_out.name}.stage-", dir=requested_out.parent)
    OUT = Path(temp_context.name)
    rows: list[dict[str, str]] = []
    rows.append(write("App/PrivacyInfo.xcprivacy", privacy_manifest([
        # 1C8F.1: App Group state shared with the widget. CA92.1: the app's own UserDefaults
        # (purchase cache, rating-prompt counters, search history, sync and read-aloud settings).
        ("NSPrivacyAccessedAPICategoryUserDefaults", ["1C8F.1", "CA92.1"]),
        ("NSPrivacyAccessedAPICategoryFileTimestamp", ["C617.1"]),
    ]), "privacy-manifest-app"))
    rows.append(write("Widget/PrivacyInfo.xcprivacy", privacy_manifest([
        ("NSPrivacyAccessedAPICategoryUserDefaults", ["1C8F.1"]),
    ]), "privacy-manifest-widget"))

    icon_sources = [
        ("App-Icon-1024x1024@1x.png", "assets/artwork/john-icon.png"),
        ("App-Icon-dark-1024x1024@1x.png", "assets/artwork/john-icon-dark.png"),
        ("App-Icon-tinted-1024x1024@1x.png", "assets/artwork/john-icon-tinted.png"),
    ]
    rows.append(write("Assets.xcassets/Contents.json", b'{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n', "asset-catalog-index"))
    rows.append(write("Assets.xcassets/AppIcon.appiconset/Contents.json", asset_contents("AppIcon"), "asset-catalog-metadata"))
    for basename, source in icon_sources:
        rows.append(copy(source, f"Assets.xcassets/AppIcon.appiconset/{basename}", "canonical-app-icon"))
    rows.append(write("Assets.xcassets/SplashScreenLogo.imageset/Contents.json", asset_contents("SplashScreenLogo"), "asset-catalog-metadata"))
    # The canonical 360-pixel image is 120 points at 3x. Asset catalogs scale it
    # for lower-density screens without generated Expo project files.
    rows.append(copy("assets/artwork/john-splash.png",
                     "Assets.xcassets/SplashScreenLogo.imageset/image@3x.png", "canonical-launch-mark"))
    rows.append(copy("native/John/Resources/Launch/SplashScreenBackground.colorset/Contents.json",
                     "Assets.xcassets/SplashScreenBackground.colorset/Contents.json", "canonical-launch-color"))
    rows.append(copy("native/John/Resources/Launch/SplashScreen.storyboard", "Launch/SplashScreen.storyboard", "canonical-launch-layout"))

    font_files = [
        ("Lora_400Regular.ttf", "node_modules/@expo-google-fonts/lora/400Regular/Lora_400Regular.ttf"),
        ("Lora_500Medium.ttf", "node_modules/@expo-google-fonts/lora/500Medium/Lora_500Medium.ttf"),
        ("SpaceGrotesk_300Light.ttf", "node_modules/@expo-google-fonts/space-grotesk/300Light/SpaceGrotesk_300Light.ttf"),
        ("SpaceGrotesk_400Regular.ttf", "node_modules/@expo-google-fonts/space-grotesk/400Regular/SpaceGrotesk_400Regular.ttf"),
        ("SpaceGrotesk_500Medium.ttf", "node_modules/@expo-google-fonts/space-grotesk/500Medium/SpaceGrotesk_500Medium.ttf"),
        ("SpaceGrotesk_600SemiBold.ttf", "node_modules/@expo-google-fonts/space-grotesk/600SemiBold/SpaceGrotesk_600SemiBold.ttf"),
        ("SpaceGrotesk_700Bold.ttf", "node_modules/@expo-google-fonts/space-grotesk/700Bold/SpaceGrotesk_700Bold.ttf"),
    ]
    for name, source in font_files:
        rows.append(copy(source, f"App/Fonts/{name}", "shipped-font"))
    for source, name in [
        ("node_modules/@expo-google-fonts/lora/LICENSE_FONT", "Lora-OFL-1.1.txt"),
        ("node_modules/@expo-google-fonts/space-grotesk/LICENSE_FONT", "Space-Grotesk-OFL-1.1.txt"),
        ("native/John/Resources/Feather-LICENSE.txt", "react-native-feather-wrapper-MIT.txt"),
        ("scripts/native/release/licenses/feather/LICENSE", "Feather-icons-MIT.txt"),
        ("native/John/LegacyAdapter/Vendor/MMKVCore/LICENSE.TXT", "MMKV-Core-LICENSE.txt"),
        ("assets/READINGS-LICENSE.txt", "Catholic-Readings-API-MIT.txt"),
        ("assets/ROMCAL-LICENSE.txt", "Romcal-MIT.txt"),
        ("assets/CREDITS.md", "Artwork-and-Content-Credits.md"),
        ("assets/artwork/credits.json", "Artwork-Credits.json"),
        ("src/services/bible/data/web-ce/meta.json", "WEB-CE-Attribution.json"),
        ("src/services/bible/data/douay-rheims/meta.json", "Douay-Rheims-Attribution.json"),
        ("src/services/bible/data/vulgate/meta.json", "Clementine-Vulgate-Attribution.json"),
    ]:
        rows.append(copy(source, f"Legal/{name}", "license-or-attribution"))
    rows.append(copy("native/John/Resources/Feather.ttf", "App/Feather.ttf", "shipped-font"))

    manifest = {
        "formatVersion": 1,
        "sourceCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "generator": "scripts/native/release/prepare-release-resources.py",
        "generatorSHA256": sha(ROOT / "scripts/native/release/prepare-release-resources.py"),
        "resources": sorted(rows, key=lambda item: item["staged"]),
    }
    (OUT / "resource-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    verify_tree(OUT)
    if requested_out.exists():
        requested_out.rmdir()
    OUT.rename(requested_out)
    temp_context.cleanup()
    OUT = requested_out
    print(f"staged and verified {len(rows)} resources in {OUT}")


def verify_tree(root: Path) -> None:
    manifest = json.loads((root / "resource-manifest.json").read_text())
    if manifest.get("formatVersion") != 1 or not isinstance(manifest.get("resources"), list):
        raise SystemExit("invalid resource manifest")
    generator = ROOT / manifest.get("generator", "")
    if not generator.is_file() or sha(generator) != manifest.get("generatorSHA256"):
        raise SystemExit("generator hash does not match the resource manifest")
    rows = manifest["resources"]
    expected = {row["staged"] for row in rows} | {"resource-manifest.json"}
    actual = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
    if actual != expected:
        raise SystemExit(f"output tree mismatch: missing={sorted(expected - actual)} unexpected={sorted(actual - expected)}")
    for row in rows:
        destination = root / row["staged"]
        actual_hash = sha(destination)
        if actual_hash != row.get("sha256"):
            raise SystemExit(f"staged hash mismatch: {row['staged']}")
        source = row.get("source")
        if source and source != "scripts/native/release/prepare-release-resources.py":
            source_path = ROOT / source
            if not source_path.is_file() or sha(source_path) != actual_hash:
                raise SystemExit(f"source bytes differ from staged bytes: {row['staged']}")


if __name__ == "__main__":
    main()
