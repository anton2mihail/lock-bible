#!/usr/bin/env python3
"""L26 static network-surface report. Source only. Read only.

Lists, for the app and each extension executable: linked frameworks, undefined symbols that name a network API,
and http(s) URL strings. It also lists the domains of http(s) URLs in bundled JSON catalogs.
This is package evidence about code that can reach the network. It does not block or observe traffic.
A clean result does not replace the runtime block and its positive control.

Usage: l26_static_network_surface.py --app /path/John.app [--out NEW.json]
"""
import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse

NETWORK_FRAMEWORKS = ("CFNetwork", "Network.framework", "WebKit", "AVFoundation", "AVKit", "MultipeerConnectivity",
                      "NetworkExtension", "SafariServices", "StoreKit", "CloudKit")
NETWORK_SYMBOL = re.compile(r"(NSURLSession|NSURLConnection|NSURLRequest|CFNetwork|CFURLConnection|CFReadStream|CFWriteStream|"
                            r"_nw_|NWConnection|getaddrinfo|_socket$|_connect$|_connectx$|WKWebView|AVPlayer|AVURLAsset)")
URL = re.compile(rb"https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]{4,200}")


def run(args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def executable_report(path):
    frameworks = [line.split()[0] for line in run(["otool", "-L", str(path)]).splitlines()[1:] if line.strip()]
    symbols = sorted({line.split()[-1] for line in run(["nm", "-u", str(path)]).splitlines()
                      if NETWORK_SYMBOL.search(line)})
    data = path.read_bytes()
    urls = sorted({m.group(0).decode("ascii", "replace") for m in URL.finditer(data)})
    return {"path": str(path), "linkedLibraries": frameworks,
            "networkFrameworksLinked": [f for f in frameworks if any(n in f for n in NETWORK_FRAMEWORKS)],
            "networkSymbols": symbols, "urlStrings": urls}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--app", required=True)
    parser.add_argument("--out")
    args = parser.parse_args()
    app = Path(args.app).resolve(strict=True)
    info = json.loads(run(["plutil", "-convert", "json", "-o", "-", str(app / "Info.plist")]))
    targets = [app / info.get("CFBundleExecutable", "John")]
    targets += [p for p in sorted(app.glob("PlugIns/*.appex/*")) if p.is_file() and p.suffix in ("", ".dylib")]
    targets += sorted(app.glob("Frameworks/*.framework/*"))
    targets += [p for p in sorted(app.glob("*.dylib"))]
    report = {"app": str(app), "executables": [executable_report(p) for p in targets if p.is_file()]}
    domains = Counter()
    for catalog in sorted(app.rglob("*.json")):
        try:
            for match in URL.finditer(catalog.read_bytes()):
                domains[urlparse(match.group(0).decode("ascii", "replace")).netloc] += 1
        except OSError:
            pass
    report["bundledJsonUrlDomains"] = dict(domains.most_common())
    text = json.dumps(report, indent=2) + "\n"
    if args.out:
        out = Path(args.out)
        if out.exists():
            sys.exit(f"output file already exists: {out}")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text)
    for item in report["executables"]:
        print(f"{Path(item['path']).relative_to(app)}: network frameworks {item['networkFrameworksLinked'] or 'none'}; "
              f"network symbols {len(item['networkSymbols'])}; URL strings {len(item['urlStrings'])}")
    print("bundled JSON URL domains:", dict(report["bundledJsonUrlDomains"]) or "none")


if __name__ == "__main__":
    main()
