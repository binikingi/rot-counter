#!/bin/bash
# curl -fsSL https://raw.githubusercontent.com/binikingi/rot-counter/main/install.sh | bash
set -euo pipefail
URL=https://github.com/binikingi/rot-counter/releases/latest/download/RotCounter.zip
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP/RotCounter.zip"
ditto -x -k "$TMP/RotCounter.zip" "$TMP"
pkill -x RotCounter || true
rm -rf /Applications/RotCounter.app
mv "$TMP/RotCounter.app" /Applications/
pkill -f RotWidget.appex || true  # stale widget process from the old version; macOS relaunches it on demand
open /Applications/RotCounter.app
echo "Installed. Add apps from the hourglass in your menu bar, then add the widget (right-click desktop → Edit Widgets)."
