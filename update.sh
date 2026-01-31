#!/usr/bin/env bash
set -euo pipefail

# Fetches the latest Helium release, verifies GPG signatures,
# and updates version + hashes in package.nix.
#
# Requirements: gh, nix, gpg, curl

REPO="imputnet/helium-linux"
PKG_FILE="$(cd "$(dirname "$0")" && pwd)/package.nix"
GPG_KEY="BE677C1989D35EAB2C5F26C9351601AD01D6378E"

echo "Checking latest release..."
latest=$(gh api "repos/$REPO/releases/latest" --jq '.tag_name')
current=$(grep 'version = ' "$PKG_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')

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

verify_arch() {
  local arch="$1" nix_system="$2"
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

  echo "Prefetching $arch hash..."
  hash=$(nix hash file --sri "$tmpdir/$base")
  echo "$nix_system = \"$hash\""
  eval "${nix_system//-/_}_hash='$hash'"
}

verify_arch "x86_64" "x86_64-linux"
x86_hash="$x86_64_linux_hash"

verify_arch "arm64" "aarch64-linux"
arm_hash="$aarch64_linux_hash"

echo ""
echo "x86_64-linux:  $x86_hash"
echo "aarch64-linux: $arm_hash"

# Update package.nix
sed -i "s|version = \"$current\"|version = \"$latest\"|" "$PKG_FILE"
sed -i "s|x86_64-linux = \"sha256-[^\"]*\"|x86_64-linux = \"$x86_hash\"|" "$PKG_FILE"
sed -i "s|aarch64-linux = \"sha256-[^\"]*\"|aarch64-linux = \"$arm_hash\"|" "$PKG_FILE"

echo ""
echo "Updated package.nix: $current -> $latest"
echo "Run 'nix build .#helium' to verify the build."
