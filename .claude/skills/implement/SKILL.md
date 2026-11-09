---
name: implement
description: Implement an approved spec - check gate G0, compute the risk level, enforce the ADR policy, plan (and stop for approval at medium or high risk, gate G1), write code and tests on a branch, run make check, open the pull request from the template and set the spec row to Review. Only on explicit request (/implement <spec-id>).
when_to_use: Load when the user runs /implement or names an approved spec and wants it built. Do not start it on your own and never for a spec that is not approved.
argument-hint: <spec id NNNN or path>
disable-model-invocation: true
---

# Implement

Stage 2 of `harness/workflow.md`. The merge is never part of this skill. A person merges medium
and high risk; low risk merges through `auto-merge.yml`.

## 1. Resolve and gate G0

1. The argument is a spec id or path. Read `docs/specs/NNNN-*.md` and its row in
   `docs/specs/README.md`.
2. `status` must be `approved` in the frontmatter and the row. Anything else: report the status
   and stop. Do not change the status.
3. Read: `AGENTS.md`, the `project-rules/*.md` of the areas in the spec, `docs/domain/glossary.md`,
   `docs/architecture/overview.md`, the ADRs in `adrs`, `contracts/README.md` when `## Contracts`
   is not `keine`.

## 2. Risk and ADR

1. List the files the change will touch. Write them to a scratchpad file and run
   `harness/scripts/risk-level.sh --files-from <file> --format text`. Then run the skill `risk`
   for the reasoning; its block goes into the PR body later.
2. Walk `harness/policies/adr.md`. ADR required and `adrs` empty: stop and report; `/adr` first.
3. The level decides the gates (`harness/policies/human-approval.md`).

## 3. Plan and gate G1

Write the plan: files to create or change, steps in order, one test per acceptance criterion
(or the reason a criterion is checked by `/verify` in the browser instead), contracts to
regenerate, the risk block.

- Medium or high: present the plan with `AskUserQuestion` (approve / change / stop) and wait. No
  code before a yes. The plan goes into the PR body under `## Plan`.
- Low: continue.

## 4. Branch

1. `git status --porcelain` must show no tracked changes. Otherwise stop and report.
2. `git fetch origin`. Branch `<type>/<NNNN>-<slug>` from `origin/<default_branch>`
   (`harness/config.yml`). `<type>` is `feat`, `fix`, `refactor`, `docs` or `chore`.

## 5. Code and tests

- Follow `project-rules/`. Use the glossary terms. No comments in code. Simplified technical
  English in identifiers and messages; user-facing text through the project's i18n.
- Every acceptance criterion gets a test that fails without the change, or a line in the PR body
  that names the `/verify` check instead.
- Contracts: through the skill `contract`, never by hand.
- An edge case the spec does not answer: stop, list it, ask. No silent workaround.

## 6. Checks

1. `make check`. A failing gate caused by this change: fix the change. A failing gate that fails
   on the base branch as well: report it with its output and stop. Never edit a gate, a test of
   someone else, an ignore file or a threshold.
2. Rerun `harness/scripts/risk-level.sh --include-working-tree --format text`. A level above the
   planned one that now needs G1: stop and present the plan again.

## 7. Commit and pull request

1. Commits: `<type>(<scope>): <summary> (<NNNN>)`, with the attribution line from the session.
   Several commits are fine; each one builds.
2. Spec row: `Status` = `Review`, `Stand` = today. Commit `docs(specs): <NNNN> Review`.
3. Push. `gh pr create --title "<type>(<scope>): <spec title> (<NNNN>)" --body-file <file>` with
   the body from `.github/pull_request_template.md`: spec link, risk block, ADR links or
   `none required: <reason>`, the plan, the criteria table with test or `/verify` per row.
4. Edit the spec row: `PR` = `#<n>`. Commit and push the row.

Labels, reviews and the merge are not part of this skill.

## 8. Summary

PR URL, risk level and gates, failing checks with output, criteria left for `/verify`, open
questions. For medium and high: the sentence that a person reviews and merges. Do not report
passing checks.
