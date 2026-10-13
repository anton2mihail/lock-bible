# Android release

The owner confirmed a new Google Play app under an organization account on
2026-10-13. The package ID is `com.john.bible`. Confirm this ID in Play Console
before the first upload. A published package ID cannot change.

The first Android release uses version `1.0.0` and version code `1`.
It requires Android 8.0 (API 26). It targets API 36.
The app is free. It has no ads or purchases.
Support email: `contact@north.boutique`.

## Signing inputs

Use the owner's existing upload key if Play Console already has one.
For a new app, use Play App Signing. Keep the upload key in private storage.
The upload key and the app signing key have different functions. Google Play
uses the app signing key to sign APKs that users install.

The release build reads these environment variables:

| Variable | Default or function |
| --- | --- |
| `ANDROID_RELEASE_APPLICATION_ID` | `com.john.bible` |
| `ANDROID_RELEASE_VERSION_CODE` | `1`; increase it for each new upload |
| `ANDROID_RELEASE_VERSION_NAME` | `1.0.0` |
| `ANDROID_UPLOAD_KEYSTORE` | Absolute path to the upload keystore |
| `ANDROID_UPLOAD_STORE_PASSWORD` | Keystore password |
| `ANDROID_UPLOAD_KEY_ALIAS` | Private key alias |
| `ANDROID_UPLOAD_KEY_PASSWORD` | Private key password |
| `ANDROID_RELEASE_PROPERTIES_FILE` | `~/.local/share/john-android/release.properties` |
| `BUNDLETOOL_JAR` | Path to the official bundletool JAR |

Environment variables override values in the private properties file.
The properties file uses these keys: `storeFile`, `storePassword`, `keyAlias`,
and `keyPassword`. Use Java properties syntax. Do not add this file to Git.
The properties file and keystore must be outside this repository.
On macOS and Linux, each file must have mode `600`.

If the owner needs a new upload key, run this command only after the package ID
and Play App Signing setup are confirmed:

```sh
python3 scripts/android/release/create-upload-key.py
```

The helper creates a 4096-bit RSA key in a PKCS12 keystore. The private alias is
`john-upload`. It saves the key as `~/.local/share/john-android/upload-key.jks`.
It saves the matching properties file in the same private folder. The directory
uses mode `700`. The files use mode `600`. The helper stops if either file exists.
Passwords do not appear in command arguments or logs.
The helper removes its temporary password file. Back up the keystore and private
configuration in the owner's secure storage before the first upload.
Do not create another key for routine app updates.

## Build the signed bundle

Use the tools listed in [README.md](README.md). Install the official
[bundletool JAR](https://github.com/google/bundletool/releases) in private tool
storage. Set `BUNDLETOOL_JAR` to its path. The default build script path is
`~/.local/share/john-android/tools/bundletool.jar`.

Run this command from the repository root:

```sh
python3 scripts/android/release/build-bundle.py
```

The script stops if signing inputs or bundletool are missing. It builds
`:app:bundleRelease`. It checks the bundle before it saves distribution output.
It disables Gradle configuration caching for this build.

The default output folder is `~/.local/share/john-android/releases`.
Use `--output-dir /absolute/private/path` to select another folder outside this
repository. The output contains a signed `.aab` file and a public JSON report.
These are release deliverables. Keep them for the Play upload. Remove the Gradle
build output after validation, as required by the root rules.

The script checks these conditions:

- Every content entry has a valid JAR signature from the selected upload key.
- The upload key is private, valid, and not the Android debug key.
- The ZIP has no corrupt or duplicate entries.
- The packaged devotional catalog matches the reviewed input in
  `native/Android/content/companion.json` exactly.
- bundletool accepts the bundle.
- The packaged application ID, version, and SDK levels match the release inputs.
- The app is neither debuggable nor marked `testOnly`.
- All packaged 64-bit native libraries have ELF LOAD alignment of at least 16 KB.
- If native libraries exist, the bundle requests 16 KB alignment for generated APKs.

The report includes the bundle SHA-256, size, package ID, version, SDK levels,
public certificate fingerprint, and devotional catalog SHA-256.
It contains no signing passwords.
`artifactVerified: true` means that these file checks passed. It does not mean
that device tests, policy forms, listing review, or Google review passed.

To check a bundle again before removing its Gradle metadata:

```sh
python3 scripts/android/release/verify-bundle.py \
  native/Android/app/build/outputs/bundle/release/app-release.aab \
  --metadata native/Android/app/build/reports/release/release-inputs.properties \
  --bundletool "$BUNDLETOOL_JAR"
```

## CI validation

CI keeps the debug build, JVM tests, lint, and shared content checks.
It also builds an unsigned release bundle and runs release lint.
CI explicitly sets `ANDROID_ALLOW_UNSIGNED_RELEASE=true` for this step.
CI verifies bundletool version 1.18.3 with a fixed SHA-256 before it runs bundle
and packaged manifest checks.
The unsigned report uses `artifactVerified: false`.
The unsigned bundle must never be uploaded to Play.
CI has no upload key. It does not publish the app.

## Before the Play upload

1. Confirm the final package ID and upload certificate in Play Console.
2. Complete the release device tests. Test widgets, audio, reminders after a
   reboot, offline content, permission denial, and app updates.
3. Complete the privacy policy, Data Safety, content rating, audience, and
   foreground service forms.
4. Add the listing text, support email, icon, feature graphic, and screenshots.
5. Upload the signed bundle to internal testing.
6. Review the Play pre-launch report and resolve blocking findings.
7. Complete the production access requirements shown for the owner's account.

Sources: [App signing](https://developer.android.com/studio/publish/app-signing),
[bundletool](https://developer.android.com/tools/bundletool), and
[16 KB page support](https://developer.android.com/guide/practices/page-sizes).
