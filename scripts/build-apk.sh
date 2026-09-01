#!/usr/bin/env bash
set -euo pipefail

APP_ID="${APP_ID:-com.aistudio.yoyoir1.track}" # informational; keep in sync with app/build.gradle.kts (applicationId on line 17)
VARIANT="${1:-debug}"
GRADLE_TASK="assemble${VARIANT^}"
ANDROID_SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"

if [ ! -f "./gradlew" ]; then
  echo "Error: gradlew not found in the current directory. Run this from the repository root that contains the Gradle wrapper." >&2
  exit 1
fi

if [ ! -x "./gradlew" ]; then
  chmod +x "./gradlew"
fi

if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  echo "Error: ANDROID_HOME or ANDROID_SDK_ROOT must be set to the local Android SDK path (e.g., \$HOME/Android/Sdk)." >&2
  exit 1
fi

./gradlew "$GRADLE_TASK" \
  -Pandroid.injected.build.api=21 \
  -Pandroid.injected.build.density=480 \
  -Pandroid.injected.build.abi=arm64-v8a

APK_PATH="app/build/outputs/apk/${VARIANT}/app-${VARIANT}.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "Error: Expected APK not found at $APK_PATH" >&2
  exit 1
fi

printf "Built APK: %s\n" "$(pwd)/$APK_PATH"
