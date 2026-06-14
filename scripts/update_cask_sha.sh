#!/usr/bin/env bash
# scripts/update_cask_sha.sh
#
# Look up the SHA256 of the latest macOS DMG from the GitHub Releases API
# and patch the Homebrew cask formula in
# `packaging/homebrew/Casks/task-manager.rb`. No DMG download needed —
# the API exposes each asset's digest directly.
#
# Usage (from repo root):
#   ./scripts/update_cask_sha.sh [version]
#
# If `version` is omitted, the script reads the latest tag from origin.
#
# Requirements: curl, python3 (for JSON parsing), sed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASK_FILE="$REPO_ROOT/packaging/homebrew/Casks/task-manager.rb"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 origin/master | sed 's/^v//')"
fi
if [[ -z "$VERSION" ]]; then
  echo "Could not determine version. Pass it as \$1 or run from a repo with origin tags." >&2
  exit 1
fi

ASSET_NAME="TaskManager_v${VERSION}_macos.dmg"

echo "Fetching digest for $ASSET_NAME from GitHub Releases API…"
DIGEST="$(curl -fsSL \
  "https://api.github.com/repos/craftor/task-manager/releases/tags/v${VERSION}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data.get('assets', []):
    if a['name'] == '$ASSET_NAME':
        # digest format: 'sha256:<hex>'
        print(a['digest'].split(':', 1)[1])
        break
else:
    sys.exit('asset $ASSET_NAME not found in release v$VERSION')
")"

echo "  sha256: $DIGEST"

if [[ ! -f "$CASK_FILE" ]]; then
  echo "Cask file not found at $CASK_FILE" >&2
  exit 1
fi

# Patch the sha256 + version lines. macOS sed needs -i '' (no backup suffix),
# GNU sed takes -i alone.
if sed --version >/dev/null 2>&1; then
  sed -i "s/^  sha256 \".*\"/  sha256 \"$DIGEST\"/" "$CASK_FILE"
  sed -i "s/^  version \".*\"/  version \"$VERSION\"/" "$CASK_FILE"
else
  sed -i '' "s/^  sha256 \".*\"/  sha256 \"$DIGEST\"/" "$CASK_FILE"
  sed -i '' "s/^  version \".*\"/  version \"$VERSION\"/" "$CASK_FILE"
fi

echo "Updated $CASK_FILE"
echo
echo "Next steps:"
echo "  1. Copy $CASK_FILE to your Homebrew tap repo at Casks/task-manager.rb"
echo "  2. Commit & push the tap repo (e.g. craftor/homebrew-task-manager)"
echo "  3. Users can run: brew update && brew install --cask task-manager"