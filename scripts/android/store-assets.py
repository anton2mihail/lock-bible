#!/usr/bin/env python3
"""Make John 1:1 Play listing graphics from the app's public-domain artwork.

Requires Pillow. The graphics are plain crops and resizes of real paintings:
the script draws no text, shapes, or gradients. No app screenshots are
generated, retouched, or resized by this script.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageOps, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = ROOT / "assets/play-store"
SOURCE_PATHS = {
    "icon": ROOT / "assets/artwork/john-icon.png",
    "illustration": ROOT / "assets/artwork/scripture.jpg",
    "listing": ROOT / "docs/android-play/store-listing.md",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def listing_fields() -> dict:
    content = SOURCE_PATHS["listing"].read_text(encoding="utf-8")
    fields = {}
    for field, heading, limit in (
        ("title", "App name", 30),
        ("shortDescription", "Short description", 80),
        ("fullDescription", "Full description", 4000),
        ("releaseNotes", "First release notes", 500),
    ):
        match = re.search(rf"^## {re.escape(heading)}\n\n```text\n(.*?)\n```", content, re.M | re.S)
        if not match:
            raise ValueError(f"Missing listing field: {heading}")
        value = match.group(1)
        if not value or len(value) > limit:
            raise ValueError(f"{heading} contains {len(value)} characters; limit is {limit}")
        fields[field] = value
    return {
        "language": "en-US",
        **fields,
        "characterCounts": {key: len(value) for key, value in fields.items()},
        "settings": {"appType": "app", "category": "BOOKS_AND_REFERENCE", "free": True,
                     "containsAds": False, "inAppPurchases": False,
                     "supportEmail": "contact@north.boutique"},
    }


def save_png(image: Image.Image, path: Path, mode: str) -> None:
    metadata = PngImagePlugin.PngInfo()
    metadata.add(b"sRGB", b"\x00")
    # Both app sources use sRGB. Explicitly tag the export for store upload.
    # A PNG sRGB chunk has no timestamp, so repeated exports are reproducible.
    image.convert(mode).save(path, "PNG", optimize=True, pnginfo=metadata)


def make_icon(output: Path) -> None:
    with Image.open(SOURCE_PATHS["icon"]) as source:
        icon = source.convert("RGBA").resize((512, 512), Image.Resampling.LANCZOS)
    save_png(icon, output / "icon-512.png", "RGBA")


def make_feature(output: Path) -> None:
    # A plain crop of Abraham Bloemaert's The Four Evangelists (public domain),
    # resized to the Play feature-graphic frame. No text or overlay is added.
    with Image.open(SOURCE_PATHS["illustration"]) as source:
        canvas = ImageOps.fit(source.convert("RGB"), (1024, 500),
                              Image.Resampling.LANCZOS, centering=(0.5, 0.45))
    save_png(canvas, output / "feature-1024x500.png", "RGB")


def validate_graphics(output: Path) -> None:
    for name, size, mode in (("icon-512.png", (512, 512), "RGBA"),
                             ("feature-1024x500.png", (1024, 500), "RGB")):
        path = output / name
        with Image.open(path) as image:
            if image.format != "PNG" or image.size != size or image.mode != mode:
                raise ValueError(f"Invalid graphic format: {path}")
            image.verify()
        if name == "icon-512.png" and path.stat().st_size > 1024 * 1024:
            raise ValueError("Store icon exceeds 1024 KB")


def validate_screenshots(output: Path) -> list[dict]:
    folder = output / "screenshots"
    files = sorted(path for path in folder.glob("*")
                   if path.suffix.lower() in {".png", ".jpg", ".jpeg"})
    if len(files) < 2:
        raise ValueError("At least two real Android screenshots are required")
    if len(files) > 8:
        raise ValueError("A phone listing supports no more than eight screenshots")
    records = []
    for path in files:
        with Image.open(path) as image:
            width, height = image.size
            if image.format not in {"PNG", "JPEG"} or image.mode != "RGB":
                raise ValueError(f"Screenshot must be RGB PNG/JPEG: {path}")
            if min(width, height) < 320 or max(width, height) > 3840 or max(width, height) > 2 * min(width, height):
                raise ValueError(f"Invalid Play screenshot dimensions {image.size}: {path}")
            image.verify()
        records.append({"path": str(path.relative_to(output)), "size": [width, height],
                        "sha256": digest(path)})
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check-screenshots", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    for path in SOURCE_PATHS.values():
        if not path.is_file():
            raise FileNotFoundError(f"Required source is missing: {path}")
    fields = listing_fields()
    screenshots = validate_screenshots(output) if args.check_screenshots else None
    output.mkdir(parents=True, exist_ok=True)
    make_icon(output)
    make_feature(output)
    (output / "listing-en-US.json").write_text(json.dumps(fields, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    validate_graphics(output)
    generated = ("icon-512.png", "feature-1024x500.png", "listing-en-US.json")
    manifest = {
        "formatVersion": 1,
        "generator": "scripts/android/store-assets.py",
        "artworkOrigin": "Public-domain paintings from Wikimedia Commons; see assets/CREDITS.md",
        "sources": [{"path": str(path.relative_to(ROOT)), "sha256": digest(path)}
                    for path in SOURCE_PATHS.values()],
        "outputs": [{"path": name, "bytes": (output / name).stat().st_size,
                     "sha256": digest(output / name)} for name in generated],
    }
    if screenshots is not None:
        manifest["screenshots"] = screenshots
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Created and checked listing assets in {output}")
    print(json.dumps(fields["characterCounts"]))
    if screenshots is not None:
        print(f"Checked {len(screenshots)} real Android screenshots")


if __name__ == "__main__":
    main()
