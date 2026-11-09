# Policy: when human approval is required

Four gates. Each one is a point where an agent stops and a person decides. The risk level
(`risk.md`) decides which gates apply to a change.

| Gate | Decision | low | medium | high |
|---|---|---|---|---|
| **G0 spec approval** | the spec describes the right change | required | required | required |
| **G1 plan approval** | the implementation plan is the right way | – | required | required |
| **G2 merge approval** | a person reviewed the PR: the label `human-approved`, or an approving review | – | required | required |
| **G3 verification evidence** | the `/verify` table on the final commit, read by the approver | – | – | required |

## How each gate is recorded

- **G0**: a person sets `status: approved` in the spec frontmatter and in the row of
  `docs/specs/README.md`. The commit that does this is by a person. Agents never write `approved`.
- **G1**: the person answers the plan in the session. `/implement` continues only after a yes.
  The plan is kept in the PR body under `## Plan`.
- **G2**: the label named in `harness/config.yml` (`human_approval_label`, default
  `human-approved`) set by a person after reading the PR, or an approving review by another
  person. The `human-gate` job in `auto-merge.yml` is a required check and reads both.
- **G3**: the `/verify` comment names the head commit SHA. The approver confirms the SHA matches.

## Who reviews

The person who directs the agents is the reviewer. They write or approve the spec, approve the
plan, read the pull request and set the label. GitHub does not let the author of a PR approve it,
and the director is the author of every PR their agents open, so the label is the normal way to
record G2. The deny rules in `.claude/settings.json` keep agents away from `gh label` and
`gh pr edit`; CI never sets the label.

A second person reviews in two cases:

1. `second_reviewer_for` in `harness/config.yml` names the level (`high`, or `medium` for medium
   and high). Then only an approving review passes the gate; the label alone does not.
2. The director decides it for one PR: they request a review and leave the label off.

A project with a team sets `second_reviewer_for: high` at least. A project with one person keeps
it empty.

## Always a person, regardless of level

- Merging a medium or high risk PR, and setting the label `human-approved` on one.
- Setting a spec to `approved`.
- Changing `AGENTS.md`, `CLAUDE.md`, `harness/policies/`, `harness/risk-matrix.yml`,
  `harness/config.yml`, `.github/workflows/`. These paths are denied for agent edits and listed
  in `.github/CODEOWNERS`.
- Deleting data, rotating secrets, changing infrastructure, spending money.
- Any question the spec leaves open. The agent lists the question and stops; it does not pick an
  answer.

## What agents decide alone

- Everything inside an approved spec and an approved plan: naming, file layout, test cases,
  refactoring on the way, the order of commits.
- Raising a risk level. Never lowering it.
- Reporting a finding as blocking or not, by the categories in the review skills.

## When a gate is skipped

A skipped gate is a policy violation, not a shortcut. The PR gets the label `needs-human`, which
blocks auto-merge, and the person decides whether to accept the work or to redo the gate.
