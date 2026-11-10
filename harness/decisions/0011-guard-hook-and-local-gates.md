# 0011: A guard hook instead of blanket deny rules; local gates skip missing tools

Status: accepted, 2026-11-10

## Context

`.claude/settings.json` denied `gh pr edit` as a whole, because `--add-label` could set the label
of the human gate. The agent could then not write the PR title or body, and the person had to.
Deny rules match by prefix; they cannot tell `gh pr edit 5 --body-file f` from
`gh pr edit 5 --add-label human-approved`, and they miss `gh pr create --label`.

Locally `make check` failed whenever a tool was missing (shellcheck, actionlint, semgrep,
gitleaks, osv-scanner), and `implement` stopped on it. CI runs every gate with the tools
installed.

## Decision

- A PreToolUse hook, `.claude/hooks/guard-bash.sh`, reads every Bash command and denies: merge,
  PR reviews, every label change, rulesets, branch protection, repository settings, secrets,
  commit statuses other than `ai-review`, force pushes, pushes to the default branch, and shell
  writes to the paths of the `Edit(...)` deny rules.
- The deny rule for `gh pr edit` goes; the other deny rules stay as a second layer.
- A gate with a missing tool prints "übersprungen" and passes when `CI` is not set. In CI it
  fails as before. `implement` lists skipped gates in its summary.
- In the harness repository `.github/workflows/auto-merge.yml` is not denied for edits. It is
  high risk, so the human gate covers every change to it.

## Consequences

- The agent writes and corrects PR title and body itself.
- The hook is a guard against mistakes, not a security boundary: an agent with the person's
  `gh` token can reach the API in ways no pattern lists. The human gate checks who set the label.
- A gate skipped locally can fail in CI; `implement` waits for CI and fixes such failures.
