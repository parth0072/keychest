# Keychest

**Keep app secrets out of your repo and out of your project folder.**
Keychest pulls secrets from the macOS Keychain (or 1Password, or CI environment variables) at build time and generates a small, obfuscated Swift package your app imports.

```swift
import KeychestKeys

let client = APIClient(key: Secrets.Release().apiKey)
```

- **No `.env` file in the project.** Real values live in the Keychain, not next to your code, so they can't be committed by accident or read by tools that can read your folder (editors, scripts, AI coding assistants).
- **Safe to commit config.** `.keychest.yml` lists key *names* only.
- **Pluggable backends.** Keychain, environment variables (for CI) and 1Password today; adding one is a ~30-line type.
- **Per-environment secrets.** `Debug` and `Release` can have different values; generate only the environments a machine needs.
- **Zero runtime dependencies.** The generated package is plain Swift with no imports beyond Foundation.
- **Testable.** Generated protocols make it easy to inject fake secrets in unit tests.

> **Read this first:** anything shipped inside an app can be extracted by a determined attacker. Keychest's obfuscation only stops secrets from showing up in `strings`. Its main value is keeping secrets out of your *source tree and repository*. See [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md).

## How it works

```
 build time (your Mac or CI)                              runtime (your app)
┌──────────────────────────────┐   ┌─────────────────┐   ┌──────────────────────────┐
│ Keychain / 1Password / env   │──▶│ keychest generate│──▶│ KeychestKeys (Swift pkg) │
│ (real values, never in repo) │   │ XOR + random salt│   │ decodes values on access │
└──────────────────────────────┘   └─────────────────┘   └──────────────────────────┘
        .keychest.yml (names only, committed) ──────────▲
```

## Requirements

- macOS 12+ and Swift 5.9+ (Xcode 15+) to build and use Keychain storage
- The `op` CLI, signed in, only if you use the 1Password backend
- The core (config, obfuscation, code generation, env backend) also builds on Linux

## Install

From source:

```bash
git clone https://github.com/parth0072/keychest.git
cd keychest
swift build -c release
cp .build/release/keychest /usr/local/bin/
```

With [Mint](https://github.com/yonaskolb/Mint):

```bash
mint install parth0072/keychest
```

## Quick start

```bash
cd MyApp
keychest init                       # creates .keychest.yml
# edit .keychest.yml: service name, environments, secret names

keychest set apiKey                 # prompts (hidden) once per environment
keychest set analyticsToken         # global secret: prompts once
keychest check                      # verify everything is present (never prints values)
keychest generate                   # writes ./KeychestKeys
```

Then add `KeychestKeys` to your project as a **local Swift package** (Xcode: *File → Add Package Dependencies… → Add Local…*), and use it:

```swift
import KeychestKeys

Secrets.Global().analyticsToken
Secrets.Debug().apiKey
Secrets.Release().apiKey
```

Generated code is git-ignored automatically (a `.gitignore` is written into the output folder).

### Step-by-step walkthrough

1. **Install** the `keychest` binary (see [Install](#install)) and check it with `keychest --help`.
2. **Create the config** in your app's root folder: `keychest init`. Edit `.keychest.yml` and list your secret *names* (never values). The file is safe to commit.
3. **Store values.** With the `keychain` backend run `keychest set <name>` for each secret; you are prompted with echo off. With the `env` backend, export variables named like the keys (`apiKeyDebug`, `apiKeyRelease`, `clientID`).
4. **Check.** `keychest check` lists what is present or missing and never prints values.
5. **Generate.** `keychest generate` writes the `KeychestKeys` Swift package (obfuscated, no plaintext, git-ignored).
6. **Add to Xcode.** *File → Add Package Dependencies… → Add Local…*, pick the `KeychestKeys` folder, and link it to your app target.
7. **Use it.** `import KeychestKeys`, then `Secrets.Debug().apiKey`.
8. **Re-run `keychest generate`** whenever a secret changes. On CI, use the `env` backend (see [Continuous integration](#continuous-integration)).

### Using the protocols for DI and tests

```swift
func makeClient(secrets: SecretsEnvironmentProtocol) -> APIClient {
    APIClient(key: secrets.apiKey)
}

#if DEBUG
let client = makeClient(secrets: Secrets.Debug())
#else
let client = makeClient(secrets: Secrets.Release())
#endif

// In tests:
struct FakeSecrets: SecretsEnvironmentProtocol { let apiKey = "test-key" }
```

## Commands

| Command | What it does |
| --- | --- |
| `keychest init [--force]` | Create a starter `.keychest.yml`. |
| `keychest set <name> [-e Env] [--stdin]` | Store a secret. The value is prompted for with echo off, never passed as an argument (so it stays out of shell history and `ps`). Environment secrets prompt once per environment unless `-e` is given. |
| `keychest remove <name> [-e Env]` | Delete a secret from the backend. |
| `keychest check [--environments A,B]` | List which secrets are present or missing. Exits `1` if any are missing. Never prints values. |
| `keychest generate [--environments A,B] [--output DIR]` | Fetch secrets and write the Swift package. Reports *all* missing secrets at once. |

All commands accept `-c/--config <path>` (default `.keychest.yml`).

## Configuration

```yaml
backend: keychain              # keychain | env | 1password
service: com.example.myapp     # Keychain service name (keychain backend)

# onepassword:                 # 1password backend
#   vault: Development
#   item: MyApp

environments: [Debug, Release]
environment_secrets: [apiKey]       # stored as apiKeyDebug, apiKeyRelease
global_secrets: [analyticsToken]    # stored as analyticsToken

output:
  path: KeychestKeys           # where the package is written
  package_name: KeychestKeys   # what you `import`
  type_name: Secrets           # top-level namespace
  gitignore: true              # write a .gitignore into the output folder
```

Rules: key and environment names are ASCII letters, digits and underscores, starting with a letter. `Global` is reserved. A name can't be declared twice. `MySecretKey` becomes the property `mySecretKey`; Swift keywords are escaped automatically. More examples are in [`Examples/`](Examples).

## Backends

| Backend | Read | Write (`set`/`remove`) | Notes |
| --- | :-: | :-: | --- |
| `keychain` | ✅ | ✅ | macOS login keychain, generic-password items under your `service`. macOS may ask permission the first time. |
| `env` | ✅ | ❌ | Reads `$<account>`, e.g. `$apiKeyRelease`. Intended for CI secrets. |
| `1password` | ✅ | ❌ | Shells out to `op read op://<vault>/<item>/<account>`. Manage values in 1Password. |

Writing your own backend means conforming to [`SecretBackend`](Sources/KeychestCore/SecretBackend.swift) and adding a case in `BackendFactory`. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Continuous integration

Use the same key names, with values from your CI's secret store:

```yaml
# .github/workflows/release.yml (excerpt)
- run: keychest generate --config ci.keychest.yml --environments Release
  env:
    apiKeyRelease: ${{ secrets.API_KEY_RELEASE }}
    analyticsToken: ${{ secrets.ANALYTICS_TOKEN }}
```

`--environments` lets you keep Release secrets off developer machines and Debug values out of CI.

## Xcode

Run `keychest generate` **before** building: from a terminal, fastlane, or a pre-build step.
If you use an Xcode *Run Script* build phase, note that **User Script Sandboxing** (on by default in new projects) can block Keychain access; either turn it off for that phase or run Keychest outside Xcode.

## Using Keychest with AI coding assistants

Because real values are never in the project folder, assistants that can read your repo (Claude Code, Cursor, Copilot, …) can't read them from files. Two things to still do:

- The generated folder contains encoded values *and* the salt, which is trivially reversible. Keep it git-ignored (Keychest does this by default) and add it to your assistant's deny list.
- An assistant that can run shell commands could run `security find-generic-password -w …` or `keychest generate`. Restrict those commands too.

Details and copy-paste Claude Code settings: [docs/AI_ASSISTANTS.md](docs/AI_ASSISTANTS.md).

## Security model

Keychest protects against secrets being **committed, shared by accident, or read from your source tree**, and makes them **non-obvious in the shipped binary**. It does **not** make secrets unrecoverable from a shipped app. For truly sensitive credentials, keep them on a server and have your app call it. Full discussion: [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Keychest vs. Arkana

[Arkana](https://github.com/rogerluan/arkana) is a great Ruby tool that inspired this project and shares its account-naming convention (`apiKey` + `Debug` → `apiKeyDebug`). Differences:

| | Arkana | Keychest |
| --- | --- | --- |
| Secret source | `.env` file or env vars | Keychain, 1Password, or env vars |
| Implementation | Ruby gem | Single Swift binary (no Ruby/Bundler) |
| Platforms generated | Swift and Kotlin | Swift only (for now) |
| White-label flavors | ✅ | ❌ (not yet) |
| CocoaPods output | ✅ | ❌ (SwiftPM local package only) |

If you need Android/Kotlin output, flavors or CocoaPods, use Arkana. Keychest can also complement it, since Arkana reads plain env vars.

## Roadmap

- White-label flavors
- Kotlin output
- Touch ID–gated Keychain items
- More backends (Bitwarden, HashiCorp Vault, AWS Secrets Manager)
- Homebrew formula and signed release binaries

Ideas and PRs welcome.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run the tests with `swift test` and the end-to-end check with `Scripts/e2e.sh`.

## License

[MIT](LICENSE)
