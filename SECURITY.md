# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.
Use GitHub's private vulnerability reporting ("Security" tab → "Report a vulnerability") on this repository.
Include steps to reproduce and the affected version. You can expect an initial response within a few days.

## Scope and limitations

Keychest obfuscates secrets in generated code; it does not encrypt them. That limitation is documented in
[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) and is not considered a vulnerability. Bugs that leak values
(for example printing them, writing them to unexpected places, or passing them on a command line) are in scope.
