#!/usr/bin/env bash
# Injects AppStream metainfo into the .deb produced by electron-builder.
# electron-builder has no built-in way to add files to arbitrary system paths
# inside a .deb, so we extract → patch → repack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
DIST="$ROOT/dist"
METAINFO_SRC="$SCRIPT_DIR/../metainfo/com.life-framework.app.metainfo.xml"

DEB="$(ls "$DIST"/*.deb | head -1)"
if [[ -z "$DEB" ]]; then
  echo "patch-deb: no .deb found in $DIST — skipping"
  exit 0
fi

echo "patch-deb: patching $DEB"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

dpkg-deb -x "$DEB" "$TMPDIR/pkg"
dpkg-deb --control "$DEB" "$TMPDIR/pkg/DEBIAN"

mkdir -p "$TMPDIR/pkg/usr/share/metainfo"
cp "$METAINFO_SRC" "$TMPDIR/pkg/usr/share/metainfo/com.life-framework.app.metainfo.xml"

dpkg-deb --build "$TMPDIR/pkg" "$DEB"
echo "patch-deb: done → $DEB"
