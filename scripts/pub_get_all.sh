#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Resolving dependencies for core..."
cd "$ROOT_DIR/core" && dart pub get

echo ""
echo "Resolving dependencies for extensions..."
cd "$ROOT_DIR/extensions" && dart pub get

echo ""
echo "Done."
