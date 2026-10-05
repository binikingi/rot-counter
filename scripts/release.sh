#!/bin/bash
# Usage: scripts/release.sh 0.1.0
# One-time setup: a "Developer ID Application" cert in your keychain, and
#   xcrun notarytool store-credentials rotcounter --apple-id <you> --team-id <team>
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$1
APP=build/export/RotCounter.app
ZIP=build/RotCounter.zip

rm -rf build/export build/RotCounter.xcarchive "$ZIP"
xcodegen -q
xcodebuild -project RotCounter.xcodeproj -scheme RotCounter -configuration Release \
  -archivePath build/RotCounter.xcarchive MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$VERSION" archive
xcodebuild -exportArchive -archivePath build/RotCounter.xcarchive -exportPath build/export \
  -exportOptionsPlist scripts/ExportOptions.plist

ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile rotcounter --wait
xcrun stapler staple "$APP"
rm "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"  # re-zip so the stapled ticket ships

gh release create "v$VERSION" "$ZIP" --title "v$VERSION" --generate-notes
echo "Released v$VERSION."
