# Testing rules

<!-- TODO: fill at project start. -->

## Levels

| Level | Tool | Runs in | Scope |
|---|---|---|---|
| unit | TODO | `make test` | one module, no I/O |
| integration | TODO | `make test` | module with database or HTTP, test doubles for other systems |
| end-to-end | TODO | separate target `make e2e`, not a gate | user flows against a running system |

## Rules

- A change to behaviour comes with a test that fails without the change.
- Tests are named after the behaviour, not the method.
- Test data comes from builders or factories: TODO. No reflection into private state.
- Flaky tests are fixed or deleted in their own PR, never retried in CI.
- Coverage floor, if any: TODO. The floor is a gate; lowering it is a reviewed change.

## What `/verify` runs

- Affected tests: how to select them by changed path: TODO (for example
  `tests/<area>/` matches `src/<area>/`).
- Browser checks: which URL, which login, which test data command: TODO
