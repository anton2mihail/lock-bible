#!/usr/bin/env python3
"""Build and verify a signed Play bundle. Signing secrets stay outside this repo."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]
ANDROID = REPO / "native/Android"
PRIVATE = Path.home() / ".local/share/john-android"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundletool", type=Path, default=Path(os.environ.get("BUNDLETOOL_JAR", str(PRIVATE / "tools/bundletool.jar"))))
    parser.add_argument("--output-dir", type=Path, default=PRIVATE / "releases")
    args = parser.parse_args()
    properties = Path(os.environ.get("ANDROID_RELEASE_PROPERTIES_FILE", str(PRIVATE / "release.properties")))
    signing_names = ("ANDROID_UPLOAD_KEYSTORE", "ANDROID_UPLOAD_STORE_PASSWORD", "ANDROID_UPLOAD_KEY_ALIAS", "ANDROID_UPLOAD_KEY_PASSWORD")
    if not properties.is_file() and not all(os.environ.get(name) for name in signing_names):
        parser.exit(1, "Release signing inputs are missing. Set all ANDROID_UPLOAD_* inputs or create the private release.properties file. See native/Android/RELEASE.md.\n")
    if not args.bundletool.is_file():
        parser.exit(1, "bundletool is required before upload. Set BUNDLETOOL_JAR to the official bundletool JAR.\n")
    output_dir = args.output_dir.expanduser().resolve()
    if output_dir.is_relative_to(REPO):
        parser.exit(1, "Keep signed distribution output outside the repository.\n")
    output_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    environment = os.environ.copy()
    environment["ANDROID_ALLOW_UNSIGNED_RELEASE"] = "false"
    # Do not put passwords in command arguments or enable verbose Gradle logging.
    result = subprocess.run([str(ANDROID / "gradlew"), ":app:validateReleaseInputs", ":app:bundleRelease",
                             "--no-daemon", "--no-configuration-cache", "--console=plain"],
                            cwd=ANDROID, env=environment)
    if result.returncode:
        parser.exit(result.returncode, "The signed release build failed. No distribution artifact was saved.\n")
    spec = importlib.util.spec_from_file_location("verify_bundle", Path(__file__).with_name("verify-bundle.py"))
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    bundle = ANDROID / "app/build/outputs/bundle/release/app-release.aab"
    try:
        report = verifier.verify(bundle, ANDROID / "app/build/reports/release/release-inputs.properties", args.bundletool)
        if not report["artifactVerified"]:
            raise ValueError("The signed bundle did not pass all artifact checks.")
        name = f"{report['applicationId']}-{report['versionCode']}-{report['sha256'][:12]}"
        destination = output_dir / f"{name}.aab"
        report_path = output_dir / f"{name}.json"
        # Never replace a previous release artifact.
        report["bundle"] = destination.name
        if destination.exists() or report_path.exists():
            if not destination.is_file() or not report_path.is_file():
                raise ValueError("A previous release output is incomplete. No files were replaced.")
            with destination.open("rb") as source:
                existing_digest = hashlib.file_digest(source, "sha256").hexdigest()
            if existing_digest != report["sha256"] or json.loads(report_path.read_text()) != report:
                raise ValueError("Previous release output does not match this verified bundle. No files were replaced.")
            print(f"Verified signed bundle already saved: {destination}")
            print(f"Public verification report: {report_path}")
            return
        with tempfile.TemporaryDirectory(prefix="verified-bundle-", dir=output_dir) as scratch_name:
            scratch = Path(scratch_name)
            staged_bundle = scratch / destination.name
            with staged_bundle.open("xb") as output, bundle.open("rb") as source:
                os.chmod(staged_bundle, 0o600)
                shutil.copyfileobj(source, output)
            staged_report = scratch / report_path.name
            with staged_report.open("x") as output:
                os.chmod(staged_report, 0o600)
                json.dump(report, output, indent=2)
                output.write("\n")
            os.link(staged_bundle, destination)
            try:
                os.link(staged_report, report_path)
            except OSError:
                destination.unlink()
                raise
        print(f"Verified signed bundle: {destination}")
        print(f"Public verification report: {report_path}")
        print("This artifact still needs device tests and Play Console review.")
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, f"Release verification or output failed: {error}\n")


if __name__ == "__main__":
    main()
