#!/usr/bin/env python3
"""L26 host-side resource sampler. Source only. Read only.

Finds the John app and widget extension processes of ONE simulator device and records their memory.
Simulator processes are host processes. Their RSS and footprint come from host tools.
RSS is host-process resident memory. It does not prove physical-device peak memory.
Do not add the widget and app values together. Shared pages count in both.

Usage:
  l26_resource_sampler.py --udid UDID --out NEW.csv [--app-name John] [--widget-name JohnWidget]
                          [--interval 1.0] [--duration SECONDS | --stop-file PATH]
The output CSV file must not exist. Stop the sampler with Ctrl-C, the duration, or the stop file.
"""
import argparse
import csv
import datetime as dt
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PS_LINE = re.compile(r"^\s*(\d+)\s+(\d+)\s+(.*)$")


def find_processes(udid, app_name, widget_name):
    """Return {pid: (role, name, rss_kb)} for processes whose executable is inside this device's app bundles."""
    out = subprocess.run(["ps", "-axo", "pid=,rss=,command="], capture_output=True, text=True, check=True).stdout
    found = {}
    marker = f"/Devices/{udid.upper()}/"
    for line in out.splitlines():
        match = PS_LINE.match(line)
        if not match:
            continue
        pid, rss, command = int(match.group(1)), int(match.group(2)), match.group(3)
        if marker.lower() not in command.lower():
            continue
        if "/Bundle/Application/" not in command:
            continue
        if f".appex/{widget_name}" in command:
            found[pid] = ("widget", widget_name, rss)
        elif f".app/{app_name}" in command and ".appex/" not in command:
            found[pid] = ("app", app_name, rss)
    return found


def footprint(pid):
    """Return (phys_footprint, phys_footprint_peak) in bytes, or (None, None)."""
    with tempfile.TemporaryDirectory() as folder:
        target = os.path.join(folder, "fp.json")
        result = subprocess.run(["footprint", "-p", str(pid), "-j", target, "--noCategories"],
                                capture_output=True, text=True)
        if result.returncode != 0 or not os.path.exists(target):
            return None, None
        try:
            data = json.load(open(target))
            process = data["processes"][0]
            auxiliary = process.get("auxiliary", {})
            return auxiliary.get("phys_footprint", process.get("footprint")), auxiliary.get("phys_footprint_peak")
        except (OSError, ValueError, KeyError, IndexError):
            return None, None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--app-name", default="John")
    parser.add_argument("--widget-name", default="JohnWidget")
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--duration", type=float)
    parser.add_argument("--stop-file")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9A-Fa-f-]{36}", args.udid):
        sys.exit("--udid must be an explicit device UDID (never 'booted')")
    out = Path(args.out)
    if out.exists():
        sys.exit(f"output file already exists: {out}")
    out.parent.mkdir(parents=True, exist_ok=True)
    started = time.time()
    rows = 0
    with out.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["epoch", "utc", "role", "pid", "name", "rss_kb", "footprint_bytes", "footprint_peak_bytes"])
        try:
            while True:
                tick = time.time()
                for pid, (role, name, rss) in sorted(find_processes(args.udid, args.app_name, args.widget_name).items()):
                    now, peak = footprint(pid)
                    stamp = dt.datetime.fromtimestamp(time.time(), dt.timezone.utc).isoformat(timespec="milliseconds")
                    writer.writerow([f"{time.time():.3f}", stamp, role, pid, name, rss,
                                     "" if now is None else now, "" if peak is None else peak])
                    rows += 1
                handle.flush()
                if args.duration is not None and tick - started >= args.duration:
                    break
                if args.stop_file and os.path.exists(args.stop_file):
                    break
                time.sleep(max(0.0, args.interval - (time.time() - tick)))
        except KeyboardInterrupt:
            pass
    print(f"wrote {rows} rows to {out}")


if __name__ == "__main__":
    main()
