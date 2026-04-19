#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="$ROOT_DIR/extensions"

echo "Publishing dashability_extensions..."

# Copy LICENSE.
cp "$ROOT_DIR/LICENSE" "$PKG_DIR/LICENSE"
cp "$ROOT_DIR/.gitignore" "$PKG_DIR/.gitignore"
cp -r "$ROOT_DIR/example" "$PKG_DIR/example"

cleanup() {
  echo "Cleaning up copied files..."
  rm -f "$PKG_DIR/LICENSE"
  rm -f "$PKG_DIR/.gitignore"
  rm -rf "$PKG_DIR/example"
}
trap cleanup EXIT

# Dry run first.
cd "$PKG_DIR"
dart pub publish --dry-run

echo ""
read -p "Publish dashability_extensions to pub.dev? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

dart pub publish --force
echo "Published dashability_extensions."
