# Changelog

All notable changes are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-11-04

### Added
- `Examples/keychest-sample`: a SwiftUI sample app that uses Keychest.
- Homebrew install: `brew install parth0072/tap/keychest`.

### Changed
- `BackendKind` now conforms to `Decodable` only (it was `Codable, CaseIterable`).
- Shorter README with a quick start, and a License section.

### Removed
- Unused public API in `KeychestCore`: `Obfuscator.decode(_:salt:)` and `Obfuscator.randomSalt(using:)`.

## [0.1.0] - 2026-11-03

### Added
- Initial release: `init`, `set`, `remove`, `generate`, `check` commands.
- Backends: macOS Keychain, environment variables (CI), 1Password CLI (read-only).
- Generated dependency-free Swift package with per-environment and global secrets,
  protocols for dependency injection, and per-run random salt.
- `--environments` filter to keep other environments' secrets off a machine.
