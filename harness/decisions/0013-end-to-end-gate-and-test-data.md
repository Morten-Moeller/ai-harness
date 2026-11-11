# 0013: End-to-end tests as an optional gate; test levels and test data in the project rules

Status: accepted, 2026-11-11.

## Context

The harness required `make test` (unit and integration tests) and named end-to-end tests only as
"a separate target, not a gate". No workflow ran them. A criterion that names a screen was left to
the browser walk of `/verify`, which runs only on request and needs a browser in the session. For
medium risk a pull request could merge with screen criteria nobody checked.

A larger monorepo of the same team keeps its Playwright suite out of the pull request gates: it
needs a separate infrastructure stack. Agents run the specs of the touched area locally, and test
data comes from a project CLI with named states instead of rows written by hand. That works there;
a project whose tests start the application themselves can run the suite in CI as well.

## Decision

- A seventh gate, `make e2e`, required as `gates (e2e)`. It runs in CI only with `e2e_in_ci: true`
  in `harness/config.yml`; otherwise the job passes without setup. It is not part of `make check`.
- The project Makefile template has an `e2e` stub that exits 0 with a message.
- `project-rules/testing.md` gets the sections Areas (source path to tests), End-to-end (start,
  one spec, selectors, waits) and Test data (command, environment check, named states). The
  default stance: test through the public interface with the real database; unit tests for pure
  calculations; test doubles only for other systems.
- `implement` writes an end-to-end test for a criterion that names a screen when the project has
  the level, and runs the specs of the touched areas; `/verify` runs them too. `/spec` names them
  in `## Umsetzung`.
- A new skill `test-data` makes data only with the project's command; a missing state goes into a
  spec.

## Consequences

- A project with a self-starting suite gets its screen criteria checked on every pull request.
- A project whose suite needs a running environment keeps `e2e_in_ci: false`; agents run the specs
  locally when the environment is up, and the summary names the ones that did not run.
- The ruleset requires `gates (e2e)`; after `update.sh` a project runs `setup-repo.sh` once.
