# R1 release: TestFlight upload

Result: pass. Upload succeeded ("Upload succeeded", "EXPORT SUCCEEDED").

- Branch: codex/swiftui-ios26-rebuild
- Scheme and configuration: John Update, Release
- Bundle IDs: com.nrsv.verse (app), com.nrsv.verse.widget (widget). Same as the old Expo app (app.json).
- App group: group.com.nrsv.verse
- Team: QZ44N522NQ (Apple ID anton.mihail@yahoo.com in Xcode)
- Version: 2.0.0, build 20 (old JS app: 1.5.0 build 18). Set in the three Info.plist files.
- Signing: automatic, -allowProvisioningUpdates. Upload through the Xcode Apple ID login. No API key was needed.
- Simulator: not used.
- Script: scripts/native/release-testflight.sh [version] [build]
- Output: build/native-release/2.0.0-20/

Open item: App Store Connect still processes the build. Check TestFlight for the processing result.
Note: AuthKey_W7J22FU3LN.p8 is an APNs key, not an App Store Connect key. Do not use it for upload.
