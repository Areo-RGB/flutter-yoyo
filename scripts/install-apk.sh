#!/usr/bin/env bash
set -euo pipefail

# Script directory and project root setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

VARIANT="${1:-debug}"
SKIP_BUILD="${SKIP_BUILD:-false}"
PACKAGE="${PACKAGE:-com.aistudio.yoyoir1.track}"

# 1. Build APK Flow
if [ "$SKIP_BUILD" != "true" ]; then
  echo "=== Step 1/2: Building $VARIANT APK ==="
  "$SCRIPT_DIR/build-apk.sh" "$VARIANT"
else
  echo "=== Step 1/2: Skipping Build (SKIP_BUILD=true) ==="
fi

APK_PATH="build/app/outputs/flutter-apk/app-${VARIANT}.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "Error: APK not found at $APK_PATH" >&2
  exit 1
fi

# 2. Install & Launch Flow
echo "=== Step 2/2: Installation Flow ==="

PERMS=""
if command -v aapt2 &>/dev/null; then
  PERMS="$(aapt2 dump permissions "$APK_PATH" 2>/dev/null | sed -n 's/.*name='\''\([^'\'']*\)'\''.*/\1/p' || true)"
elif command -v aapt &>/dev/null; then
  PERMS="$(aapt dump permissions "$APK_PATH" 2>/dev/null | sed -n "s/.*name='\([^']*\)'.*/\1/p" || true)"
fi

DEVICES="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
if [ -z "$DEVICES" ]; then
  echo "Error: No Android devices/emulators detected by adb." >&2
  exit 1
fi

for DEVICE in $DEVICES; do
  echo "--- Installing on device $DEVICE ---"

  echo "Stopping $PACKAGE on $DEVICE ..."
  adb -s "$DEVICE" shell am force-stop "$PACKAGE" 2>/dev/null && echo "  Stopped" || echo "  Not running"

  echo "Installing $APK_PATH ..."
  if ! adb -s "$DEVICE" install -r "$APK_PATH"; then
    echo "  Install failed on $DEVICE, continuing to next device..." >&2
    continue
  fi

  if [ -n "$PERMS" ]; then
    echo "Granting permissions for $PACKAGE on $DEVICE ..."
    while IFS= read -r PERM; do
      [ -z "$PERM" ] && continue
      adb -s "$DEVICE" shell pm grant "$PACKAGE" "$PERM" 2>/dev/null && echo "  Granted $PERM" || true
    done <<< "$PERMS"
  fi

  echo "Launching $PACKAGE on $DEVICE ..."
  if adb -s "$DEVICE" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 &>/dev/null; then
    echo "  Successfully launched on $DEVICE"
  else
    echo "  Launch failed on $DEVICE" >&2
  fi
done

echo "=== Install flow complete ==="
