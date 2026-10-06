#!/usr/bin/env python3
"""L26 analysis. Source only. Reads logs and CSV files. Writes JSON and Markdown to a new folder.

Input: one or more text logs that contain the helper lines L26_CONFIG, L26_LAUNCH_SAMPLE, L26_CHAPTER_SAMPLE,
L26_SEARCH_SAMPLE and L26_SUMMARY (xcodebuild output, or `log stream` output from the device).
The script drops duplicate lines. It drops warm-up samples. It recomputes median and tail from the raw samples
and compares them with the helper's own L26_SUMMARY. It does not apply any performance budget.

Statistics:  n, min, median, mean, p90, p95 (nearest rank), p99 (nearest rank), max, standard deviation, IQR.
Nearest rank: sorted values, index ceil(p*n)-1.  With n = 20, p95 is the 19th value and p99 is the maximum.
With n = 3 the tail has no meaning. Three samples are preflight only.

Usage:
  l26_analyze.py --log RUN.log [--log MORE.log ...] --out-dir NEW_DIR
                 [--resources SAMPLER.csv] [--size SIZE.json] [--series NAME=v1,v2,...]
"""
import argparse
import csv
import datetime as dt
import json
import math
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

LINE = re.compile(r"(L26_[A-Z_]+)\s+(.*)$")
STAMP = re.compile(r"(\d{4}-\d\d-\d\d[ T]\d\d:\d\d:\d\d(?:\.\d+)?)")

DISCLAIMER = ("Simulator numbers. They include UI automation, typing, debounce and accessibility polling. "
              "'Cold' means a new app process, not a cold OS or file cache. They are not physical-device budgets. "
              "The proposed targets (median 1 s, p95 1.5 s, query 150 ms) are physical-device proposals and are not applied here.")


def nearest_rank(sorted_values, p):
    return sorted_values[max(0, math.ceil(p * len(sorted_values)) - 1)]


def stats(values):
    ordered = sorted(values)
    n = len(ordered)
    if n == 0:
        return {"n": 0}
    quartiles = statistics.quantiles(ordered, n=4, method="inclusive") if n >= 2 else [ordered[0]] * 3
    return {"n": n, "min": ordered[0], "median": statistics.median(ordered), "mean": statistics.fmean(ordered),
            "p90": nearest_rank(ordered, 0.90), "p95": nearest_rank(ordered, 0.95), "p99": nearest_rank(ordered, 0.99),
            "max": ordered[-1], "stdev": statistics.stdev(ordered) if n >= 2 else 0.0,
            "iqr": quartiles[2] - quartiles[0], "raw": values}


def key_value(text, key):
    match = re.search(rf"\b{key}=(\S+)", text)
    return match.group(1) if match else None


def parse(paths):
    seen, runs = set(), []
    current = None
    problems = []
    for path in paths:
        for raw_line in Path(path).read_text(errors="replace").splitlines():
            match = LINE.search(raw_line)
            if not match:
                continue
            tag, rest = match.group(1), match.group(2)
            stamp_match = STAMP.search(raw_line[:match.start()])
            stamp = (dt.datetime.fromisoformat(stamp_match.group(1).replace(" ", "T")).timestamp()
                     if stamp_match else None)
            if tag == "L26_CONFIG":
                current = {"config": rest, "stamps": {"config": stamp}, "long": {}, "launch": [], "chapter": [], "reference": [], "fts": [],
                           "summaries": {}, "source": str(path), "sampleCount": int(key_value(rest, "sampleCount") or 0),
                           "seen": set()}
                runs.append(current)
                continue
            if current is None:
                problems.append(f"{tag} line before any L26_CONFIG in {path}")
                continue
            ident = (tag, re.sub(r"\s+", " ", rest))
            if ident in current["seen"]:
                continue
            current["seen"].add(ident)
            if tag == "L26_LAUNCH_SAMPLE":
                current["launch"].append(float(key_value(rest, "seconds")))
            elif tag == "L26_CHAPTER_SAMPLE":
                if key_value(rest, "excludedWarmup") != "true":
                    current["chapter"].append(float(key_value(rest, "seconds")))
            elif tag == "L26_SEARCH_SAMPLE":
                if key_value(rest, "excludedWarmup") != "true":
                    kind = key_value(rest, "kind")
                    current["reference" if kind == "reference" else "fts"].append(float(key_value(rest, "seconds")))
            elif tag in ("L26_LONG_READER", "L26_LONG_WORK", "L26_LONG_TEXT"):
                current["stamps"][tag] = stamp
                current["long"][tag] = rest
            elif tag == "L26_SUMMARY":
                raw = key_value(rest, "raw") or ""
                current["summaries"][key_value(rest, "workload")] = {
                    "raw": [float(x) for x in raw.split(",") if x],
                    "median": float(key_value(rest, "median")), "p95": float(key_value(rest, "nearestRankP95"))}
    for run in runs:
        run.pop("seen")
    return runs, problems


def check_run(run, problems):
    count = run["sampleCount"]
    if count not in (3, 20):
        problems.append(f"{run['source']}: sample count {count} is not 3 or 20")
    run["classification"] = "preflight-only" if count == 3 else "recorded-distribution" if count == 20 else "invalid"
    workloads = {"cold-process-useful-today-launch": run["launch"], "chapter-open": run["chapter"],
                 "search-reference-user-action": run["reference"], "search-ordinary-fts-user-action": run["fts"]}
    run["workloads"] = {}
    for name, values in workloads.items():
        if not values:
            continue
        computed = stats(values)
        run["workloads"][name] = computed
        if len(values) != count:
            problems.append(f"{run['source']}: {name} has {len(values)} samples, config says {count}")
        helper = run["summaries"].get(name)
        if helper is None:
            problems.append(f"{run['source']}: no L26_SUMMARY for {name}")
        else:
            if sorted(helper["raw"]) != sorted(round(v, 6) for v in values):
                problems.append(f"{run['source']}: {name} raw samples differ from L26_SUMMARY")
            if abs(helper["median"] - computed["median"]) > 2e-6 or abs(helper["p95"] - computed["p95"]) > 2e-6:
                problems.append(f"{run['source']}: {name} median or p95 differs from L26_SUMMARY")


def long_journeys(runs, problems):
    """One value per run that holds a long-text journey. Values come from log timestamps (coarse, includes navigation)."""
    reader, works, whole = [], [], []
    for run in runs:
        marks = run["stamps"]
        if "L26_LONG_TEXT" not in marks:
            continue
        if None in (marks.get("config"), marks.get("L26_LONG_READER"), marks.get("L26_LONG_WORK"), marks["L26_LONG_TEXT"]):
            problems.append(f"{run['source']}: long-text lines have no timestamps; use the device log (log stream)")
            continue
        if "visible=true" not in run["long"].get("L26_LONG_READER", "") or "textChanged=true" not in run["long"].get("L26_LONG_WORK", ""):
            problems.append(f"{run['source']}: long-text journey did not report visible=true and textChanged=true")
        reader.append(marks["L26_LONG_READER"] - marks["config"])
        works.append(marks["L26_LONG_WORK"] - marks["L26_LONG_READER"])
        whole.append(marks["L26_LONG_TEXT"] - marks["config"])
    return {"reader-journey-from-config-to-psalm-119-176-visible": stats(reader),
            "works-journey-from-reader-log-to-page-2": stats(works),
            "whole-long-text-journey": stats(whole)} if whole else {}


def summarize_resources(path):
    rows = defaultdict(list)
    with open(path, newline="") as handle:
        for row in csv.DictReader(handle):
            if row["footprint_bytes"]:
                rows[(row["role"], row["pid"])].append(row)
    result = []
    for (role, pid), items in sorted(rows.items()):
        feet = [int(r["footprint_bytes"]) for r in items]
        peaks = [int(r["footprint_peak_bytes"]) for r in items if r["footprint_peak_bytes"]]
        rss = [int(r["rss_kb"]) for r in items]
        result.append({"role": role, "pid": int(pid), "samples": len(items), "firstEpoch": float(items[0]["epoch"]),
                       "lastEpoch": float(items[-1]["epoch"]), "footprintMedianBytes": statistics.median(feet),
                       "footprintMaxSampledBytes": max(feet), "footprintPeakReportedBytes": max(peaks) if peaks else None,
                       "rssMaxKB": max(rss)})
    by_role = defaultdict(list)
    for item in result:
        by_role[item["role"]].append(item)
    roles = {}
    for role, items in by_role.items():
        roles[role] = {"processes": len(items),
                       "worstFootprintPeakBytes": max((i["footprintPeakReportedBytes"] or i["footprintMaxSampledBytes"]) for i in items),
                       "worstRssKB": max(i["rssMaxKB"] for i in items)}
    return {"processes": result, "roles": roles,
            "note": "Footprint and RSS are host-process values. Report app and widget separately. Do not add them."}


def fmt(value):
    return f"{value:.4f}" if isinstance(value, float) else str(value)


def markdown(report):
    lines = ["# L26 analysis", "", f"> {DISCLAIMER}", ""]
    for index, run in enumerate(report["runs"], 1):
        if not run["workloads"]:
            continue
        lines += [f"## Run {index}: {run['classification']} (source {run['source']})", ""]
        lines += ["| Workload | n | min | median | mean | p90 | p95 | p99 | max | stdev | IQR |",
                  "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
        for name, s in run["workloads"].items():
            lines.append(f"| {name} | {s['n']} | " + " | ".join(fmt(s[k]) for k in
                         ("min", "median", "mean", "p90", "p95", "p99", "max", "stdev", "iqr")) + " |")
        lines.append("")
        if run["classification"] == "preflight-only":
            lines += ["Three samples are preflight only. Do not report a tail from them.", ""]
    if report.get("longJourneys"):
        lines += ["## Long text journeys (log timestamps, include navigation, not frame rate)", "",
                  "| Journey | n | min | median | p95 | max |", "| --- | --- | --- | --- | --- | --- |"]
        for name, s in report["longJourneys"].items():
            lines.append(f"| {name} | {s['n']} | " + " | ".join(fmt(s[k]) for k in ("min", "median", "p95", "max")) + " |")
        lines.append("")
    if report.get("series"):
        lines += ["## Extra series", "", "| Name | n | min | median | p95 | max |", "| --- | --- | --- | --- | --- | --- |"]
        for name, s in report["series"].items():
            lines.append(f"| {name} | {s['n']} | " + " | ".join(fmt(s[k]) for k in ("min", "median", "p95", "max")) + " |")
        lines.append("")
    if report.get("resources"):
        lines += ["## Memory (host values, sampled)", "", "| Role | Processes | Worst footprint peak (MiB) | Worst RSS (MiB) |",
                  "| --- | --- | --- | --- |"]
        for role, r in report["resources"]["roles"].items():
            lines.append(f"| {role} | {r['processes']} | {r['worstFootprintPeakBytes'] / 1048576:.1f} | {r['worstRssKB'] / 1024:.1f} |")
        lines += ["", report["resources"]["note"], ""]
    if report.get("size"):
        s = report["size"]
        lines += ["## Installed size (simulator build)", "",
                  f"- App bundle: {s['appBundleBytes']:,} bytes.",
                  f"- Extensions: " + ", ".join(f"{e['name']} {e['bytes']:,} bytes" for e in s["extensions"]) + ".",
                  f"- Duplicate content inside the bundle: {s['duplicateWastedBytes']:,} bytes."]
        for key in ("appDataContainer", "appGroupContainer"):
            if key in s:
                lines.append(f"- {key}: {s[key]['bytes']:,} bytes.")
        lines.append("")
    lines += ["## Problems", ""] + ([f"- {p}" for p in report["problems"]] or ["- None."]) + [""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--log", action="append", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--resources")
    parser.add_argument("--size")
    parser.add_argument("--series", action="append", default=[])
    args = parser.parse_args()
    out = Path(args.out_dir)
    if out.exists():
        sys.exit(f"--out-dir already exists: {out}")
    runs, problems = parse(args.log)
    if not runs:
        sys.exit("no L26_CONFIG line found in the logs")
    for run in runs:
        check_run(run, problems)
    long_series = long_journeys(runs, problems)
    for run in runs:
        for key in ("launch", "chapter", "reference", "fts", "stamps", "long"):
            run.pop(key, None)
    report = {"formatVersion": 1, "disclaimer": DISCLAIMER, "runs": runs, "problems": problems,
              "longJourneys": long_series}
    if args.resources:
        report["resources"] = summarize_resources(args.resources)
    if args.size:
        report["size"] = json.loads(Path(args.size).read_text())
    if args.series:
        report["series"] = {}
        for item in args.series:
            name, _, values = item.partition("=")
            report["series"][name] = stats([float(v) for v in values.split(",") if v])
    out.mkdir(parents=True)
    (out / "analysis.json").write_text(json.dumps(report, indent=2) + "\n")
    (out / "analysis.md").write_text(markdown(report))
    print(f"wrote {out}/analysis.json and analysis.md; problems: {len(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
