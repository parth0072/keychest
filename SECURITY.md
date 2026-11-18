# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.
Use GitHub's private vulnerability reporting ("Security" tab → "Report a vulnerability") on this repository.
Include steps to reproduce and the affected version. You can expect an initial response within a few days.

## Supported versions

Only the latest release gets security fixes. Please upgrade before you report.

## Scope and limitations

Keychest obfuscates secrets in generated code; it does not encrypt them. That limitation is documented in
[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) and is not considered a vulnerability.

These **are** in scope:

- Anything that leaks a secret value: printing or logging it, passing it on a command line, writing it somewhere unexpected, or giving other users access to it.
- Generated code that contains a plaintext value.
- Weaknesses in how Keychest is built, released or installed (tampered archives, unpinned or compromised build steps).

Running Keychest on a `.keychest.yml` you don't trust is not safe, and is documented as such in [docs/PRODUCTION.md](docs/PRODUCTION.md).

## Verifying a download

Homebrew checks the SHA-256 of the release archive. For a manual download, compare it with the `.sha256` file on the same release. Releases after 1.2.0 also carry signed build provenance:

```bash
gh attestation verify keychest-<version>-macos-universal.tar.gz -R parth0072/keychest
```
