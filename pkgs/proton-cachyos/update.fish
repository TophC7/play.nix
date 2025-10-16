#!/usr/bin/env fish

# Update script for proton-cachyos versions.json
# Checks for new releases and updates the version file

set -l versionsFile versions.json

# Check if we're in the right directory
if not test -f $versionsFile
    echo "Error: Could not find $versionsFile"
    echo "Please run this script from the pkgs/proton-cachyos directory"
    exit 1
end

# Read current version
set -l currentBase (jq -r .base < $versionsFile)
set -l currentRelease (jq -r .release < $versionsFile)

echo "Current version: $currentBase-$currentRelease"
echo "Checking for updates..."

# Fetch latest release from CachyOS repository
set -l latestTag (curl -s 'https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest' | jq -r '.tag_name')

if test -z "$latestTag" -o "$latestTag" = null
    echo "Error: Could not fetch latest release tag"
    exit 1
end

echo "Latest tag: $latestTag"

# Parse the tag format: cachyos-X.Y-Z-slr
# Remove prefix and suffix, then split
set -l tagParts (string replace 'cachyos-' '' $latestTag | string replace -- '-slr' '' | string split '-')

if test (count $tagParts) -ne 2
    echo "Error: Unexpected tag format: $latestTag"
    echo "Expected format: cachyos-X.Y-Z-slr"
    exit 1
end

set -l latestBase $tagParts[1]
set -l latestRelease $tagParts[2]

# Check if we're already up to date
if test "$currentBase" = "$latestBase" -a "$currentRelease" = "$latestRelease"
    echo "✓ Already up to date!"
    exit 0
end

echo "New version available: $latestBase-$latestRelease"

# Construct the download URL
set -l fileName "proton-cachyos-$latestBase-$latestRelease-slr-x86_64_v3.tar.xz"
set -l downloadUrl "https://github.com/CachyOS/proton-cachyos/releases/download/$latestTag/$fileName"

echo "Computing hash for: $fileName"

# Fetch the hash (this will download the file to verify)
set -l sha256 (nix-prefetch-url --type sha256 "$downloadUrl" 2>/dev/null)

if test -z "$sha256"
    echo "Error: Failed to download or hash the release"
    echo "URL: $downloadUrl"
    exit 1
end

# Convert to SRI hash format
set -l sriHash (nix-hash --to-sri --type sha256 $sha256)

echo "New hash: $sriHash"

# Create the new JSON content
set -l newJson (jq -n \
    --arg base "$latestBase" \
    --arg release "$latestRelease" \
    --arg hash "$sriHash" \
    '{base: $base, release: $release, hash: $hash}')

# Write the new JSON to the file
echo $newJson | jq '.' >$versionsFile

if test $status -ne 0
    echo "Error: Failed to update $versionsFile"
    exit 1
end

echo "✓ Updated $versionsFile"
echo ""
echo "Summary:"
echo "  Version: $currentBase-$currentRelease → $latestBase-$latestRelease"
echo "  Hash: $sriHash"
echo ""
echo "Remember to commit the changes:"
echo "  git add $versionsFile"
echo "  git commit -m \"proton-cachyos: $currentBase.$currentRelease → $latestBase.$latestRelease\""
