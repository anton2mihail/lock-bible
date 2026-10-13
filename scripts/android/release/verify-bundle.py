#!/usr/bin/env python3
"""Verify a release AAB. Report public metadata only; never read signing passwords."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"


def run(command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        raise ValueError(f"Verification command failed: {Path(command[0]).name}. {result.stderr.strip()[-1500:]}")
    return result.stdout


def read_metadata(path):
    # These fields are ASCII and have no Java properties escapes.
    result = {}
    for line in path.read_text().splitlines():
        if line and not line.startswith(("#", "!")):
            key, value = line.split("=", 1)
            result[key] = value
    required = {"applicationId", "versionCode", "versionName", "minSdk", "targetSdk", "signed", "certificateSha256"}
    if required - result.keys():
        raise ValueError("Public release metadata is incomplete.")
    if result["minSdk"] != "26" or result["targetSdk"] != "36":
        raise ValueError("Expected minSdk 26 and targetSdk 36.")
    return result


def check_elf(data, name):
    if data[:4] != b"\x7fELF" or len(data) < 64:
        raise ValueError(f"Invalid ELF library: {name}")
    endian = {1: "<", 2: ">"}.get(data[5])
    if not endian:
        raise ValueError(f"Unknown ELF byte order: {name}")
    if data[4] == 2:
        offset = struct.unpack_from(endian + "Q", data, 32)[0]
        entry_size, count = struct.unpack_from(endian + "HH", data, 54)
        layout = endian + "IIQQQQQQ"
        alignment_index, offset_index, virtual_index = 7, 2, 3
    elif data[4] == 1:
        offset = struct.unpack_from(endian + "I", data, 28)[0]
        entry_size, count = struct.unpack_from(endian + "HH", data, 42)
        layout = endian + "IIIIIIII"
        alignment_index, offset_index, virtual_index = 7, 1, 2
    else:
        raise ValueError(f"Unknown ELF class: {name}")
    # 16 KB device support applies to the 64-bit Android ABIs.
    needs_16k = "/arm64-v8a/" in name or "/x86_64/" in name
    alignments = []
    if entry_size < struct.calcsize(layout) or offset + count * entry_size > len(data):
        raise ValueError(f"Invalid ELF program header: {name}")
    for index in range(count):
        header = struct.unpack_from(layout, data, offset + index * entry_size)
        if header[0] == 1:  # PT_LOAD
            alignment = header[alignment_index]
            alignments.append(alignment)
            if needs_16k and (alignment < 16384 or alignment & (alignment - 1)
                             or (header[offset_index] - header[virtual_index]) % 16384):
                raise ValueError(f"ELF LOAD segment does not support 16 KB pages: {name}")
    if not alignments:
        raise ValueError(f"ELF library has no LOAD segments: {name}")
    return {"entry": name, "loadAlignments": alignments, "requires16k": needs_16k}


def verify(bundle, metadata_path, bundletool=None, allow_unsigned=False):
    metadata = read_metadata(metadata_path)
    java = shutil.which("java")
    if not java:
        raise ValueError("JDK 17 or later is required.")
    is_signed = metadata["signed"] == "true"
    if not is_signed and not allow_unsigned:
        raise ValueError("The bundle is unsigned. It cannot be uploaded to Play.")
    if is_signed:
        if not metadata["certificateSha256"]:
            raise ValueError("Expected upload certificate fingerprint is missing.")
        signature = json.loads(run([java, str(Path(__file__).with_name("VerifyBundle.java")),
                                    str(bundle), metadata["certificateSha256"]]))
    else:
        signature = {"status": "unsigned; CI validation only"}
    with zipfile.ZipFile(bundle) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("The bundle contains duplicate entries.")
        if "base/manifest/AndroidManifest.xml" not in names or "BundleConfig.pb" not in names:
            raise ValueError("The file is not an Android App Bundle.")
        if archive.testzip():
            raise ValueError("Bundle ZIP integrity check failed.")
        catalog_name = "base/assets/Catalogs/devotional-catalogs.json"
        pinned_catalog = Path(__file__).resolve().parents[3] / "native/Android/content/companion.json"
        if not pinned_catalog.is_file() or catalog_name not in names:
            raise ValueError("The pinned devotional catalog or its packaged copy is missing.")
        catalog_bytes = archive.read(catalog_name)
        if catalog_bytes != pinned_catalog.read_bytes():
            raise ValueError("Packaged devotional catalog does not match the reviewed Android input.")
        catalog_sha256 = hashlib.sha256(catalog_bytes).hexdigest()
        provenance = json.loads(pinned_catalog.with_name("companion-provenance.json").read_text())
        if catalog_sha256 != provenance["catalog"]["sha256"]:
            raise ValueError("Packaged devotional catalog does not match its reviewed provenance.")
        libraries = [check_elf(archive.read(name), name) for name in names if name.endswith(".so")]
    manifest_check = "not checked; bundletool is required before upload"
    if bundletool:
        if not bundletool.is_file():
            raise ValueError("BUNDLETOOL_JAR does not exist.")
        prefix = [java, "-jar", str(bundletool)]
        run(prefix + ["validate", f"--bundle={bundle}"])
        manifest = ET.fromstring(run(prefix + ["dump", "manifest", f"--bundle={bundle}", "--module=base"]))
        sdk = manifest.find("uses-sdk")
        application = manifest.find("application")
        if sdk is None or application is None:
            raise ValueError("Bundle manifest is incomplete.")
        actual = {"applicationId": manifest.attrib["package"],
                  "versionCode": manifest.attrib[ANDROID_NS + "versionCode"],
                  "versionName": manifest.attrib[ANDROID_NS + "versionName"],
                  "minSdk": sdk.attrib[ANDROID_NS + "minSdkVersion"],
                  "targetSdk": sdk.attrib[ANDROID_NS + "targetSdkVersion"]}
        if any(metadata[key] != value for key, value in actual.items()):
            raise ValueError("Packaged identity or SDK versions do not match release inputs.")
        if application.attrib.get(ANDROID_NS + "debuggable", "false") != "false":
            raise ValueError("A debuggable bundle cannot be released.")
        if application.attrib.get(ANDROID_NS + "testOnly", "false") != "false":
            raise ValueError("A test-only bundle cannot be released.")
        manifest_check = "passed"
        if any(library["requires16k"] for library in libraries):
            config = run(prefix + ["dump", "config", f"--bundle={bundle}"])
            if "PAGE_ALIGNMENT_16K" not in config:
                raise ValueError("Bundle does not request 16 KB ZIP alignment for generated APKs.")
    elif libraries:
        raise ValueError("bundletool is required to check native library APK alignment.")
    with bundle.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    return {"bundle": bundle.name, "sha256": digest, "sizeBytes": bundle.stat().st_size,
            "applicationId": metadata["applicationId"], "versionCode": int(metadata["versionCode"]),
            "versionName": metadata["versionName"], "minSdk": 26, "targetSdk": 36,
            "devotionalCatalogSha256": catalog_sha256,
            "signature": signature, "bundletoolManifest": manifest_check,
            "nativeLibraries": libraries, "nativePageSize": "no native libraries" if not libraries else "ELF checks passed",
            "artifactVerified": is_signed and manifest_check == "passed",
            "storeSubmissionChecksComplete": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--bundletool", type=Path, default=Path(os.environ["BUNDLETOOL_JAR"]) if os.environ.get("BUNDLETOOL_JAR") else None)
    parser.add_argument("--allow-unsigned", action="store_true", help="CI only; never marks the artifact verified")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        report = verify(args.bundle, args.metadata, args.bundletool, args.allow_unsigned)
        rendered = json.dumps(report, indent=2) + "\n"
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(rendered)
        print(rendered, end="")
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, ET.ParseError, struct.error) as error:
        parser.exit(1, f"Bundle verification failed: {error}\n")


if __name__ == "__main__":
    main()
