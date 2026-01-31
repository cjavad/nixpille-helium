#!/usr/bin/env bash
set -euo pipefail

# Fetches the latest Helium release, verifies GPG signatures,
# and updates sources.json.
#
# Requirements: gh, nix, gpg, curl, jq

REPO="imputnet/helium-linux"
SOURCES="$(cd "$(dirname "$0")" && pwd)/sources.json"
GPG_KEY="BE677C1989D35EAB2C5F26C9351601AD01D6378E"

echo "Checking latest release..."
latest=$(gh api "repos/$REPO/releases/latest" --jq '.tag_name')
current=$(jq -r .version "$SOURCES")

if [[ "$latest" == "$current" ]]; then
  echo "Already up to date: $current"
  exit 0
fi

echo "Updating $current -> $latest"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Import Helium signing key if needed
if ! gpg --list-keys "$GPG_KEY" &>/dev/null; then
  echo "Importing Helium signing key..."
  gpg --keyserver keyserver.ubuntu.com --recv-keys "$GPG_KEY"
fi

download_and_verify() {
  local arch="$1"
  local base="helium-${latest}-${arch}_linux.tar.xz"
  local url="https://github.com/$REPO/releases/download/$latest/$base"

  echo "Downloading $base..."
  curl -sL "$url" -o "$tmpdir/$base"
  curl -sL "$url.asc" -o "$tmpdir/$base.asc"

  echo "Verifying GPG signature for $arch..."
  if ! gpg --verify "$tmpdir/$base.asc" "$tmpdir/$base" 2>&1; then
    echo "ERROR: GPG verification failed for $base" >&2
    exit 1
  fi

  nix hash file --sri "$tmpdir/$base"
}

x86_hash=$(download_and_verify "x86_64")
arm_hash=$(download_and_verify "arm64")

echo ""
echo "x86_64-linux:  $x86_hash"
echo "aarch64-linux: $arm_hash"

# Write sources.json
jq -n \
  --arg version "$latest" \
  --arg x86 "$x86_hash" \
  --arg arm "$arm_hash" \
  '{
    version: $version,
    hashes: {
      "x86_64-linux": $x86,
      "aarch64-linux": $arm
    }
  }' > "$SOURCES"

echo ""
echo "Updated sources.json: $current -> $latest"
echo "Run 'nix build .#helium' to verify the build."
