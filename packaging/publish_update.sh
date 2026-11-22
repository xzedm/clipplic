#!/bin/bash
# Signs a release DMG with the Sparkle key in your login Keychain and adds it to appcast.xml.
#
# Usage: packaging/publish_update.sh build/Clipplic-1.4.dmg v1.4 [release-notes.md]
#
# Then upload the DMG to the GitHub release with the same tag, and commit + push appcast.xml to main.
# Installed copies check https://raw.githubusercontent.com/xzedm/clipplic/main/appcast.xml once a day.
set -euo pipefail

DMG="${1:?Path to the release DMG}"
TAG="${2:?Release tag, for example v1.4}"
NOTES="${3:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Sparkle's tools come with the Swift package; Xcode keeps them in DerivedData.
# Set SPARKLE_BIN to the folder holding generate_appcast to pick a specific copy.
if [[ -n "${SPARKLE_BIN:-}" ]]; then
  TOOL="$SPARKLE_BIN/generate_appcast"
else
  TOOL="$(find "$ROOT/build" "$HOME/Library/Developer/Xcode/DerivedData" -path '*artifacts/sparkle/Sparkle/bin/generate_appcast' -type f 2>/dev/null | head -1)"
fi
if [[ -z "$TOOL" ]]; then
  echo "generate_appcast not found. Open clipplic.xcodeproj in Xcode once so it downloads the Sparkle package." >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp "$DMG" "$STAGE/"
if [[ -n "$NOTES" ]]; then
  # generate_appcast shows notes whose file name matches the DMG
  cp "$NOTES" "$STAGE/$(basename "${DMG%.dmg}").md"
fi
# Keep earlier entries: generate_appcast reads the existing appcast and adds the new version.
[[ -f "$ROOT/appcast.xml" ]] && cp "$ROOT/appcast.xml" "$STAGE/appcast.xml"

"$TOOL" "$STAGE" \
  --download-url-prefix "https://github.com/xzedm/clipplic/releases/download/$TAG/" \
  --embed-release-notes \
  -o "$STAGE/appcast.xml"

cp "$STAGE/appcast.xml" "$ROOT/appcast.xml"
echo "Updated appcast.xml for $TAG. Upload $(basename "$DMG") to the $TAG GitHub release, then push appcast.xml to main."
