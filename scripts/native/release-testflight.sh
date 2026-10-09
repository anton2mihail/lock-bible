#!/bin/bash
# Archive the John Update scheme, sign it, and upload it to TestFlight.
# Uses the Apple ID signed in to Xcode (team QZ44N522NQ). No simulator.
# Usage: scripts/native/release-testflight.sh [version] [build]
set -euo pipefail
cd "$(dirname "$0")/../.."
VERSION="${1:-2.0.0}"
BUILD="${2:-20}"
TEAM=QZ44N522NQ
OUT="build/native-release/$VERSION-$BUILD"
for p in native/John/App/Info.plist native/John/Widget/Info.plist native/John/SharedResources/Info.plist; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$p"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$p"
done
mkdir -p "$OUT"
cat > "$OUT/ExportOptions.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>teamID</key><string>$TEAM</string>
<key>signingStyle</key><string>automatic</string>
<key>uploadSymbols</key><true/>
</dict></plist>
PL
xcodebuild archive -project native/John/John.xcodeproj -scheme "John Update" \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath "$OUT/John.xcarchive" DEVELOPMENT_TEAM=$TEAM \
  -allowProvisioningUpdates | tail -25
xcodebuild -exportArchive -archivePath "$OUT/John.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT/export" \
  -allowProvisioningUpdates | tail -25
