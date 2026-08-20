#!/usr/bin/env bash
# setup-nextcloud-folders.sh
#
# Creates the sibling PARA folder structure at $HOME. Does NOT configure
# Nextcloud sync connections themselves — those must be set up through the
# Nextcloud desktop client GUI (one sync connection per folder, each mapping
# a remote folder to a local path).
#
# This script just creates the local placeholder folders so you can point
# Nextcloud at them, and prints the pairing instructions.
#
# Usage: ./setup-nextcloud-folders.sh

set -euo pipefail

FOLDERS=(
    "00-Inbox"
    "10-Projects"
    "15-Code"
    "20-Teaching"
    "30-Research"
    "40-Admin"
    "60-Media"
    "70-Vault"
    "80-Reference"
    "90-Archive"
)

echo "→ Creating sibling folder structure at $HOME"
for folder in "${FOLDERS[@]}"; do
    if [ -e "$HOME/$folder" ]; then
        echo "  · $folder (exists, skipping)"
    else
        mkdir -p "$HOME/$folder"
        echo "  + $folder"
    fi
done

echo ""
echo "✓ Folder structure created."
echo ""
echo "Next steps (manual, via Nextcloud desktop client):"
echo ""
echo "  1. Open Nextcloud desktop client → Settings → Add Folder Sync Connection"
echo "  2. For each folder below, create a sync connection mapping the"
echo "     remote folder to the local path:"
echo ""
for folder in "${FOLDERS[@]}"; do
    case "$folder" in
        15-Code|60-Media)
            echo "     $folder → (not synced via Nextcloud)"
            ;;
        *)
            echo "     Remote: $folder    →    Local: $HOME/$folder"
            ;;
    esac
done
echo ""
echo "  3. Do this once per machine that should sync these folders."
echo "     Different machines can sync different subsets."
echo ""
echo "Notes:"
echo "  - $HOME/15-Code is for Git working trees, not synced by Nextcloud."
echo "  - $HOME/60-Media is for consumption media, managed by media apps."
echo "  - $HOME/70-Vault holds the Cryptomator vault; the encrypted vault files"
echo "    are what Nextcloud syncs. Open the vault with Cryptomator, not Files."
