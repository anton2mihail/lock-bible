#!/usr/bin/env python3
"""Fetch the app's devotional artwork from Wikimedia Commons and normalise it.

Every painting the app shows is a historical work in the public domain. This
script is the only way they enter the repo: it reads assets/artwork/sources.json,
confirms each file is cleanly public domain, downloads a rendition, and writes a
1200x800 JPEG to assets/artwork/.

    python3 scripts/fetch-artwork.py                 # write any missing art
    python3 scripts/fetch-artwork.py --check         # verify licences only
    python3 scripts/fetch-artwork.py --force         # re-fetch everything
    python3 scripts/fetch-artwork.py --only mary joyful-1

Licence checking reads the file page's wikitext rather than the API's summary.
A Commons {{Artwork}} page carries two licences — one for the painting and one
for the photograph of it — and the API reports only the first. A museum
photograph of a public-domain painting can still be CC BY-SA, so the summary
alone will happily pass a file we cannot ship. See docs/john/artwork-sources.md.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "LockBible-artwork/1.0 (Catholic prayer app; public-domain artwork sourcing)"
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "artwork"
MANIFEST = OUT_DIR / "sources.json"
CREDITS = OUT_DIR / "credits.json"
CACHE = pathlib.Path(__file__).resolve().parent / ".artwork-cache"

TARGET_W, TARGET_H = 1200, 800
MAX_BYTES = 360 * 1024
QUALITY_LADDER = (90, 86, 82, 78, 74, 70)

# Any Creative Commons claim disqualifies the file, wherever it appears: it is
# usually the photographer's claim over a public-domain painting. Match the
# licence name anywhere inside a template, not just straight after the braces,
# because {{self|cc-by-sa-4.0}} puts "self|" in between and slips a plain
# "\{\{cc-by" pattern.
CC_TEMPLATE = re.compile(r"\{\{[^}]*?\b(cc-by[a-z0-9.-]*|cc-sa[a-z0-9.-]*)\b", re.IGNORECASE)

# A photograph the uploader released says nothing about the painting inside it.
# Fine for a flat PD-Art scan; not fine for a picture taken inside a church,
# where the painting's own copyright is simply never addressed.
SELF_RELEASED = re.compile(r"\{\{\s*(PD-self|PD-user|self)\b", re.IGNORECASE)
PD_ART = re.compile(r"\{\{\s*PD-(Art|old|scan)", re.IGNORECASE)

_last_call = [0.0]


def api(params: dict, attempts: int = 8) -> dict:
    """Throttled Commons API call; the API returns 429 under rapid bursts."""
    params["format"] = "json"
    url = f"{API}?{urllib.parse.urlencode(params)}"
    delay = 2.0
    for attempt in range(attempts):
        elapsed = time.monotonic() - _last_call[0]
        if elapsed < 2.0:
            time.sleep(2.0 - elapsed)
        _last_call[0] = time.monotonic()
        try:
            request = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code not in (429, 503) or attempt == attempts - 1:
                raise
            time.sleep(delay)
            delay = min(delay * 2, 90.0)
    raise RuntimeError("unreachable")


def plain(html: str | None) -> str:
    text = re.sub(r"<[^>]+>", " ", html or "")
    text = text.replace("&amp;", "&").replace("&nbsp;", " ").replace("&#160;", " ")
    return re.sub(r"\s+", " ", text).strip()


def lookup(title: str, width: int = 2600) -> dict | None:
    data = api(
        {
            "action": "query",
            "titles": title,
            "prop": "imageinfo",
            "iiprop": "url|size|extmetadata",
            "iiurlwidth": str(width),
        }
    )
    page = next(iter(((data.get("query") or {}).get("pages") or {}).values()), {})
    info = (page.get("imageinfo") or [None])[0]
    if not info:
        return None
    meta = info.get("extmetadata", {})
    return {
        "url": (info.get("thumburl") or info["url"]).split("?")[0],
        "pageUrl": info.get("descriptionurl", ""),
        "width": info.get("width", 0),
        "height": info.get("height", 0),
        "licence": plain(meta.get("LicenseShortName", {}).get("value")),
    }


def licence_problem(title: str, licence: str) -> str | None:
    """Return why this file cannot ship, or None if it is cleanly public domain."""
    if "public domain" not in (licence or "").lower():
        return f"licence is {licence!r}, not public domain"

    data = api({"action": "parse", "page": title, "prop": "wikitext"})
    wikitext = ((data.get("parse") or {}).get("wikitext") or {}).get("*", "")
    if not wikitext:
        return "could not read the file page to confirm the photograph's licence"

    found = sorted({match.group(1).lower() for match in CC_TEMPLATE.finditer(wikitext)})
    if found:
        return f"the photograph carries a Creative Commons claim ({', '.join(found)})"

    if SELF_RELEASED.search(wikitext) and not PD_ART.search(wikitext):
        return (
            "only the photographer released their rights; nothing on the page puts "
            "the painting itself in the public domain"
        )
    return None


def render(entry: dict, source: pathlib.Path, dest: pathlib.Path) -> None:
    """Crop to the entry's window, then fill a 1200x800 frame under the size cap."""
    probe = subprocess.run(
        ["magick", "identify", "-format", "%w %h", f"{source}[0]"],
        capture_output=True,
        text=True,
        check=True,
    )
    width, height = (int(value) for value in probe.stdout.split())
    top = int(height * float(entry.get("top", 0.0)))
    bottom = int(height * float(entry.get("bottom", 1.0)))
    window = f"{width}x{max(bottom - top, 1)}+0+{top}"

    for quality in QUALITY_LADDER:
        subprocess.run(
            [
                "magick", f"{source}[0]",
                "-crop", window, "+repage",
                "-colorspace", "sRGB",
                "-resize", f"{TARGET_W}x{TARGET_H}^",
                "-gravity", entry.get("gravity", "center"),
                "-extent", f"{TARGET_W}x{TARGET_H}",
                "-strip",
                "-quality", str(quality),
                "-sampling-factor", "4:2:0",
                "-interlace", "JPEG",
                str(dest),
            ],
            check=True,
        )
        if dest.stat().st_size <= MAX_BYTES:
            return


ARTWORK_FIELD = re.compile(
    r"^\s*\|\s*(?:artist|author|creator|painter)\s*=\s*(.+?)\s*$", re.IGNORECASE | re.MULTILINE
)
DATE_FIELD = re.compile(r"^\s*\|\s*date\s*=\s*(.+?)\s*$", re.IGNORECASE | re.MULTILINE)
CREATOR_TEMPLATE = re.compile(r"\{\{\s*[Cc]reator\s*[:|]\s*([^}|]+)", re.IGNORECASE)
BOLD = re.compile(r"'{2,}")


def unwrap(value: str) -> str:
    """Reduce a Commons artist field to a plain name."""
    creator = CREATOR_TEMPLATE.search(value)
    if creator:
        return creator.group(1).strip()
    value = re.sub(r"\{\{[^}]*\}\}", " ", value)
    value = re.sub(r"\[\[[^|\]]*\|([^\]]*)\]\]", r"\1", value)
    value = re.sub(r"\[\[([^\]]*)\]\]", r"\1", value)
    value = re.sub(r"<[^>]+>", " ", value)
    value = BOLD.sub("", value)
    return " ".join(value.split()).strip(" ,;:|")


def painter_from_page(title: str) -> tuple[str, str]:
    """The painter and date from the file page, not the photographer.

    The API's `Artist` field names whoever took the photograph, so for a museum
    plate of a Leonardo it reports the uploader. The {{Artwork}} template's own
    `artist` field is the painter, usually wrapped in a {{creator:...}}, so read
    that instead. A wrong name under a painting is worse than no name at all.
    """
    data = api({"action": "parse", "page": title, "prop": "wikitext"})
    wikitext = ((data.get("parse") or {}).get("wikitext") or {}).get("*", "")
    if not wikitext:
        return "", ""
    artist = ""
    for match in ARTWORK_FIELD.finditer(wikitext):
        candidate = unwrap(match.group(1))
        # Skip photographer credits, which sit in an |author= under |photo license=.
        if candidate and not re.search(r"photo|own work|scan|user:", candidate, re.I):
            artist = candidate
            break
    date_match = DATE_FIELD.search(wikitext)
    return artist, unwrap(date_match.group(1)) if date_match else ""


def refresh_artists(manifest: dict) -> int:
    """Replace photographer credits in the manifest with the actual painter."""
    fixed = 0
    for slug, entry in sorted(manifest.items()):
        artist, date = painter_from_page(entry["file"])
        if artist and artist != entry.get("artist"):
            entry["artist"] = artist
            fixed += 1
        if date:
            entry["year"] = date
        print(f"  {slug:18} {entry['artist'][:46]}")
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    return fixed


def tidy_year(raw: str) -> str:
    """Commons date fields trail machine-readable junk; keep the human part."""
    year = (raw or "").split(" date QS")[0].split("date QS")[0].strip()
    return " ".join(year.split())[:40] or "date unknown"


def write_credits(manifest: dict) -> None:
    """Emit the artist line the app shows under each painting.

    Generated rather than hand-kept: with this many works a hard-coded list
    drifts the moment one entry is swapped, and a wrong attribution under a
    painting is worse than none.
    """
    credits = {
        slug: f"{entry['artist']}, {tidy_year(entry.get('year', ''))}"
        for slug, entry in sorted(manifest.items())
    }
    CREDITS.write_text(json.dumps(credits, indent=2, ensure_ascii=False) + "\n")
    print(f"credits for {len(credits)} paintings → {CREDITS.relative_to(ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="re-fetch art that already exists")
    parser.add_argument("--check", action="store_true", help="verify licences without writing art")
    parser.add_argument("--only", nargs="*", metavar="SLUG", help="limit to these assets")
    parser.add_argument(
        "--fix-artists", action="store_true",
        help="re-read the painter from each file page and rewrite the credits",
    )
    args = parser.parse_args()

    if not MANIFEST.exists():
        print(f"missing manifest: {MANIFEST}", file=sys.stderr)
        return 1
    manifest = json.loads(MANIFEST.read_text())

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(exist_ok=True)

    if args.fix_artists:
        fixed = refresh_artists(manifest)
        write_credits(manifest)
        print(f"\n{fixed} attribution(s) corrected.")
        return 0

    slugs = args.only or sorted(manifest)
    unknown = [slug for slug in slugs if slug not in manifest]
    if unknown:
        print(f"not in the manifest: {', '.join(unknown)}", file=sys.stderr)
        return 1

    failures = []
    for slug in slugs:
        entry = manifest[slug]
        dest = OUT_DIR / f"{slug}.jpg"
        if dest.exists() and not args.force and not args.check:
            print(f"  · {slug} already present")
            continue

        info = lookup(entry["file"])
        if not info:
            failures.append(f"{slug}: {entry['file']} not found on Commons")
            print(f"  ✗ {slug}  not found")
            continue

        problem = licence_problem(entry["file"], info["licence"])
        if problem:
            failures.append(f"{slug}: {problem}")
            print(f"  ✗ {slug}  {problem}")
            continue

        print(f"  ✓ {slug}  {info['licence']}  ({info['width']}x{info['height']})")
        if args.check:
            continue

        raw = CACHE / f"{slug}.src"
        if args.force or not raw.exists():
            subprocess.run(
                ["curl", "-sS", "-L", "--fail", "-A", UA, "-o", str(raw), info["url"]],
                check=True,
            )
        render(entry, raw, dest)
        print(f"      → {dest.relative_to(ROOT)}  {dest.stat().st_size // 1024}KB")

    write_credits(manifest)

    if failures:
        print(f"\n{len(failures)} asset(s) failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print(f"\n{len(slugs)} asset(s) verified public domain.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
