#!/usr/bin/env python3
"""Create a private upload key for a new Play app. Never replace an existing key."""
import argparse
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path.home() / ".local/share/john-android")
    parser.add_argument("--distinguished-name", default="CN=John Android Upload, O=North Boutique, C=CA")
    args = parser.parse_args()
    private = args.directory.expanduser().resolve()
    if private.is_relative_to(REPO):
        parser.exit(1, "The upload key must be outside the repository.\n")
    keytool = shutil.which("keytool")
    if not keytool:
        parser.exit(1, "JDK keytool is required.\n")
    private.mkdir(parents=True, mode=0o700, exist_ok=True)
    if private.stat().st_mode & 0o077:
        parser.exit(1, "The private directory must have mode 700.\n")
    keystore = private / "upload-key.jks"
    config = private / "release.properties"
    if keystore.exists() or config.exists():
        parser.exit(1, "An upload key or release configuration already exists. No files were changed.\n")
    # The characters need no Java properties escapes. PKCS12 uses one password.
    password = secrets.token_urlsafe(48)
    try:
        with tempfile.TemporaryDirectory(prefix="new-upload-key-", dir=private) as scratch_name:
            scratch = Path(scratch_name)
            password_file = scratch / "password"
            with password_file.open("x") as output:
                os.chmod(password_file, 0o600)
                output.write(password)
            staged_key = scratch / "upload-key.jks"
            result = subprocess.run([keytool, "-genkeypair", "-noprompt", "-storetype", "PKCS12",
                                     "-keystore", str(staged_key), "-alias", "john-upload",
                                     "-keyalg", "RSA", "-keysize", "4096", "-validity", "10000",
                                     "-dname", args.distinguished_name,
                                     "-storepass:file", str(password_file), "-keypass:file", str(password_file)],
                                    capture_output=True, text=True)
            if result.returncode:
                parser.exit(1, "keytool could not create the upload key. No passwords were printed.\n")
            os.chmod(staged_key, 0o600)
            staged_config = scratch / "release.properties"
            # Java Properties needs escaped backslashes in paths.
            escaped_path = str(keystore).replace("\\", "\\\\")
            with staged_config.open("x") as output:
                os.chmod(staged_config, 0o600)
                output.write(f"storeFile={escaped_path}\nstorePassword={password}\nkeyAlias=john-upload\nkeyPassword={password}\n")
            # Hard links fail if an existing key/config appeared during generation.
            os.link(staged_key, keystore)
            try:
                os.link(staged_config, config)
            except OSError:
                keystore.unlink()
                raise
            # Remove the temporary plaintext password. Secure deletion is not
            # guaranteed on SSDs; protect this computer with disk encryption.
            password_file.write_bytes(b"\0" * len(password))
            password_file.unlink()
        print(f"Upload key created: {keystore}")
        print(f"Private signing configuration created: {config}")
        print("Back up both files in the owner's secure storage before the first upload.")
    except OSError as error:
        parser.exit(1, f"Could not save the private upload key: {error}\n")


if __name__ == "__main__":
    main()
