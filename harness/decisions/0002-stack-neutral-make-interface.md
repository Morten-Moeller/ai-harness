# 0002: Quality gates are make targets with fixed names

Status: accepted, 2026-11-09

## Context

Projects use different stacks (TypeScript, .NET, Go, others). CI, the skills and the policies need
one way to run the gates.

## Decision

Five targets: `test`, `typecheck`, `lint`, `sast`, `deps`, plus `check` for all of them. The
project fills the first three. `sast` and `deps` default to stack-neutral tools (semgrep, gitleaks,
osv-scanner) in `harness/gates.mk`. Unfilled targets fail with a message.

## Consequences

- CI (`quality-gates.yml`) and the skills call `make <gate>` and never a stack tool directly.
- A project without a kind of check replaces the stub with a one-line exit 0 target and a reason.
- GNU make 3.81 (macOS default) is the floor: no `.RECIPEPREFIX`, no `!=`.
