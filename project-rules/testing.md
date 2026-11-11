---
sources: []
---

# Testing rules

<!-- TODO: fill at project start. sources: the globs of the test setup (for example
     playwright.config.ts, the test data tool); a change there asks to check this file. -->

## Levels

| Level | Tool | Runs in | Scope |
|---|---|---|---|
| unit | TODO | `make test` | pure calculations and isolated mechanisms, no I/O |
| integration | TODO | `make test` | one feature through its public interface (HTTP route, component) with the real database or an in-memory one; test doubles only for other systems |
| end-to-end | TODO or none | `make e2e`, in CI only with `e2e_in_ci: true` | user flows in the browser against the running application |

## Rules

- A change to behaviour comes with a test that fails without the change.
- Test behaviour through the public interface, not private methods. No mocks of own classes; a
  test double stands in for another system only (payment provider, mail, clock).
- Tests are named after the behaviour, not the method.
- A test creates the data it needs and does not count rows of others. Test data comes from
  builders or factories: TODO. No reflection into private state.
- Flaky tests are fixed or deleted in their own PR, never retried in CI.
- Coverage floor, if any: TODO. The floor is a gate; lowering it is a reviewed change.

## Areas

Which tests belong to which source paths. `implement` and `/verify` run the tests of the areas a
change touches.

| Source path | Unit and integration | End-to-end |
|---|---|---|
| TODO `src/orders/` | TODO `tests/orders/` | TODO `e2e/orders.spec.ts` |

## End-to-end

- Start: TODO. Either the tests start the application themselves (Playwright `webServer`, a
  compose file); then `e2e_in_ci: true` is possible. Or the application must run before
  (`make dev`); then `make e2e` runs locally only.
- One spec: TODO (for example `pnpm exec playwright test e2e/orders.spec.ts`).
- A criterion of a spec that names a screen gets an end-to-end test when this level exists;
  otherwise `/verify` walks the screen in the browser.
- Selectors: TODO (for example `data-testid` first, then role and name; never CSS classes of a
  component library).
- Waits: on a visible state or a request, never a fixed sleep.

## Test data

- Command: TODO, for example `make seed STATE=<name>` or a project CLI. It needs no knowledge of
  tables and prints one JSON document per call (`ok`, `data`, `error.code`).
- Environment check: TODO (`make seed-doctor`): which services must run, with the fix for each.
- Named states: TODO (for example `empty`, `with-items`, `checked-out`).
- Never write rows by hand, never call internal endpoints, never click through the application to
  make data that the command makes. A state the command lacks goes into a spec; the command is
  extended there.

## What `/verify` runs

- Automated: `make check` and the tests of the touched areas (table Areas).
- Browser checks: which URL, which login, which test data state: TODO.
