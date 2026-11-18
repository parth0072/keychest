# Using Keychest in production

Keychest keeps secrets out of your repository and your project folder. It does **not** make a secret safe once it is inside a shipped app: anyone with your app can recover it. Read this page before you use Keychest on a live app.

## 1. Decide what belongs in an app

Put in an app only what you could live with being public.

- **Fine:** analytics and crash-reporting tokens, map keys, client IDs, and API keys that the provider lets you restrict to your app (bundle ID or package name plus signing certificate), limit to certain APIs, and rate-limit.
- **Never:** payment secrets, database or cloud admin credentials, signing keys, or any long-lived token that can act as a user or an admin. Keep those behind your own server, and have the app call that server.

Restrict every key at the provider, set quotas, and plan how you will rotate it. Assume it will be extracted.

## 2. Keep environments apart

By default `keychest generate` puts the secrets of **every** environment into the generated code. A Debug build then carries your Release key, and a Release build carries the Debug one. Generate only what each build needs:

- On developer machines, store only Debug values and run `keychest generate --environments Debug`.
- Keep Release values in your CI's secret store, and run `keychest generate --environments Release` on the release pipeline.
- In Swift, choose the environment with `#if DEBUG` so each build only refers to what exists. On Android, generating per build type is on the [roadmap](../README.md#roadmap). Until then the generated module holds every environment you generate.

## 3. Protect the generated folders

`KeychestKeys/` and `keychest-keys/` hold the encoded values next to their salt, which is as good as plain text for anyone who can read them.

- Keychest writes them owner-only (folders 0700, files 0600) and excludes them from backups on macOS. They are git-ignored by default.
- Never `git add -f` them. Don't upload them as CI artifacts or cache them, and delete them after the build.
- Keep projects out of cloud-synced folders such as iCloud Drive's Desktop and Documents, or generate only on CI. Keychest can't stop a sync service from copying them.
- Keep them out of reach of AI assistants: see the [assistant guide](AI_ASSISTANTS.md).

## 4. Trust the config you run

`.keychest.yml` decides which Keychain service or 1Password item Keychest reads, and where it writes. Treat it like a build script: only run Keychest on repositories you trust.

## 5. CI

- Use the `env` backend with your CI's secret store ([how](REFERENCE.md#ci)). Give the job read-only repository permissions and only the secrets it needs.
- Don't expose secrets to workflows triggered by pull requests from forks.
- Never print the environment, and don't cache or archive the generated folders.

## 6. Install Keychest safely

- Homebrew (`brew install parth0072/tap/keychest`) checks the SHA-256 of the archive it downloads.
- For a manual download, check the archive against the `.sha256` file from the same release. Releases after 1.2.0 also carry signed build provenance, which you can check with `gh attestation verify keychest-<version>-macos-universal.tar.gz -R parth0072/keychest`.
- In CI, download one specific version and verify its checksum, rather than installing whatever is latest.

## 7. When something leaks

If a generated folder, an app build, a log or a screenshot ever showed a value, rotate that secret. Obfuscation can't be undone. To see what a build exposes, try a test value: `strings YourApp | grep <test value>` should print nothing. That only shows the value isn't stored as readable text. It is still recoverable by someone who analyses the app.

## Checklist

- [ ] Every key in the app is restricted at the provider, and you could rotate it today
- [ ] Nothing in the app could do real damage if it were extracted
- [ ] Release builds are generated on CI only, with `--environments Release`
- [ ] Generated folders are git-ignored, not cached, not uploaded and not synced
- [ ] Keychest and its CI actions are pinned and verified
