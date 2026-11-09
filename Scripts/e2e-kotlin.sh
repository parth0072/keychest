#!/usr/bin/env bash
# End-to-end check for Kotlin output: generate a Gradle module with the env backend, make sure no
# plaintext leaks into it, then build and run a tiny consumer with Gradle and confirm the decoded
# values round-trip. Needs a JDK (11+) and Gradle on PATH, plus network access for the Kotlin
# Gradle plugin. Override the Kotlin version with KEYCHEST_E2E_KOTLIN_VERSION.
set -euo pipefail

KOTLIN_VERSION="${KEYCHEST_E2E_KOTLIN_VERSION:-2.4.21}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v gradle >/dev/null || { echo "gradle not found on PATH" >&2; exit 1; }

swift build --package-path "$ROOT" >/dev/null
BIN="$(swift build --package-path "$ROOT" --show-bin-path)/keychest"

cd "$WORK"
cat > .keychest.yml <<'YAML'
backend: env
platforms: [kotlin]
environments: [Debug, Release]
environment_secrets: [apiKey]
global_secrets: [clientID]
kotlin:
  path: keychest-keys
  package: com.example.keys
YAML

export clientID='cid-ünï-$p€cial "q" \ ` x 🔑' apiKeyDebug=dbg-key-123 apiKeyRelease=rel-key-456

"$BIN" check
"$BIN" generate

if grep -rE "dbg-key-123|rel-key-456|cid-" keychest-keys; then
  echo "FAIL: plaintext secret found in generated code" >&2
  exit 1
fi

# A Gradle build shaped like an Android project: repositories are declared once in settings and
# module scripts may not declare their own, which the generated module must respect.
cat > settings.gradle.kts <<'KTS'
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { mavenCentral() }
}
rootProject.name = "keychest-e2e"
include(":keychest-keys", ":consumer")
KTS

cat > build.gradle.kts <<KTS
plugins {
    kotlin("jvm") version "$KOTLIN_VERSION" apply false
}
KTS

mkdir -p consumer/src/main/kotlin
cat > consumer/build.gradle.kts <<'KTS'
plugins {
    kotlin("jvm")
    application
}

dependencies {
    implementation(project(":keychest-keys"))
}

application {
    mainClass.set("MainKt")
}
KTS

cat > consumer/src/main/kotlin/Main.kt <<'KT'
import com.example.keys.Secrets
import java.util.Base64

// Print as Base64 so the check does not depend on the terminal's character encoding.
private fun show(value: String) = println(Base64.getEncoder().encodeToString(value.toByteArray(Charsets.UTF_8)))

fun main() {
    show(Secrets.Global.clientID)
    show(Secrets.Debug.apiKey)
    show(Secrets.Release.apiKey)
}
KT

ACTUAL="$(gradle --no-daemon --console=plain -q :consumer:run)"
b64() { printf '%s' "$1" | base64 | tr -d '\n'; }
EXPECTED="$(printf '%s\n%s\n%s' "$(b64 "$clientID")" "$(b64 "$apiKeyDebug")" "$(b64 "$apiKeyRelease")")"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "FAIL: decoded values differ from originals" >&2
  echo "expected: $EXPECTED" >&2
  echo "actual:   $ACTUAL" >&2
  exit 1
fi
echo "e2e kotlin OK"
