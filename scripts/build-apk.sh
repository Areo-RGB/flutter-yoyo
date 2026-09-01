#!/usr/bin/env bash
set -euo pipefail

VARIANT="${1:-debug}"

# Ensure script is run from project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Building Flutter APK ($VARIANT) ==="
flutter build apk --"$VARIANT"

APK_PATH="build/app/outputs/flutter-apk/app-${VARIANT}.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "Error: Expected APK not found at $APK_PATH" >&2
  exit 1
fi

printf "Built APK: %s\n" "$PROJECT_ROOT/$APK_PATH"
