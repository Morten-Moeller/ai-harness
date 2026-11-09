# 0004: The human merge gate is a status check, not a ruleset review requirement

Status: superseded by 0006, 2026-11-09

## Context

Branch rulesets require a number of approving reviews for every pull request, regardless of
labels. Low-risk PRs would then need a person after all, or a bot would have to approve, which
GitHub blocks for the default workflow token.

## Decision

The ruleset requires no reviews. Instead the `human-gate` job in `auto-merge.yml` is a required
check. It passes for low risk at once and for medium and high only when
`gh pr view --json reviewDecision` says `APPROVED`. It reruns on every `pull_request_review`
event.

## Consequences

- A person's approval is still the gate for medium and high; it is read by the job.
- A person who dismisses the review turns the check red again.
- The job must stay honest: it is on the agent-denied edit list and in CODEOWNERS.
