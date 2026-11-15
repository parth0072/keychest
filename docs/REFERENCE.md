# Keychest reference

The [README](../README.md) shows the quick path. This page has the details.

## Commands

| Command | What it does |
| --- | --- |
| `keychest init` | Create `.keychest.yml`. |
| `keychest set <name> [-e Env]` | Store a secret. Hidden prompt, or `--stdin` for scripts. The value is never a command-line argument. |
| `keychest remove <name> [-e Env]` | Delete a secret. |
| `keychest check` | Show which secrets exist. Never prints values. Exits `1` if any are missing. |
| `keychest generate` | Write the Swift package and/or Kotlin module. `--platforms swift,kotlin` picks one or both. |

Every command takes `-c <path>` to use another config file. `check` and `generate` take `--environments Release` to read only some environments.

## Config options

```yaml
backend: keychain          # keychain | env | 1password
platforms: [swift]         # swift, kotlin or both

output:                    # the Swift package (all optional)
  path: KeychestKeys
  package_name: KeychestKeys

kotlin:                    # the Kotlin module (all optional)
  path: keychest-keys
  package: com.yourcompany.yourapp.keys
```

Names use letters, digits and underscores and start with a letter. `MySecretKey` becomes the property `mySecretKey`, and `MAPS_API_KEY` becomes `mapsApiKey`. More examples are in [`Examples/`](../Examples).

## Backends

| Backend | Read | Write | Notes |
| --- | :-: | :-: | --- |
| `keychain` | ✅ | ✅ | macOS login keychain. macOS may ask for permission the first time: choose Always Allow. |
| `env` | ✅ | – | Reads environment variables. Meant for CI, and works on Linux. |
| `1password` | ✅ | – | Reads from 1Password with the `op` CLI. Needs an `onepassword:` section with `vault` and `item`. |

To add a backend, see [CONTRIBUTING.md](../CONTRIBUTING.md).

## CI

CI machines have no Keychain, so use the `env` backend. Keep a copy of your config with `backend: env` (say `ci.keychest.yml`) and give the CI your secrets under the same names. `apiKeyRelease` is the Release value of `apiKey`:

```yaml
- run: keychest generate --config ci.keychest.yml --environments Release
  env:
    apiKeyRelease: ${{ secrets.API_KEY_RELEASE }}
    clientID: ${{ secrets.CLIENT_ID }}
```

`--environments Release` keeps the other environments' secrets off that machine.
