# 0006: The director records G2 with a label; a second reviewer is the exception

Status: accepted, 2026-11-09

## Context

Decision 0004 made `human-gate` read `reviewDecision == APPROVED`. GitHub does not let the author
of a pull request approve it, and the person who directs the agents is the author of every PR
they open. On the first medium-risk PR of this repository the gate could not turn green and, as
a required check, blocked the merge button as well.

## Decision

`human-gate` passes for medium and high when the PR carries the label named in
`harness/config.yml` (`human_approval_label`, default `human-approved`) or has an approving
review. `second_reviewer_for` names the level from which only an approving review counts. The
label is set by a person; agents are denied `gh label` and `gh pr edit`, CI never sets it.

The model behind it: the director reviews. They write or approve the spec, approve the plan and
read the PR. A second reviewer is a decision for a team or for one PR, not the default.

## Consequences

- One person can run the whole workflow, including medium and high risk, without a bypass in the
  ruleset. The quality gates stay enforced for everyone.
- In a team the label lets an author pass their own PR. `second_reviewer_for: high` closes that
  for high risk; `medium` for both levels.
- `setup-repo.sh` creates the label. Projects on 0.1.0 create it by hand and add the two keys to
  `harness/config.yml` (see `harness/CHANGELOG.md`).
