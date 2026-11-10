# 0010: Spec approval in the session, plan in the spec, the label merges

Status: accepted, 2026-11-10. Changes 0003 and 0006.

## Context

One feature stopped the person about seven times: approve the spec by editing and committing it,
approve the plan, run `/review` after each push, fix the PR text by hand, set the label, merge.
Only two of these are decisions: is the spec right, and is the pull request right.

## Decision

- **G0**: `/spec` ends with the question whether the spec is approved. On a yes from the person
  the skill writes `status: approved`, creates the branch and commits the spec there. With
  "approve and implement" it continues with `implement`; spec and code are one pull request.
- **G1** is no longer a stop. The spec has a section `## Umsetzung` with the files, the steps and
  one test per criterion. Approving the spec approves the plan. `implement` stops only when the
  change needs a higher risk level than the spec, files or contracts outside the plan, or an
  answer the spec does not give.
- **G2**: the label `human-approved` is the merge decision. When `human-gate` passes for medium or
  high risk, `auto-merge.yml` enables auto-merge, and GitHub merges after every required check.
  `needs-human` blocks only the low-risk path.
- `auto-merge.yml` enables auto-merge only when the base branch has required status checks. A
  repository without a ruleset would otherwise merge at once.
- `implement` and `review` may be started by the model, so `/spec` continues into `implement` and
  every push of a session is reviewed without a command. `/spec` and `/verify` stay on explicit
  request.

## Consequences

- Two stops per feature: the spec question and the label.
- The person approves G0 with a click in the session, not with a commit. The commit that writes
  `approved` is made by the agent and names the approval in the session.
- No agent merges. The merge follows the label of a person and the required checks.
