---
name: review-architecture
description: Architecture review of a pull request against docs/architecture, the ADRs and project-rules - module boundaries, dependency direction, deviations without an ADR, missing ADRs per harness/policies/adr.md, contract changes without a spec section - written as a PR comment that starts with "Architektur-Review". Run in the session on explicit request (/review-architecture <PR>); CI checks the comment for high risk or contract changes and runs the skill itself only when a token secret is set.
when_to_use: Load only when the user runs /review-architecture or when the skill review invokes it with a PR number. Do not start it on your own.
argument-hint: <PR number> [--no-rerun]
context: fork
---

# Architecture review

The merge is never part of this skill.

## 1. Resolve

As in `review-code` step 1. An existing comment that starts with `Architektur-Review` for the same
`headRefOid`: report and stop.

## 2. Review

Run the agent `architecture-reviewer` with: the diff path, the spec path,
`docs/architecture/overview.md`, every ADR in `docs/adr/`, the `project-rules/*.md` of the touched
areas and `harness/policies/adr.md`. Without the Agent tool (forked run): do the review yourself
by the rules in `.claude/agents/architecture-reviewer.md`. Take the findings and add:

1. ADR policy: walk the six conditions in `harness/policies/adr.md`. Required and no ADR linked
   in the spec or the PR body: blocking.
2. Contracts: a change under `contracts/` without a `## Contracts` section in the spec, or a
   breaking change without a migration path: blocking.
3. Module boundaries and dependency direction from `docs/architecture/overview.md` and
   `project-rules/`: a new import across a forbidden boundary: blocking.
4. A new dependency, framework or infrastructure component without an ADR: blocking.
5. A rule in `project-rules/` not followed and no ADR records the exception: blocking.
6. Structure that makes the next change harder (duplicated concept, second way to do the same
   thing, generated and hand-written code mixed): non-blocking, with the place and the better
   option.

Each finding names the rule or document it rests on.

## 3. Comment

```text
Architektur-Review <YYYY-MM-DD>, Commit <head SHA>

Ergebnis: <keine blockierenden Befunde | n blockierende Befunde>

| Datei:Zeile | Regel / Dokument | Befund | Blockiert |
|---|---|---|---|

ADR: <vorhanden NNNN | nicht nötig, weil ... | FEHLT: Bedingung n>
```

## 4. CI check

Skip this step when the arguments contain `--no-rerun`; the skill `review` reruns CI once for
all reviews.

The job `review-architecture` in `ai-review.yml` checks for this comment. When the PR already had a
run for this commit, rerun its failed jobs so the check turns green:
`gh run list --workflow ai-review.yml --commit <head SHA> --json databaseId --jq '.[0].databaseId'`
and then `gh run rerun <id> --failed`. No run yet: nothing to do; the next run finds the comment.

## 5. Summary

PR, blocking and non-blocking counts, the ADR verdict, the comment URL.
