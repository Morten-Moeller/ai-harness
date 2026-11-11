# 0018: Verification before the merge, recorded as the status verified

Status: accepted, 2026-11-11. Changes 0010 and the G3 rule of `harness/policies/human-approval.md`.

## Context

In the second test project `/verify` ran twice after the merge. `implement` ended with "set the
label", `/verify` started only on request, and nothing checked the order: the policy named G3 for
high risk, but no script read it. A browser finding after the merge needs a fix pull request, and
each feature needed one more pull request only to set its spec row to `done`.

The line `Geprüft: <date>, Commit <sha>` in the PR body never named the head either: `/verify`
commits the spec row after it writes the line and pushes, so the head is always one commit later.

## Decision

- `implement` runs the skill `verify` for medium and high risk once CI passed, before its summary.
  The summary carries the result; the person reads the PR and sets the label. Two stops per
  feature stay. `/verify <n>` stays for a later check, and the session runs `verify` again after its
  own push to a medium or high risk pull request.
- `verify` sets the commit status `verified` (`harness/scripts/review-status.sh verify`): `success`
  when every criterion is met and every check is green, otherwise `failure`. It sets it on the head
  after its own push of the spec row; that commit adds only the row to the checked one, and the
  description names the checked commit. A later push has no status.
- `human-gate.sh` checks G3 before G2: for the levels in `verify_required_for`
  (`harness/config.yml`: `high`, the default, `medium` for medium and high, `""` off) the head needs
  `verified` = `success`. Pull requests by bots are exempt; they have no spec, CI is their check.
  No new required check: `human-gate` is one already.
- `verify` writes the row as `done` with the PR number instead of `fertig`. The row reaches the
  default branch only with the merge, so `done` is true there and no pull request after the merge
  is needed. For low risk `implement` writes `done` with the PR number. The status `fertig` goes.
- `verify` works without a spec (automated checks only) and, in the harness repository, against the
  decision of the change.

Not chosen: `/verify <n>` as a command of the person before the label; a third stop per feature.
`review-status.sh set --context verified`; the guard keeps `set` for CI. The `Geprüft:` line as the
evidence the gate reads; a status shows in the checks of the pull request and needs write access.

## Consequences

- A high risk pull request merges only after `verify` passed on its head. After a later push the
  session runs `verify` again before the person sets the label.
- `verified` is set by the agent, like `ai-review`. It shows the person that the check ran; the
  decision stays the label.
- A label set before `verify` pushed is stale, as after any push; set it again.
- Every pull request of the harness repository is high risk, so G3 applies here too; `verify` runs
  without a browser.
