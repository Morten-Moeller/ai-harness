# 0015: Project skills survive updates; git hooks; line endings

Status: accepted, 2026-11-11.

## Context

`update.sh` synced `.claude/skills/` and `.claude/agents/` with `--delete`. A skill of the project,
for example the recipe for a new screen or the knowledge of an area, was deleted by the next
update. Skills with `paths:` load by themselves when an agent works on matching files; the
monorepo of 0012 to 0014 keeps its area knowledge that way.

Formatting and fast lint findings reached CI and cost a fix round, because nothing ran on commit.
Line endings were left to each checkout.

## Decision

- `owned-paths.txt` accepts paths with `*`: `.claude/skills/*/` and `.claude/agents/*.md` copy
  each harness skill and agent on its own and keep the ones of the project. A `[remove]` section
  lists harness paths that were dropped, so they are deleted in projects.
- `project-rules/README.md` describes area skills with `paths:`.
- `.githooks/pre-commit` (harness-owned) runs `make precommit` when the project defines it.
  `make setup` sets `core.hooksPath`; `bootstrap.sh` does it for the first clone. The guard hook
  denies `--no-verify` and `git commit -n`.
- `.gitattributes` in the template: LF for text, binary for images and fonts.

## Consequences

- A harness skill that a project changed is still overwritten by the update; project changes go
  into a skill of its own name.
- A harness skill that is dropped needs a line under `[remove]`; without it the old copy stays in
  projects.
- Every clone other than the first runs `make setup` once. Without it the hook does not run; CI
  catches the same findings later.
