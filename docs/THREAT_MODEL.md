# Threat model

Keychest is a convenience and hygiene tool. It is deliberately honest about what it does and does not protect.

## What Keychest protects against

| Threat | How it helps |
| --- | --- |
| Secrets committed to git | Real values never live in the repo; `.keychest.yml` holds names only; generated output is git-ignored. |
| Secrets read from the project folder by other tools (editors, scripts, AI assistants, backups, shared zips) | Values live in the Keychain/1Password, not in a `.env` file in the folder. |
| Secrets visible in shell history or process lists | `keychest set` prompts with echo off and never takes the value as an argument. |
| Casual extraction with `strings` on a built app | Values are XOR-obfuscated with a random per-run salt. |
| Release secrets present on developer laptops | `--environments` generates only the environments a machine needs. |

## What Keychest does **not** protect against

- **A determined attacker with your app.** The decoder and salt ship in the binary. Anyone with a debugger, Frida or a disassembler can recover the values. XOR is obfuscation, not encryption. This is true of every client-side secret scheme, including Arkana and cocoapods-keys.
- **A decompiled Android app.** The Kotlin decoder and salt ship in the app's dex files, and tools such as jadx can recover the values. Code shrinking and renaming with R8 do not change that.
- **Malware or a malicious process running as you.** Any process running as your user can ask the Keychain for items once it is unlocked (macOS may prompt, depending on the item's access control).
- **The generated folder.** It contains the encoded values and the salt side by side, so anyone who can read it can decode it. Treat it like a secret: git-ignored, not shared, and denied to AI tools.
- **Compromised CI.** Whoever controls the CI job can read the secrets it injects.
- **Revocation.** If a secret leaks, rotate it. Keychest cannot un-leak anything.

## Recommendations

1. Prefer short-lived or scoped keys over powerful long-lived ones.
2. Never embed anything that would be catastrophic if extracted (payment secrets, database credentials, signing keys). Put those behind your own server.
3. Rotate any secret that was ever committed or pasted into a tool.
4. Keep the generated folder out of version control and backups you don't control.
