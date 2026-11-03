# Using Keychest with AI coding assistants

Goal: let an assistant work on your app without being able to read your real secrets.

## What Keychest already gives you

- No `.env` or other plaintext secret file in the project, so file-reading tools have nothing to find.
- `.keychest.yml` contains only names.

## What you should still lock down

1. **The generated folder** (`KeychestKeys/` by default). Values are encoded, but the salt is next to them, so decoding is trivial.
2. **Shell access to the secret stores.** An assistant that can run commands can run `security find-generic-password -w`, `op read`, or `keychest generate`.

## Claude Code example

`.claude/settings.json` (project) or `~/.claude/settings.json` (all projects):

```json
{
  "permissions": {
    "deny": [
      "Read(./KeychestKeys/**)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Bash(security *)",
      "Bash(op *)",
      "Bash(keychest generate*)",
      "Bash(keychest set*)"
    ]
  }
}
```

Permission rule syntax can change between versions; confirm with `/permissions` or the current Claude Code docs. Deny rules are strongest for the assistant's file tools; for shell access, also consider the sandbox.

## Workflow

Run `keychest generate` yourself in a terminal, then let the assistant build and test against the generated package (it only needs to compile it, not read it). Other assistants offer similar ignore/deny settings; use whichever applies.
