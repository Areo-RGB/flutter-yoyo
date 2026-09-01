#!/usr/bin/env bash
set -euo pipefail

VARIANT="${1:-debug}"
APK_PATH="${2:-app/build/outputs/apk/${VARIANT}/app-${VARIANT}.apk}"
PACKAGE="${PACKAGE:-com.aistudio.yoyoir1.track}"
LAUNCH_ACTIVITY="${LAUNCH_ACTIVITY:-$PACKAGE/com.example.MainActivity}"

if [ ! -f "$APK_PATH" ]; then
  echo "Error: APK not found at $APK_PATH" >&2
  exit 1
fi

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
  echo "=== Installing on $DEVICE ==="

  echo "Stopping $PACKAGE on $DEVICE ..."
  adb -s "$DEVICE" shell am force-stop "$PACKAGE" 2>/dev/null && echo "  stopped" || echo "  skip stop (not running or failed)"

  if ! adb -s "$DEVICE" install -r "$APK_PATH"; then
    echo "Install failed on $DEVICE, continuing..." >&2
    continue
  fi

  if [ -n "$PERMS" ]; then
    echo "Granting permissions for $PACKAGE on $DEVICE ..."
    while IFS= read -r PERM; do
      [ -z "$PERM" ] && continue
      adb -s "$DEVICE" shell pm grant "$PACKAGE" "$PERM" 2>/dev/null && echo "  granted $PERM" || echo "  skip $PERM (not grantable or already granted)"
    done <<< "$PERMS"
  else
    echo "No permissions extracted (no aapt), skipping grants."
  fi

  echo "Launching $LAUNCH_ACTIVITY on $DEVICE ..."
  adb -s "$DEVICE" shell am start -n "$LAUNCH_ACTIVITY" 2>/dev/null && echo "  launched" || echo "  launch failed on $DEVICE" >&2
done

echo "Done."
