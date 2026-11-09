# Project rules

Stack-specific rules that every change follows. `/implement` reads the file for the area it
touches; `/review` checks against them. A rule that cannot be
followed needs an ADR (`harness/policies/adr.md`).

| File | Covers |
|---|---|
| `frontend.md` | UI code: framework, state, styling, i18n, accessibility |
| `backend.md` | services, data access, errors, logging, configuration |
| `testing.md` | test levels, naming, fixtures, what `make test` runs |

Keep each file short: rules, not tutorials. One rule per bullet, with the reason when it is not
obvious. Replace every `TODO` block at project start.
