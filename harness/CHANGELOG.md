# Changelog

Versions follow semver. Breaking means: a project needs a manual step after `update.sh`.

## 0.2.0 (2026-11-09)

Manual steps after `update.sh`:

- Create the label `human-approved` (`harness/scripts/setup-repo.sh` does it) and add
  `human_approval_label: human-approved` and `second_reviewer_for: ""` to `harness/config.yml`.
  `human-gate` now passes for medium and high with the label or an approving review (decision
  0006). Without the label key the gate still requires an approving review.
- Set `cooldown.default-days: 7` in `.github/dependabot.yml`. The semgrep rule
  `dependabot-missing-cooldown` treats smaller values as missing and fails `make sast`.

## 0.1.0 (2026-11-09)

First version. Workflow with gates G0–G3, risk policy with machine-readable matrix, ADR, human
approval and auto-merge policies, ten skills, three reviewer agents, two hooks, four workflows,
bootstrap, update and setup scripts. Review skills run in the session; CI checks their comments
and runs them itself only with a token secret (decision 0005).
