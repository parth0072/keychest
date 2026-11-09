# Keychest

**Keep app secrets out of your repo and your project folder.**

Keychest pulls API keys from the macOS Keychain (or 1Password, or CI environment variables) at build time and generates a small Swift package (or a Kotlin module for Android) your app imports. Real values never touch git, and there is no `.env` file for editors, scripts or AI assistants to find.

```swift
import KeychestKeys

let client = APIClient(key: Secrets.Release().apiKey)
```

> **Work in progress.** Keychest is still young, so you may hit bugs or things that don't work yet. If something breaks, please [open an issue](https://github.com/parth0072/keychest/issues/new/choose) with the command you ran and the error output (never paste real secret values) and we'll take a look.

> **Know the limits.** Anything shipped inside an app can be extracted by a determined attacker. Keychest obfuscates values so they don't show up in `strings`, but its real value is keeping secrets out of your source tree and git history. See the [threat model](docs/THREAT_MODEL.md).

## Quick start

Install with [Homebrew](https://brew.sh) (builds from source, so Xcode 15+ is required):

```bash
brew install parth0072/tap/keychest
```

or build from source (macOS 12+, Swift 5.9+):

```bash
git clone https://github.com/parth0072/keychest.git && cd keychest
swift build -c release && cp .build/release/keychest /usr/local/bin/
```

Then, in your app's folder:

```bash
keychest init             # writes .keychest.yml (key names only, safe to commit)
keychest set apiKey       # hidden prompt, once per environment
keychest check            # confirms every secret exists; never prints values
keychest generate         # writes ./KeychestKeys (git-ignored)
```

Add `KeychestKeys` to Xcode as a local package (*File → Add Package Dependencies… → Add Local…*), then:

```swift
Secrets.Debug().apiKey            // per-environment secret
Secrets.Global().analyticsToken   // shared by every environment
```

A complete SwiftUI app is in [`Examples/keychest-sample`](Examples/keychest-sample).

Re-run `keychest generate` whenever a secret changes. For tests, depend on the generated protocol instead of the concrete type:

```swift
func makeClient(_ secrets: SecretsEnvironmentProtocol) -> APIClient { APIClient(key: secrets.apiKey) }
struct FakeSecrets: SecretsEnvironmentProtocol { let apiKey = "test-key" }
```

## Android

The same `.keychest.yml` can also generate a Kotlin module for Android (or any JVM) projects. Choose the platform and, optionally, where the module goes:

```yaml
platforms: [swift, kotlin]   # or just [kotlin]
kotlin:
  path: keychest-keys
  package: com.example.keys
```

Run `keychest generate`, then add the module to your Gradle build:

```kotlin
// settings.gradle.kts
include(":keychest-keys")

// app/build.gradle.kts
dependencies { implementation(project(":keychest-keys")) }
```

The module applies the Kotlin plugin without a version, so declare it once in your root `build.gradle.kts`: `id("org.jetbrains.kotlin.jvm") version "<your Kotlin version>" apply false`. Then use it like the Swift one:

```kotlin
import com.example.keys.Secrets
import com.example.keys.SecretsEnvironment

val secrets: SecretsEnvironment = if (BuildConfig.DEBUG) Secrets.Debug else Secrets.Release
val apiKey = secrets.apiKey
val clientID = Secrets.Global.clientID
```

`BuildConfig` needs `buildFeatures { buildConfig = true }` on recent Android Gradle plugins. Values are obfuscated, not encrypted: tools such as jadx can recover them from an APK.

## How it works

```
Keychain / 1Password / env  ──▶  keychest generate  ──▶  KeychestKeys (Swift package)
real values, never in git        XOR + random salt        decoded on access in your app
```

`.keychest.yml` lists secret *names* only. Each run uses a fresh random salt, and the generated code has no dependencies.

## Configuration

```yaml
backend: keychain                 # keychain | env | 1password
service: com.example.myapp        # Keychain service name

# onepassword:                    # for backend: 1password
#   vault: Development
#   item: MyApp

environments: [Debug, Release]
environment_secrets: [apiKey]     # stored as apiKeyDebug, apiKeyRelease
global_secrets: [analyticsToken]  # stored as analyticsToken

output:                           # optional
  path: KeychestKeys
  package_name: KeychestKeys      # what you `import`
  type_name: Secrets
  gitignore: true

platforms: [swift]                # swift, kotlin or both
kotlin:                           # used when platforms includes kotlin
  path: keychest-keys
  package: com.example.keys
```

Names use ASCII letters, digits and underscores and start with a letter; `Global` is reserved. More in [`Examples/`](Examples).

## Commands

| Command | What it does |
| --- | --- |
| `keychest init` | Create a starter `.keychest.yml` (`--force` to overwrite). |
| `keychest set <name> [-e Env]` | Store a secret via a hidden prompt, or `--stdin` for scripts. The value is never a command-line argument. |
| `keychest remove <name> [-e Env]` | Delete a secret from the backend. |
| `keychest check` | List present and missing secrets. Exits `1` if any are missing. |
| `keychest generate [--platforms swift,kotlin] [--output DIR]` | Fetch secrets and write the Swift package and/or Kotlin module. Reports every missing secret at once. |

`check` and `generate` take `--environments Debug,Release` to limit which environments are read, which keeps Release secrets off developer machines. Every command takes `-c/--config <path>`.

## Backends

| Backend | Read | Write | Notes |
| --- | :-: | :-: | --- |
| `keychain` | ✅ | ✅ | macOS login keychain. macOS may ask for permission the first time. |
| `env` | ✅ | – | Reads variables such as `$apiKeyRelease`. Meant for CI; also works on Linux. |
| `1password` | ✅ | – | Reads `op://<vault>/<item>/<account>` with the signed-in `op` CLI. |

To add one, conform to [`SecretBackend`](Sources/KeychestCore/SecretBackend.swift); see [CONTRIBUTING.md](CONTRIBUTING.md).

## CI and Xcode

On CI, use the `env` backend with the same key names:

```yaml
- run: keychest generate --config ci.keychest.yml --environments Release
  env:
    apiKeyRelease: ${{ secrets.API_KEY_RELEASE }}
    analyticsToken: ${{ secrets.ANALYTICS_TOKEN }}
```

In Xcode, run `keychest generate` before building (terminal, fastlane or a pre-build step). Inside a Run Script phase, User Script Sandboxing can block Keychain access.

## Security

Keychest protects against secrets being committed, shared by accident or read from your source tree. It does not make them unrecoverable from a shipped app, so keep truly sensitive credentials on a server. The generated folder holds the encoded values next to their salt: keep it git-ignored (the default) and out of reach of AI assistants, as described in [docs/AI_ASSISTANTS.md](docs/AI_ASSISTANTS.md). Report vulnerabilities privately; see [SECURITY.md](SECURITY.md).

## Roadmap

Planned, with no dates yet. Ideas and PRs are welcome.

- **More Android support** (Kotlin output is already here)
  - A sample Android app
  - Map Android build types and product flavors to Keychest environments, so one `.keychest.yml` can serve iOS and Android
  - A Gradle task that runs `keychest generate` before builds
- White-label flavors
- Touch ID–gated Keychain items
- More backends (Bitwarden, Vault, AWS)
- Prebuilt binaries so Xcode isn't needed to install

## Contributing

Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Keychest is released under the [MIT License](LICENSE). Copyright (c) 2026 Parth Kshatriya.
