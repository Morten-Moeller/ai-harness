# 0008: Gate markers raise the risk; gate scripts stay self-contained

Status: accepted, 2026-11-09. Adds to 0006 and 0007.

## Context

The reviews of PR #4 found three things that 0006 and 0007 do not record:

- The label `needs-human`, set by CI with `GITHUB_TOKEN`, starts no workflow. A low-risk PR with
  a switched-off check could get auto-merge enabled before the label arrived.
- `author_association` `MEMBER` or `COLLABORATOR` does not mean write permission.
- The awk readers for the matrix and the config exist in several scripts.

## Decision

1. `gate_markers` in `harness/risk-matrix.yml` lists the patterns of switched-off checks.
   `risk-level.sh` raises a low-risk PR with such an added line to medium; `review-rules.sh`
   reports the lines. Option not taken: a finding only, without raising the risk, because the
   finding arrives too late for auto-merge.
2. `human-gate.sh` counts an approval only when the collaborators API reports `write`, `maintain`
   or `admin` for the reviewer.
3. The scripts that CI runs from the base branch (`risk-level.sh`, `review-rules.sh`,
   `human-gate.sh`) stay self-contained and keep their own config readers. CI copies them one by
   one into a temporary directory, where a shared helper would be missing. Option not taken: a
   shared `harness/scripts/lib/`, which would need a second copy step and a second place to keep in
   sync with the base branch.
4. The rule check in `ai-review.yml` runs scripts only from the base branch. When the base has
   no `review-rules.sh` yet, the check is skipped with a notice instead of running code of the
   pull request; a base matrix without `gate_markers` is replaced by the matrix of the pull
   request, which is data and not code. Option not taken: fail in both cases, because then the
   update pull request of a project could never bring the files in.
5. `auto-merge.yml` keeps its fallback to the copy of the pull request for `human-gate.sh`. Without
   it the update pull request to 0.2 could never pass G2. In a project whose base has no
   `human-gate.sh`, a pull request can change the workflow file itself as well (0006), so the
   fallback opens no new way.

## Consequences

- A switched-off check always needs a person, also in a low-risk PR.
- A second reviewer needs real write permission; a reader of an organisation does not count.
- The update pull request from 0.1 runs without rule check and with the gate script of the
  pull request. A person reviews it by hand (`harness/CHANGELOG.md`).
- A change to the config format touches every script that reads it. The tests in
  `harness/scripts/tests/run.sh` cover each reader.
