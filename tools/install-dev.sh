#!/usr/bin/env bash
# Copy the addon (only the files WoW needs) into a Forever AddOns folder for testing.
#   tools/install-dev.sh                       # default TUF/Omarchy Battle.net path
#   tools/install-dev.sh "/path/to/_forever_/Interface/AddOns"
# v0.1 was only ever installed into a temp folder (BRIEF: never the live AddOns path
# without Tim's OK).
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
addons="${1:-$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns}"
[ -d "$addons" ] || { echo "AddOns folder not found: $addons" >&2; exit 1; }
dest="$addons/TheTerminalList"
mkdir -p "$dest"
rsync -a --delete \
  --include='*.toc' --include='Core/***' --include='Modules/***' --include='UI/***' --include='Media/***' \
  --include='LICENSE' --exclude='*' \
  "$repo/" "$dest/"
echo "Installed to: $dest"
echo "In game: /reload, then /tlist"
