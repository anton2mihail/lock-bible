# Read-only release package check

Run this script after Main builds the app and embeds the widget. The widget path is normally inside `App.app/PlugIns/`. The script reads the app, widget, Info.plists, compiled asset catalog, and accepted resource manifest. It writes `report.json` only to a new evidence directory.

```sh
python3 scripts/native/release/verify-release-package.py \
  --app /path/to/John.app \
  --widget /path/to/John.app/PlugIns/JohnWidget.appex \
  --manifest /path/to/staged/Resources/resource-manifest.json \
  --evidence-dir /path/to/new/package-check-evidence
```

The script checks bundle IDs, versions, build numbers, minimum OS, URL schemes, the `AppGroupIdentifier` Info.plist value, and signed App Group entitlements when the platform can display them. It reports the app and widget separately. It maps each staged resource path to its app or widget target. It checks packaged privacy manifests, fonts listed by `UIAppFonts`, and license or attribution files by both file name and SHA-256. It checks the compiled `Assets.car` for the three icon renditions and the launch asset names. It checks for the compiled launch storyboard and controller nib.

The script runs `codesign -d` only to read entitlements. It does not sign, archive, launch, or change the app. Entitlements do not prove that an App Group container works. The compiled asset catalog check does not prove source PNG byte identity or pixel identity. Use the staged resource manifest for source file hashes. Main owns archive and runtime acceptance.

The report lists bundle IDs, versions, deployment floors, URL schemes, App Group values, and signed groups as observed facts. It does not compare them with the required production configuration. A passed result covers resource checks only. It does not prove archive or signing readiness. Main must compare these observed facts with the release requirements.
