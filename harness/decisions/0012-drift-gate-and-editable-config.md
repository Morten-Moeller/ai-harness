# 0012: Drift gate for generated files; agents may edit the config and the risk matrix

Status: accepted, 2026-11-11.

## Context

Generated files (contracts, API types) are committed. The harness only reported a changed file
with a generated header (`generiert` rule of `review-rules.sh`). Nothing checked that the
committed copy matches its source: a forgotten regeneration, a hand edit or a merge of two
branches that both changed a contract passed every gate. A larger monorepo of the same team
regenerates its contracts in CI and fails on a difference; this decision takes that check over.

`contracts_generate_target` in `harness/config.yml` names the generator. The settings of a
project denied agents every edit of `harness/config.yml` and `harness/risk-matrix.yml`, so a
spec that introduced a generator stopped for the person to edit one line. CI already reads both
files from the base branch when it decides the risk level, the human gate and the merge
(`auto-merge.yml`); only the rule check read the config of the pull request.

## Decision

- A sixth gate, `make drift` (`harness/scripts/drift.sh`): it runs `make <contracts_generate_target>`
  and fails when the generator changed a file. Empty target: the gate passes and CI skips the
  setup action for it. The gate is part of `make check`, runs in `quality-gates.yml` as
  `gates (drift)` and is a required check of the ruleset.
- `bootstrap.sh --contracts-target <target>` sets the key at project start.
- The project settings template no longer denies edits of `harness/config.yml` and
  `harness/risk-matrix.yml`. Both stay high risk, so every change waits for the label of a person.
- The rule check in CI (`review-rules`) reads the config of the base branch, like the risk matrix.
  A pull request is judged by the config and matrix it started from, never by the ones it changes.

Not adopted from that monorepo: a no-op merge driver (`merge=generated` in `.gitattributes`) for
generated files. Pull requests are merged one after the other; the drift gate fails a bad merge
result and the regeneration fixes it.

## Consequences

- An agent sets `contracts_generate_target` in the same change that adds the generator target;
  the spec plan names `harness/config.yml`, and the label approves it.
- An agent can also propose a lower risk level for a path or switch off a review rule. That pull
  request is high risk and is judged by the old matrix and config; the person reads the change
  before the label.
- The gate `drift` reads the target from the pull request, not from the base branch, so the change
  that introduces a generator is checked at once. A pull request that empties the key skips the
  gate; that change to `harness/config.yml` is high risk, and the rule `generiert` still reports a
  hand edit of a file with a generated header.
- The generator must be deterministic: the same source gives the same bytes. A timestamp or an
  unsorted map in the output fails the gate on every run.
- `make check` runs the generator, which can need a build (for example `mvn package`).
- After `update.sh` a project runs `setup-repo.sh` once, so the ruleset requires `gates (drift)`.
