#!/usr/bin/env bash
# Copies only installer artifacts from dist/ into releases/, leaving metadata behind.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC="$ROOT/dist"
DEST="$ROOT/releases"

mkdir -p "$DEST"

shopt -s nullglob
copied=0
for f in \
  "$SRC"/*.AppImage \
  "$SRC"/*.deb \
  "$SRC"/*.dmg \
  "$SRC"/*.pkg \
  "$SRC"/*.exe \
  "$SRC"/*.msi \
  "$SRC"/*.snap \
  "$SRC"/*.rpm \
  "$SRC"/*.zip; do
  [[ -e "$f" ]] || continue
  cp -- "$f" "$DEST/"
  echo "publish-releases: copied $(basename "$f") → releases/"
  (( copied++ )) || true
done
shopt -u nullglob

if (( copied == 0 )); then
  echo "publish-releases: no installer files found in $SRC"
fi
