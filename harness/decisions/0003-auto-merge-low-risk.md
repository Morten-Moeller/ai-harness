# 0003: Low-risk pull requests merge automatically

Status: accepted, 2026-11-09. Changed by 0010: medium and high risk merge after the label.

## Context

Documentation, tests, formatting and dependency patch updates make up a large share of pull
requests. Waiting for a person on each one costs time and adds no safety.

## Decision

`auto-merge.yml` enables GitHub auto-merge when every condition in
`harness/policies/auto-merge.md` holds. The risk level is recomputed in the job; the label is not
trusted. `review-code` is a required check that fails on blocking findings.

## Consequences

- Medium and high risk never merge without a person.
- The risk matrix is the single place that decides what is low. Lowering a level is a reviewed
  change to the matrix, never a per-PR override.
- The repository needs auto-merge enabled and the ruleset imported (`setup-repo.sh`).
