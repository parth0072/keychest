# keychest-sample

A minimal SwiftUI app showing how to use [Keychest](../../README.md) to keep API keys out of a repository. The real values live in your macOS Keychain. This folder only contains their *names*.

## Run it

You need Xcode 16 or newer and Keychest:

```bash
brew install parth0072/tap/keychest
```

Clone Keychest and move into this folder:

```bash
cd Examples/keychest-sample
```

Typing is hidden, so press Return after each value. Use fake values: the app prints one on screen.

```bash
keychest set apiKey
```

`apiKey` is asked twice, for Debug and then Release.

```bash
keychest set clientID
```

```bash
keychest generate
```

Open `keychest-sample.xcodeproj`, choose a simulator and run. The screen shows the Debug `apiKey` you stored.

## How it fits together

- `.keychest.yml` lists the secret names and environments. No values, so it is safe to commit.
- `KeychestKeys/` is created by `keychest generate`. It is git-ignored on purpose and added to the Xcode project as a local Swift package. Until you have run `generate`, Xcode reports a missing package.
- `ContentView.swift` does `import KeychestKeys` and reads `Secrets.Debug().apiKey`. Try `Secrets.Release().apiKey` or `Secrets.Global().clientID` too.

## Notes

- Values are stored in your login Keychain under the service `com.example.myapp`. Remove them with `keychest remove apiKey` and `keychest remove clientID`.
- No development team is set. The simulator works without one; pick yours under *Signing & Capabilities* to run on a device.
- Anything shipped inside an app can be extracted, so don't put truly sensitive credentials in one. See the [threat model](../../docs/THREAT_MODEL.md).

Part of Keychest, released under the [MIT License](../../LICENSE).
