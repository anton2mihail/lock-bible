# Pre-TestFlight steps for the user, 6 October 2026

## Update, 7 October 2026

This update supersedes the signing status in the 6 October steps below. Xcode created a signed John Release archive and exported a local App Store Connect IPA with team `QZ44N522NQ`. Xcode used Cloud Managed Apple Distribution and created matching Store profiles for the app and widget. The export has `get-task-allow=false` and the expected App Group. The archive was signed with Apple Development. The old unsigned simulator app below is still not a TestFlight artifact.

The current IPA is `build/native-evidence/L28/signed-oct7-02/export/John 1:1.ipa`, SHA-256 `0b47de9cba0bb3d871cc826f32ab485664c884e99d6e69349304844d3295d3cc`. The Release archive and package checks passed. Runtime validation remains in progress, so keep this IPA provisional. A read-only App Store Connect check on 7 October showed build `18` and no build `19`. Recheck before upload. Xcode generated a blank Privacy Report twice. The embedded app and widget privacy declarations passed C11 and C12, but the Xcode report remains unverified. Agents did not upload the IPA. See `docs/native/reviews/oct7-signed-archive-export-evidence.md` for hashes and reports.

The numbered steps below record the 6 October process. Steps 1 through 6 are superseded by the signed archive and export completed on 7 October. Do not use the old archive paths or treat the old signing statements as current. Steps 7 through 9 remain pending. Agents must not upload.

These steps are for the user. Agents must not upload.

1. The archive is not signed for TestFlight until an Apple Distribution identity is present. The unsigned Release simulator app built at 15:05 (executable SHA-256 `14240aa6d2882d5aeeec85b2014aceb32ad32a6a481e8d33ec2d4a7ddd25bc85`) does not include the later Reader scroll-reset fix. Archive from the source tree that contains that fix. Do not upload the 15:05 simulator app.
2. This Mac has no Apple Distribution identity. Developer ID and Apple Development are not TestFlight signing.
3. Version 1.5.0 and build 19 are already in `native/John/App/Info.plist`. A read-only check on 7 October found build 19 unused. Recheck before upload.
4. The live Expo app is version 1.5.0, build 18. The minimum OS is iOS 26.0.
5. Archive with the command from section 6 of `docs/native/reviews/L28-gate-e-checklist.md`. Leave `CODE_SIGNING_ALLOWED` on. The command does not set `CODE_SIGNING_ALLOWED=NO`. The command sets `DEVELOPMENT_TEAM=QZ44N522NQ` and `-allowProvisioningUpdates`.

```sh
xcodebuild archive -project native/John/John.xcodeproj -scheme 'John Update' -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/native-evidence/L28/signed-01/John.xcarchive \
  -derivedDataPath build/native-evidence/L28/signed-01/DerivedData -allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ
```

6. Export the archive with `build/native-evidence/L28/export-options-01/ExportOptions.plist`. Do not upload. The plist sets `destination` to `export`. Do not set `destination` to `upload`.

```sh
xcodebuild -exportArchive -archivePath build/native-evidence/L28/signed-01/John.xcarchive \
  -exportOptionsPlist build/native-evidence/L28/export-options-01/ExportOptions.plist \
  -exportPath build/native-evidence/L28/signed-01/export -allowProvisioningUpdates
```

7. Then upload the IPA in Organizer or Transporter.
8. Then install that build on a phone over the live app. Check VoiceOver, the widgets, a notice tap, share, and the saved data.
9. Agents must not upload.
