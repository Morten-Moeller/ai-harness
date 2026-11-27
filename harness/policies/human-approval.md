# Policy: when human approval is required

Four gates, decided at two points: the spec with its plan (G0, G1) and the pull request (G2,
G3). The risk level (`risk.md`) decides which gates apply to a change, `human_gate_for` in
`harness/config.yml` which levels need G2.

| Gate | Decision | low | medium | high |
|---|---|---|---|---|
| **G0 spec approval** | the spec describes the right change | required | required | required |
| **G1 plan approval** | the implementation plan in the spec is the right way | with G0 | with G0 | with G0 |
| **G2 merge decision** | a person reviewed the head commit: the label `human-approved` after the last push, or an approving review by another person; then GitHub merges | – | required, unless `human_gate_for` exempts it | required, unless `human_gate_for: ""` |
| **G3 verification evidence** | `verify` passed on the head commit: the status `verified` and the table in the PR body | – | with `verify_required_for: medium`, or exempt from G2 | required (default) |

## How each gate is recorded

- **G0**: the person answers the approval question of `/spec` in the session. Only on that answer
  the skill writes `status: approved` in the spec front matter and commits it with the name of
  the person and the date. `/roadmap` asks once for a whole wave; the answer is G0 for each of its
  specs. A person may also set the status by hand.
- **G1**: the plan is the section `## Umsetzung` of the spec and is approved with it. `implement`
  stops and asks when the change leaves the plan: a higher risk level, files or contracts that
  change what the spec promises, an edge case without an answer.
- **G2**: the label named in `harness/config.yml` (`human_approval_label`, default
  `human-approved`), set by a person after the push of the head commit, or an approving review of
  the head commit by a person other than the author with the permission write, maintain or
  admin on the repository. The `human-gate` job in `auto-merge.yml` is a
  required check; it runs `harness/scripts/human-gate.sh` with the configuration of the base
  branch. When it passes, `auto-merge.yml` enables auto-merge, so the label is the merge decision.
  A push makes the label stale; set it again after reading the new commits.
- **G3**: the commit status `verified` = `success` on the head commit, set by `verify` with
  `harness/scripts/review-status.sh verify` (decision 0018). `human-gate.sh` checks it before G2
  for the levels in `verify_required_for` (`harness/config.yml`: `high` by default, `medium` for
  medium and high, `""` off; any other value fails the gate). The line `Geprüft:` of the criteria
  table in the PR body names the checked commit; the head adds only the spec state. Pull requests by
  bots are exempt: they have no spec, CI is their check. A push removes the status; `verify` runs
  again before the label.

## Levels without G2

`human_gate_for` in `harness/config.yml` (decision 0023) names the levels of G2: `medium`
(default, also when the key is missing) for medium and high, `high` for high, `""` for none. Any
other value fails the gate. The setting is for test projects where the person reads no pull
request; never for a project with production data.

- An exempt level needs the status `verified` = `success` on the head, whatever
  `verify_required_for` says. Pull requests by bots stay exempt from it, as from G3.
- The label `needs-human` (set by `review-rules` for a switched-off check, or by a person) puts G2
  back on that pull request. A level in `second_reviewer_for` is never exempt.
- The key applies to every author; `auto_merge_allowlist` plays no part for medium and high.
- A criterion `nicht prüfbar` does not block the merge. `verify` opens one issue
  `Prüfen: <spec title> (<NNNN>, #<n>)`, assigned to the account of the session, with the steps for
  the check by hand. The person checks after the merge and closes it; a criterion that fails is a
  new `fix` spec with the issue number. `verified` means: the automated checks pass, no criterion
  is `nicht erfüllt`, and each criterion `nicht prüfbar` has its issue.
- The pull request that changes `human_gate_for` is high risk and is judged by the value on the
  base branch.

## Who reviews

The person who directs the agents is the reviewer. They approve the spec with its plan, read the
pull request and set the label. GitHub does not let the author of a PR approve it, and the
director is the author of every PR their agents open, so the label is the normal way to record G2.
The guard hook `.claude/hooks/guard-bash.sh` and the deny rules in `.claude/settings.json` keep
agents away from every label change; CI never sets the label.

A second person reviews in two cases:

1. `second_reviewer_for` in `harness/config.yml` names the level (`high`, or `medium` for medium
   and high). Then only an approving review passes the gate; the label alone does not. Any other
   value than `""`, `high` or `medium` fails the gate.
2. The director decides it for one PR: they request a review and leave the label off.

A project with a team sets `second_reviewer_for: high` at least. A project with one person keeps
it empty.

## Always a person, regardless of level

- Setting the label `human-approved` on a PR of a level in `human_gate_for`; the merge follows
  from it.
- Approving a spec: the answer in the session or the status by hand.
- Changing `AGENTS.md`, `CLAUDE.md`, `harness/policies/`, `harness/risk-matrix.yml`,
  `harness/config.yml`, `harness/scripts/human-gate.sh`, `.github/workflows/auto-merge.yml`.
  These paths are denied for agent edits in a project and listed in `.github/CODEOWNERS`.
- Deleting data, rotating secrets, changing infrastructure, spending money.
- Any question the spec leaves open. The agent lists the question and stops; it does not pick an
  answer.

## What agents decide alone

- Everything inside an approved spec and its plan: naming, file layout, test cases,
  refactoring on the way, the order of commits.
- Raising a risk level. Never lowering it.
- Reporting a finding as blocking or not, by the categories in the review skills.

## When a gate is skipped

A skipped gate is a policy violation, not a shortcut. The PR gets the label `needs-human`, which
blocks auto-merge, and the person decides whether to accept the work or to redo the gate.
