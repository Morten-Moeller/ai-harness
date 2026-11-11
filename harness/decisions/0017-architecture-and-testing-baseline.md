# 0017: An architecture and testing baseline that a project replaces rule by rule

Status: accepted, 2026-11-11.

## Context

A new project started with empty templates: `docs/architecture/overview.md`, an empty ADR list and
`project-rules/*.md` full of `TODO`. Every project had to decide again how to group code, where to
validate, how errors look, how to test. The few general test rules from 0013 sat in the
project-owned template `project-rules/testing.md`, so existing projects never received them and a
project could drop them while filling the file.

The monorepo of 0012 to 0016 states such decisions as numbered rules (layout, validation and
transaction boundaries, atomic state changes, authorization from the verified identity, one error
shape, end-to-end tests first, no mocks of own code) and checks reviews against them.

## Decision

- Two harness-owned files with numbered, stack-neutral rules: `harness/architecture.md` (A1 to A7:
  structure, API, validation and transactions, data, security, configuration, frontend) and
  `harness/testing.md` (T1 to T7: levels, what a change tests, data and isolation, determinism,
  form, end-to-end, gates). `update.sh` copies both.
- A project replaces a rule with an ADR that names its number. Without such an ADR the rule holds.
  `harness/policies/adr.md` condition 5 covers it.
- `project-rules/testing.md` keeps only the tools, commands, areas, end-to-end setup and test data
  command of the project; `docs/architecture/overview.md` only what the project adds.
- `spec` and `implement` read both files. The architecture review reports a deviation without ADR
  as blocking; the code review names the T rule of a test finding, and a test that only checks a
  mock is a finding.

## Consequences

- A project starts with a complete set of decisions and records only its differences.
- Existing projects get the baseline with the next `update.sh`. Their old code may deviate; the
  reviews look at the diff, so a deviation shows up when the code is touched. A project records the
  deviations it keeps as ADRs.
- A rule that turns out wrong for most projects changes here, in a harness PR, not in each project.
