# Keychest

**Keep API keys out of your git repo, for iOS and Android apps.**

You store each secret once, in your Mac's Keychain. Keychest turns them into a small Swift package (iOS) or Kotlin module (Android) that your app imports. Your repo only contains the key *names*, never the values.

```swift
let key = Secrets.Release().apiKey   // iOS
```

```kotlin
val key = Secrets.Release.apiKey     // Android
```

> **Early release.** You may hit bugs. If something breaks, please [open an issue](https://github.com/parth0072/keychest/issues/new/choose) with the command you ran and the error (never paste real secret values).

> **Know the limits.** Anything inside an app can be extracted by a determined attacker. Keychest keeps secrets out of your repo, not out of your app. See the [threat model](docs/THREAT_MODEL.md).

## Install

```bash
brew install parth0072/tap/keychest
```

It downloads a prebuilt binary for macOS 12 or newer, so you don't need Xcode. You can also [download it](https://github.com/parth0072/keychest/releases/latest) (if macOS blocks a browser download, run `xattr -d com.apple.quarantine keychest` once) or build from source with Swift 5.9+.

## 1. Set up (iOS and Android)

In your app's folder:

```bash
keychest init
```

This creates `.keychest.yml`. Edit it to list your secret names. Names only, so it is safe to commit:

```yaml
service: com.yourcompany.yourapp   # any unique name
environments: [Debug, Release]
environment_secrets: [apiKey]      # a different value per environment
global_secrets: [clientID]         # the same value everywhere
```

Then store the values. Typing is hidden:

```bash
keychest set apiKey      # asks for the Debug value, then the Release value
keychest set clientID
```

## 2a. iOS

```bash
keychest generate
```

This creates a `KeychestKeys/` folder. In Xcode, choose **File → Add Package Dependencies… → Add Local…** and pick it. Then:

```swift
import KeychestKeys

let key = Secrets.Debug().apiKey      // different per environment
let id = Secrets.Global().clientID    // same everywhere
```

Try the [iOS sample app](Examples/keychest-sample).

## 2b. Android

Add this to `.keychest.yml`, with your own package name:

```yaml
platforms: [kotlin]
kotlin:
  package: com.yourcompany.yourapp.keys
```

```bash
keychest generate
```

This creates a `keychest-keys/` module. Add it to your Gradle build:

```kotlin
// settings.gradle.kts
include(":keychest-keys")

// build.gradle.kts (root), inside plugins { }
id("org.jetbrains.kotlin.jvm") version "2.4.21" apply false   // or your Kotlin version

// app/build.gradle.kts
android { buildFeatures { buildConfig = true } }
dependencies { implementation(project(":keychest-keys")) }
```

Then:

```kotlin
import com.yourcompany.yourapp.keys.Secrets

val key = if (BuildConfig.DEBUG) Secrets.Debug.apiKey else Secrets.Release.apiKey
val id = Secrets.Global.clientID
```

Try the [Android sample app](Examples/keychest-sample-android). Building both apps from one repo? Use `platforms: [swift, kotlin]`.

## Good to know

- **Run `keychest generate` again** when a secret changes. The generated folders are git-ignored, so after cloning, each developer runs `keychest set` and `keychest generate` once.
- **Tests:** use the generated `SecretsEnvironmentProtocol` (Swift) or `SecretsEnvironment` (Kotlin) in your code, so a test can pass in a fake.
- **Xcode:** run `keychest generate` before building, not in a Run Script phase, because its sandbox can block the Keychain.
- **CI** has no Keychain: use the `env` backend, as shown in the [reference](docs/REFERENCE.md#ci).
- **More:** all commands, config options and backends are in the [reference](docs/REFERENCE.md). The generated folders hold the encoded values next to their salt, so keep them out of reach of AI assistants ([guide](docs/AI_ASSISTANTS.md)). To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Roadmap

**Done:** Swift and Kotlin output, Keychain, 1Password and env backends, a prebuilt macOS binary with Homebrew install, and iOS and Android sample apps.

**Next** (no dates yet; ideas and PRs are welcome):

- **Android Gradle plugin:** run `keychest generate` before builds, and feed secrets to `BuildConfig` and manifest placeholders (for keys such as a Maps API key)
- **Build flavors:** white-label apps, and Android build types and flavors mapped to Keychest environments
- **CI-friendly names:** variables like `API_KEY_DEBUG` for per-environment secrets (today they are `API_KEYDebug`)
- **Touch ID–protected** Keychain items
- **More backends:** Bitwarden, Vault, AWS
- **Prebuilt Linux binaries**

## Contributing

Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Keychest is released under the [MIT License](LICENSE). Copyright (c) 2026 Parth Kshatriya.
