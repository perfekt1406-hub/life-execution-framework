#!/usr/bin/env bash
# Clears prior build outputs before a new build.
# Usage: clean-releases.sh [--linux|--mac|--win|--all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REL="$ROOT/releases"
PLATFORM="${1:---all}"

mkdir -p "$REL"

declare -a patterns=()

case "$PLATFORM" in
  --linux)
    patterns=( "$REL"/*.AppImage "$REL"/*.deb "$REL"/*.snap "$REL"/*.rpm )
    ;;
  --mac)
    patterns=( "$REL"/*.dmg "$REL"/*.pkg )
    ;;
  --win)
    patterns=( "$REL"/*.exe "$REL"/*.msi "$REL"/*.zip )
    ;;
  --all)
    patterns=(
      "$REL"/*.AppImage "$REL"/*.deb "$REL"/*.snap "$REL"/*.rpm
      "$REL"/*.dmg "$REL"/*.pkg
      "$REL"/*.exe "$REL"/*.msi "$REL"/*.zip
    )
    ;;
  *)
    echo "clean-releases: unknown platform '$PLATFORM' — use --linux, --mac, --win, or --all"
    exit 1
    ;;
esac

shopt -s nullglob
for f in "${patterns[@]}"; do
  [[ -e "$f" ]] || continue
  rm -f -- "$f"
done
shopt -u nullglob

echo "clean-releases: cleared $PLATFORM artifacts in $REL"

# Wipe dist/ so stale artifacts from a previous platform build don't bleed into the next
rm -rf "$ROOT/dist"
echo "clean-releases: wiped dist/"
