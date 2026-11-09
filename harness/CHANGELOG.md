# Changelog

Versions follow semver. Breaking means: a project needs a manual step after `update.sh`.

## 0.2.1 (2026-11-09)

No manual step.

- An approval counts for G2 only from a person with the permission write, maintain or admin
  (collaborators API). Since 0.2.0 approvals also have to be on the head commit and from an
  account of type `User`.
- `review-rules.sh` blocks when the list `gate_markers` is missing or empty.
- `/review` decides the combined agent run by the size of the diff it reviews, the delta for an
  incremental run.
- The rule check in CI takes its scripts only from the base branch and removes a `needs-human`
  label that CI set when no gate finding is left. Decision 0008.

## 0.2.0 (2026-11-09)

Manual steps after `update.sh`:

- Add `human_approval_label: human-approved`, `second_reviewer_for: ""`,
  `review_combined_max_lines: 150` and `review_rules_disabled:` to `harness/config.yml`; remove
  `reviewer_model`. Rerun `harness/scripts/setup-repo.sh`: it creates the label and removes the
  code-owner requirement from the ruleset.
- Apply the new `.github/workflows/auto-merge.yml` by hand when the project keeps it on the deny
  list. `human-gate` now runs `harness/scripts/human-gate.sh` from the base branch (decision 0006).
- Set `cooldown.default-days: 7` in `.github/dependabot.yml`. The semgrep rule
  `dependabot-missing-cooldown` treats smaller values as missing and fails `make sast`.

Changes:

- G2 by label or by an approval of the head commit, decision 0006.
- `/review` replaces `/review-code`, `/review-security` and `/review-architecture`: rule script,
  reviewer agents on Sonnet, incremental runs, decision 0007.
- New scripts `review-rules.sh` and `human-gate.sh`; `ai-review.yml` runs the rule check.
- The PR template has a section `Gate-Änderung`.

## 0.1.0 (2026-11-09)

First version. Workflow with gates G0–G3, risk policy with machine-readable matrix, ADR, human
approval and auto-merge policies, ten skills, three reviewer agents, two hooks, four workflows,
bootstrap, update and setup scripts. Review skills run in the session; CI checks their comments
and runs them itself only with a token secret (decision 0005).
