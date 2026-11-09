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
4. The rule check in `ai-review.yml` fails when a script or the matrix is missing on the base
   branch, instead of taking the copy of the pull request.

## Consequences

- A switched-off check always needs a person, also in a low-risk PR.
- A second reviewer needs real write permission; a reader of an organisation does not count.
- A change to the config format touches every script that reads it. The tests in
  `harness/scripts/tests/run.sh` cover each reader.
