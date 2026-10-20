#!/usr/bin/env python3
"""Import every date in Vatican News' English Saint of the Day calendar.

Usage: python3 scripts/build-saints-calendar.py --cache /tmp/john-saints-source
The cache contains source HTML for review; it is never shipped. Each source
contributes at most 24 quoted words across the complete catalog.
"""
import argparse
import calendar
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import date
import hashlib
from html import unescape
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://www.vaticannews.va"
# The official index includes commemorations omitted from individual day pages.
# These names were checked against the index and day introductions.
MCI_INDEX_ADDITIONS = {
    "02-10": ["Scholastica"], "02-26": ["Photina"], "04-06": ["Methodius"],
    "04-28": ["Cyril"], "05-15": ["Isaiah"], "05-18": ["Seven Virgins"],
    "05-24": ["Nicetas"], "07-17": ["Gojdič"], "07-24": ["Boris"],
    "08-12": ["Clare of Assisi"], "08-28": ["Augustine"], "09-06": ["Archippus"],
    "09-09": ["Severian"], "09-12": ["Autonomus"], "10-28": ["Paraskeva"],
    "10-31": ["Stachys", "Epimachus"],
}


def text(html):
    return " ".join(unescape(re.sub(r"<[^>]+>", " ", html)).split())


def fetch(url, cache):
    path = cache / (hashlib.sha256(url.encode()).hexdigest() + ".html")
    if not path.exists():
        result = subprocess.run(
            ["curl", "--fail", "--location", "--silent", "--show-error",
             "--retry", "3", "--max-time", "45", url],
            check=True, capture_output=True,
        )
        path.write_bytes(result.stdout)
    return path.read_text()


def read_day(key, cache):
    # These two daily pages return 404. Vatican News supplies dedicated feast pages.
    supplements = {
        "11-01": ("Solemnity of All Saints", "solemnity-of-all-saints",
                  "The Solemnity of All Saints began in the East in the 4th century, and then spread elsewhere"),
        "11-02": ("Commemoration of all the Faithful Departed (All Souls’ Day)",
                  "commemoration-of-all-the-faithful-departed--all-souls-day-",
                  "The liturgy proposes various Masses on this day, all of which are geared toward highlighting the Paschal Mystery"),
    }
    if key in supplements:
        name, slug, excerpt = supplements[key]
        url = f"{BASE}/en/liturgical-holidays/{slug}.html"
        if excerpt not in text(fetch(url, cache)):
            raise ValueError(f"Supplement changed: {url}")
        return key, [{"id": key + "-observance", "monthDay": key, "name": name,
                      "sourceURL": url, "calendarURL": url, "_description": excerpt + "…"}]
    url = f"{BASE}/en/saints/{key.replace('-', '/')}.html"
    html = fetch(url, cache)
    if 'class="vatican-news list-saint"' not in html:
        raise ValueError(f"Unexpected calendar page: {url}")
    entries = []
    for section in re.findall(r'<section\b[^>]*section--isStatic[^>]*>(.*?)</section>', html, re.S):
        heading = re.search(r"<h2[^>]*>(.*?)</h2>", section, re.S)
        if not heading:
            raise ValueError(f"Missing saint title: {url}")
        name = text(heading[1])
        paragraphs = re.findall(r"<p\b[^>]*>(.*?)</p>", section, re.S)
        description = " ".join(filter(None, map(text, paragraphs)))
        link = re.search(r'class="saintReadMore"\s+href="([^"]+)"', section)
        source = BASE + unescape(link[1]) if link else url
        if link:
            detail = fetch(source, cache)
            body = re.search(r'<div class="section__content santi--detail">(.*?)<div class="article_banner"', detail, re.S)
            if not body:
                raise ValueError(f"Missing biography: {source}")
            paragraphs = re.findall(r"<p\b[^>]*>(.*?)</p>", body[1], re.S)
            description = " ".join(filter(None, map(text, paragraphs)))
        entries.append({
            "id": key + "-" + hashlib.sha256(name.encode()).hexdigest()[:12],
            "monthDay": key, "name": name, "sourceURL": source,
            "calendarURL": url, "_description": description,
        })
    return key, entries


def byzantine_index(cache):
    url = "https://mci.archpitt.org/menaion/index.html"
    html = fetch(url, cache)
    result = {}
    key = None
    for kind, body in re.findall(r'<p class="(date|entry)">(.*?)</p>', html, re.S):
        if kind == "date":
            label = text(body)
            try:
                month, day = label.split()
                key = f"{list(calendar.month_name).index(month):02}-{int(day):02}"
            except ValueError:
                key = None
                continue
            result[key] = {"linked": 'href="' in body, "names": []}
        elif key:
            result[key]["names"].extend(filter(None, (text(part) for part in re.split(r"<br\s*/?>", body))))
    if len(result) != 366:
        raise ValueError(f"Expected all 366 Menaion dates, got {len(result)}")
    return result


def read_byzantine_day(key, cache, index):
    url = f"https://mci.archpitt.org/menaion/{key}.html"
    try:
        html = fetch(url, cache)
    except subprocess.CalledProcessError as error:
        # Some existing day pages are not linked by the index. Try them first;
        # only a confirmed 404 on an unlinked date permits an index-only entry.
        if index[key]["linked"] or error.returncode not in (22, 56) or b"returned error: 404" not in error.stderr:
            raise
        url = "https://mci.archpitt.org/menaion/index.html"
        return key, [{
            "id": key + "-" + hashlib.sha256(name.encode()).hexdigest()[:12],
            "monthDay": key, "name": name, "sourceURL": url, "calendarURL": url,
            "_description": "",
        } for name in index[key]["names"]]
    intro = re.search(r"<h1\b[^>]*>.*?</h1>\s*(<blockquote>.*?</blockquote>)", html, re.S | re.I)
    if not intro:
        raise ValueError(f"Missing Menaion introduction: {url}")
    # December 31 has an unclosed introductory blockquote around the services.
    # A liturgical heading always ends the biographical introduction.
    body = re.split(r"<h[2-6]\b", intro[1], maxsplit=1, flags=re.I)[0]
    # One name can have separate bold spans around an alternative spelling.
    body = re.sub(r"</strong>\s*(<em>\s*or:\s*</em>)\s*<strong[^>]*>", r" \1 ", body, flags=re.I)
    entries = []
    for paragraph in re.findall(r"<p\b[^>]*>(.*?)</p>", body, re.S | re.I):
        for heading in re.finditer(r"<strong[^>]*>(.*?)</strong>(.*?)(?=<strong|$)", paragraph, re.S | re.I):
            name = text(heading[1]).strip(" .,")
            if not name or name == "Day of Alleluia" or name.startswith("Here begins"):
                continue
            description = text(heading[2]).lstrip(" ,.")
            entry = {
                "id": key + "-" + hashlib.sha256(name.encode()).hexdigest()[:12],
                "monthDay": key, "name": name, "sourceURL": url,
                "calendarURL": url, "_description": description,
            }
            # Keep service-transfer instructions separate from the life account.
            notes = [text(part) for part in re.findall(r"<em>(.*?)</em>", paragraph, re.S | re.I)
                     if "transferred" in text(part).lower()]
            if notes:
                entry["observanceNote"] = " ".join(notes)
            entries.append(entry)
    if not entries:
        raise ValueError(f"No Menaion entries: {url}")
    for fragment in MCI_INDEX_ADDITIONS.get(key, []):
        matches = [name for name in index[key]["names"] if fragment in name]
        if len(matches) != 1:
            raise ValueError(f"Review changed Menaion index: {key} {fragment}")
        name = matches[0]
        entries.append({
            "id": key + "-" + hashlib.sha256(name.encode()).hexdigest()[:12],
            "monthDay": key, "name": name,
            "sourceURL": "https://mci.archpitt.org/menaion/index.html",
            "calendarURL": "https://mci.archpitt.org/menaion/index.html",
            "_description": "",
        })
    return key, entries


def build(cache, tradition):
    keys = [f"{month:02}-{day:02}" for month in range(1, 13)
            for day in range(1, calendar.monthrange(2024, month)[1] + 1)]
    # Vatican News has no English February 29 page (HTTP 404).
    if tradition == "vatican":
        keys.remove("02-29")
    index = byzantine_index(cache) if tradition == "byzantine" else None
    with ThreadPoolExecutor(max_workers=4) as pool:
        reader = read_day if tradition == "vatican" else lambda key, cache: read_byzantine_day(key, cache, index)
        days = dict(pool.map(lambda key: reader(key, cache), keys))
    entries = [entry for key in keys for entry in days[key]]
    uses = Counter(entry["sourceURL"] for entry in entries if entry["_description"])
    for entry in entries:
        words = entry.pop("_description").split()
        budget = 24 // max(1, uses[entry["sourceURL"]])
        selected = words[:budget]
        entry["excerpt"] = " ".join(selected) + ("…" if len(words) > budget else "")
    if tradition == "vatican":
        overrides = json.loads((ROOT / "scripts/saints-vatican-summaries.json").read_text())
        by_id = {entry["id"]: entry for entry in entries}
        for override in overrides:
            entry = by_id[override["id"]]
            # Keep the English calendar's date. The biography may use a different
            # language or commemoration date; it must not silently move the feast.
            source = fetch(override["sourceURL"], cache)
            if override.get("sourceHeading") and override["sourceHeading"] not in text(source):
                raise ValueError(f"Biography heading changed: {override['sourceURL']}")
            if override.get("sourceTextSHA256"):
                sections = re.findall(r'<section\b[^>]*section--isStatic[^>]*>(.*?)</section>', source, re.S)
                section = next((part for part in sections
                                if override["sourceHeading"] == text(re.search(r"<h2[^>]*>(.*?)</h2>", part, re.S)[1])), None)
                description = " ".join(map(text, re.findall(r"<p\b[^>]*>(.*?)</p>", section or "", re.S)))
                if hashlib.sha256(description.encode()).hexdigest() != override["sourceTextSHA256"]:
                    raise ValueError(f"Review changed biography: {override['id']}")
            entry.update({key: override[key] for key in ("summary", "sourceURL", "sourceLanguage")})
            entry["excerpt"] = ""
    if len({entry["id"] for entry in entries}) != len(entries):
        raise ValueError("Duplicate commemoration IDs")
    return {
        "schemaVersion": 1,
        "tradition": tradition,
        "sourceName": "Vatican News · Saint of the Day" if tradition == "vatican" else "Metropolitan Cantor Institute · Ruthenian Byzantine Catholic",
        "sourceURL": BASE + "/en/saints.html" if tradition == "vatican" else "https://mci.archpitt.org/menaion/index.html",
        "retrievedOn": date.today().isoformat(),
        "coverage": ("All entries on the English Vatican News Saint of the Day calendar. "
                    "Includes grouped saints, blesseds, and Marian observances. "
                    "These annual commemorations do not replace local liturgical calendars."
                    if tradition == "vatican" else
                    "Fixed commemorations from the Ruthenian Byzantine Catholic Menaion index and day accounts, United States, Gregorian dates. "
                    "Includes saints and other observances. Movable feasts and local calendars can differ. "
                    "A saint can appear on both a calendar date and a transferred service date. Consult the source and your parish for services. "
                    "In non-leap years, Cassian's service is on February 28 at Compline."),
        "checkedDates": keys,
        "entries": entries,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", required=True, type=Path)
    parser.add_argument("--tradition", choices=["vatican", "byzantine"], default="vatican")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    catalog = build(args.cache, args.tradition)
    if len(catalog["entries"]) < 400:
        raise ValueError("Incomplete calendar; refusing to replace the catalog")
    output = args.output or ROOT / f"src/services/companion/data/saints-{args.tradition}.json"
    output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    print(f'{len(catalog["entries"])} entries; {len(catalog["checkedDates"])} dates checked.')


if __name__ == "__main__":
    main()
