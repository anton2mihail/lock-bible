#!/usr/bin/env python3
"""Run the production iOS notice service against an in-memory notification center."""
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix="john-saint-notices-") as folder:
    work = Path(folder)
    source = work / "Sources/Checks"
    source.mkdir(parents=True)
    for name in ("NoticeCenter.swift", "LocalNoticeService.swift"):
        shutil.copyfile(root / "native/John/Platform/Notifications" / name, source / name)
    shutil.copyfile(Path(__file__).with_name("MySaintsNoticeChecks.swift"), source / "Checks.swift")
    package = root / "native/John/Packages/JohnCore"
    (work / "Package.swift").write_text('''// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "SaintNoticeChecks", platforms: [.macOS(.v15)],
    dependencies: [.package(name: "JohnCore", path: %s)],
    targets: [.executableTarget(name: "Checks", dependencies: [.product(name: "JohnCore", package: "JohnCore")])])
''' % json.dumps(str(package)))
    subprocess.run(["swift", "run", "--package-path", str(work), "Checks", str(root)], check=True)
