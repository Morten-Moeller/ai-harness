---
name: review-security
description: Security review of a pull request - built-in security-review skill or the security-reviewer agent, plus an OWASP checklist, a secret scan of the diff and a check of new or changed dependencies - written as a PR comment that starts with "Security-Review". Runs in CI from medium risk and on explicit request (/review-security <PR>).
when_to_use: Load when the user runs /review-security, or when CI calls it with a PR number. Do not start it on your own.
argument-hint: <PR number>
disable-model-invocation: true
---

# Security review

The merge is never part of this skill.

## 1. Resolve

As in `review-code` step 1. An existing comment that starts with `Security-Review` for the same
`headRefOid`: report and stop.

## 2. Review

- The skill `security-review` is available: invoke it for the PR and take its findings.
- Otherwise: run the agent `security-reviewer` with the diff path, the spec path and
  `project-rules/backend.md` and `frontend.md`.

Checklist in every case, each item answered with `ok`, `finding` or `n/a`:

1. Injection (SQL, command, template, path) on every input that reaches a sink in the diff.
2. Authentication and authorisation: every new endpoint, handler or query checks the caller;
   object-level access (the caller owns the record) on every id from the request.
3. Secrets: nothing in the diff looks like a key, token, password or connection string. Run
   `gitleaks detect --no-banner --redact --log-opts="<base>..<head>"` when gitleaks is installed.
4. Cryptography: no home-made algorithms, no weak modes, keys from configuration.
5. Data: personal data logged, exported or copied to a new place; deletion paths.
6. Dependencies: every new or bumped package in the manifests. Run
   `osv-scanner scan source --recursive .` when installed; otherwise name the packages and
   versions for a person.
7. Frontend: output encoding, `dangerouslySetInnerHTML` or equivalents, URL handling, CSRF.
8. Configuration and infrastructure: open ports, permissive CORS, debug flags, default passwords.

Blocking: a confirmed vulnerability, a secret, a missing authorisation check, a dependency with a
known critical or high vulnerability. Non-blocking: hardening advice.

## 3. Comment

```text
Security-Review <YYYY-MM-DD>, Commit <head SHA>

Ergebnis: <keine blockierenden Befunde | n blockierende Befunde>

| Datei:Zeile | Kategorie | Befund | Blockiert |
|---|---|---|---|

Checkliste: Injection <ok/..>, AuthZ <..>, Secrets <..>, Krypto <..>, Daten <..>, Abhängigkeiten <..>, Frontend <..>, Konfiguration <..>
```

## 4. Summary

PR, blocking and non-blocking counts, the comment URL.
