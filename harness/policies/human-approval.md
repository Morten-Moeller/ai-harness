# Policy: when human approval is required

Four gates. Each one is a point where an agent stops and a person decides. The risk level
(`risk.md`) decides which gates apply to a change.

| Gate | Decision | low | medium | high |
|---|---|---|---|---|
| **G0 spec approval** | the spec describes the right change | required | required | required |
| **G1 plan approval** | the implementation plan is the right way | – | required | required |
| **G2 merge approval** | an approving PR review by a person | – | required | required |
| **G3 verification evidence** | the `/verify` table on the final commit, read by the approver | – | – | required |

## How each gate is recorded

- **G0**: a person sets `status: approved` in the spec frontmatter and in the row of
  `docs/specs/README.md`. The commit that does this is by a person. Agents never write `approved`.
- **G1**: the person answers the plan in the session. `/implement` continues only after a yes.
  The plan is kept in the PR body under `## Plan`.
- **G2**: an approving review on the PR. The `human-gate` job in `auto-merge.yml` checks
  `reviewDecision == APPROVED` for medium and high and is a required check.
- **G3**: the `/verify` comment names the head commit SHA. The approver confirms the SHA matches.

## Always a person, regardless of level

- Merging a medium or high risk PR.
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
