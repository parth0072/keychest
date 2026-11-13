# Contributing

Thanks for helping! Bug reports, docs fixes, new backends and features are all welcome.

## Setup

```bash
git clone https://github.com/parth0072/keychest.git
cd keychest
swift build
swift test
Scripts/e2e.sh        # generate -> compile -> verify round trip
Scripts/e2e-kotlin.sh # Kotlin: generate -> Gradle build -> verify (needs a JDK and Gradle)
```

The Keychain backend only compiles and runs on macOS. Everything else (config, obfuscation, code generation, env backend) is covered by tests that also run on Linux. To exercise the real keychain locally:

```bash
KEYCHEST_KEYCHAIN_TESTS=1 swift test --filter KeychainBackendIntegrationTests
```

## Project layout

```
Sources/KeychestCore/   library: config, backends, obfuscation, code generation
Sources/keychest/       command-line interface (swift-argument-parser)
Tests/KeychestCoreTests unit tests, in-memory backend for fakes
Scripts/e2e.sh          end-to-end check used by CI
Scripts/e2e-kotlin.sh   end-to-end check for the Kotlin output, used by CI
Scripts/package-release.sh builds the universal release binary, used by the Release workflow
docs/                   threat model, assistant guidance
Examples/               sample configs and an Xcode sample app
```

## Adding a backend

1. Create `Sources/KeychestCore/Backends/MyBackend.swift` conforming to `SecretBackend`:
   `read` returns `nil` for "not found" (throw only for real failures); read-only backends should throw `KeychestError.unsupportedOperation` from `write` and `delete`.
2. Add a case to `BackendKind` (and any config it needs in `Config`, plus validation in `Config.validate()`).
3. Return it from `BackendFactory.make(for:)`.
4. Add tests and an `Examples/` config, and document it in the README backend table.

## Guidelines

- Never log, print, or pass secret values on a command line. Tests must use fake values.
- Keep generated code dependency-free and deterministic for a given salt.
- Add a test for every bug fix; update `CHANGELOG.md` under *Unreleased*.
- Keep PRs focused; open an issue first for large changes.

## Releasing

1. Bump `version` in `Sources/keychest/Keychest.swift`, move the *Unreleased* entries in `CHANGELOG.md` under the new version, commit, and wait for CI to pass on `main`.
2. Tag and push (`git tag -a vX.Y.Z -m "Keychest X.Y.Z" && git push origin vX.Y.Z`), then publish the release (`gh release create vX.Y.Z --notes-file ...`).
3. Publishing runs the **Release** workflow. It builds the universal macOS binary with `Scripts/package-release.sh` and attaches `keychest-X.Y.Z-macos-universal.tar.gz` and its `.sha256` to the release. To build it for an existing tag, run that workflow by hand and give it the tag. `Scripts/package-release.sh X.Y.Z` shows locally what a release contains.
4. Update the formula in [`parth0072/homebrew-tap`](https://github.com/parth0072/homebrew-tap): set `url` and `sha256` (from the release's `.sha256` file) for the new version, then run `brew audit --strict` and `brew test` on it.

The binary is ad-hoc signed, not notarized. Homebrew downloads are not quarantined by macOS, so they run as they are.
