#!/usr/bin/env bash
# End-to-end check for the Android sample: generate the Kotlin module with fake values from the env
# backend, build the debug and release APKs with Gradle, and make sure no plaintext secret ended up
# in either APK. Needs a JDK (17+), the Android SDK (ANDROID_HOME) and network access for Gradle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLE="$ROOT/Examples/keychest-sample-android"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ -z "${ANDROID_HOME:-}" ]; then
  for candidate in "$HOME/Library/Android/sdk" /opt/homebrew/share/android-commandlinetools; do
    if [ -d "$candidate/platforms" ]; then ANDROID_HOME="$candidate"; break; fi
  done
fi
[ -d "${ANDROID_HOME:-}" ] || { echo "Android SDK not found: set ANDROID_HOME" >&2; exit 1; }
export ANDROID_HOME

swift build --package-path "$ROOT" >/dev/null
BIN="$(swift build --package-path "$ROOT" --show-bin-path)/keychest"

# Work on a copy so the repository stays clean, and leave out local IDE files such as the
# daemon JVM pin Android Studio generates, so every machine builds the same way.
rsync -a --exclude keychest-keys --exclude build --exclude .gradle --exclude .idea \
  --exclude local.properties --exclude gradle-daemon-jvm.properties "$SAMPLE/" "$WORK/"
cd "$WORK"

# The sample's own config with the env backend, so no Keychain is involved and the two cannot drift apart.
sed -e 's/^backend:.*/backend: env/' .keychest.yml > ci.keychest.yml
export clientID=ci-client-id apiKeyDebug=ci-debug-key-111 apiKeyRelease=ci-release-key-222
"$BIN" generate -c ci.keychest.yml

./gradlew --no-daemon --console=plain -q :app:assembleDebug :app:assembleRelease

for variant in debug release; do
  apk="app/build/outputs/apk/$variant/app-$variant.apk"
  [ -f "$apk" ] || { echo "FAIL: $apk was not built" >&2; exit 1; }
  unpacked="$WORK/unpacked-$variant"
  mkdir -p "$unpacked"
  unzip -q "$apk" -d "$unpacked"
  if grep -rlaF -e ci-client-id -e ci-debug-key-111 -e ci-release-key-222 "$unpacked"; then
    echo "FAIL: plaintext secret found in the $variant APK" >&2
    exit 1
  fi
done
echo "e2e android OK"
