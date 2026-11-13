#!/usr/bin/env bash
# End-to-end check: generate a package with the env backend, make sure no plaintext
# leaks into it, then compile it and confirm the decoded values round-trip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift build --package-path "$ROOT" >/dev/null
BIN="$(swift build --package-path "$ROOT" --show-bin-path)/keychest"

cd "$WORK"
cat > .keychest.yml <<'YAML'
backend: env
environments: [Debug, Release]
environment_secrets: [apiKey]
global_secrets: [clientID, MAPS_API_KEY]
YAML

export clientID='cid-ünï-$p€cial "q" \ ` x' apiKeyDebug=dbg-key-123 apiKeyRelease=rel-key-456 MAPS_API_KEY=maps-key-789

"$BIN" check
"$BIN" generate

if grep -rE "dbg-key-123|rel-key-456|maps-key-789|cid-" KeychestKeys; then
  echo "FAIL: plaintext secret found in generated code" >&2
  exit 1
fi

mkdir -p consumer/Sources/consumer
cat > consumer/Package.swift <<'SWIFT'
// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "consumer",
    dependencies: [.package(path: "../KeychestKeys")],
    targets: [.executableTarget(name: "consumer",
                                dependencies: [.product(name: "KeychestKeys", package: "KeychestKeys")])]
)
SWIFT
cat > consumer/Sources/consumer/main.swift <<'SWIFT'
import KeychestKeys
print(Secrets.Global().clientID)
print(Secrets.Debug().apiKey)
print(Secrets.Release().apiKey)
print(Secrets.Global().mapsApiKey)
SWIFT

ACTUAL="$(swift run --package-path consumer consumer)"
EXPECTED="$(printf '%s\n%s\n%s\n%s' "$clientID" "$apiKeyDebug" "$apiKeyRelease" "$MAPS_API_KEY")"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "FAIL: decoded values differ from originals" >&2
  exit 1
fi
echo "e2e OK"
