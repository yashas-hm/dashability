#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="$ROOT_DIR/core"

echo "Publishing dashability..."

# Copy files needed for pub.dev scoring.
cp "$ROOT_DIR/LICENSE" "$PKG_DIR/LICENSE"
cp "$ROOT_DIR/README.md" "$PKG_DIR/README.md"
cp "$ROOT_DIR/.gitignore" "$PKG_DIR/.gitignore"
cp -r "$ROOT_DIR/example" "$PKG_DIR/example"

cleanup() {
  echo "Cleaning up copied files..."
  rm -f "$PKG_DIR/LICENSE"
  rm -f "$PKG_DIR/README.md"
  rm -f "$PKG_DIR/.gitignore"
  rm -rf "$PKG_DIR/example"
}
trap cleanup EXIT

# Dry run first.
cd "$PKG_DIR"
dart pub publish --dry-run

echo ""
read -p "Publish dashability to pub.dev? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

dart pub publish --force
echo "Published dashability."
