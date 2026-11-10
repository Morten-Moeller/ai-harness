# 0006: The director records G2 with a label; a second reviewer is the exception

Status: accepted, 2026-11-09. Supersedes the gate condition of 0004; changed by 0010.

## Context

Decision 0004 made `human-gate` read `reviewDecision == APPROVED`. GitHub does not let the author
of a pull request approve it, and the person who directs the agents is the author of every PR
they open. On the first medium-risk PR of this repository the gate could not turn green. With
`required_approving_review_count: 0` in the ruleset, `reviewDecision` also stays empty, so an
approval by a second person would not have counted either.

## Decision

The gate logic lives in `harness/scripts/human-gate.sh`. `auto-merge.yml` runs the copy of that
script, of `harness/config.yml`, of `harness/risk-matrix.yml` and of `risk-level.sh` from the base
branch. A pull request cannot change the rules it is judged by.

For medium and high risk the gate passes when one of these holds:

1. A person other than the author, with write access (`author_association` owner, member or
   collaborator) and an account of type `User`, approved the head commit (reviews API,
   `commit_id`).
2. The label from `human_approval_label` (default `human-approved`) was set by an account of type
   `User` after the push of the head commit. The push time is the first workflow run for that
   commit. A label from before the push is stale; the job removes it.

`second_reviewer_for` (`""`, `high`, `medium`) names the level from which only the first way
counts. Any other value fails the gate. A label name with `:` or the name `needs-human` fails the
gate as well.

The ruleset no longer requires a code-owner review. CODEOWNERS still requests the reviewers.

The model behind it: the director reviews. They write or approve the spec, approve the plan and
read the PR. A second reviewer is a decision for a team or for one PR, not the default.

## Consequences

- One person can run the whole workflow, including medium and high risk, without a bypass in the
  ruleset. The quality gates stay enforced for everyone.
- Every push needs a new label, just as it would dismiss an approval.
- Agents are kept away from the label by deny rules for `gh label`, `gh pr edit`,
  `gh issue edit`, `gh api *labels*` and `gh api graphql`. The deny rules run on the client; the
  `User` check only rules out apps.
- In a team the label lets an author pass their own PR. `second_reviewer_for: high` closes that
  for high risk; `medium` for both levels.
- Projects on 0.1.0 create the label, add the two keys to `harness/config.yml` and rerun
  `setup-repo.sh` for the ruleset (see `harness/CHANGELOG.md`).
