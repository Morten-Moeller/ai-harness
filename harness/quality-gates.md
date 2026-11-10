# Quality gates

A gate is a `make` target. Locally, `make check` runs all of them. In CI, `quality-gates.yml` runs
each one as a separate job and the branch ruleset requires all of them. The harness fixes the
target names; the project fills them with its tools.

## The make contract

| Target | Checks | Default in the template | Project fills |
|---|---|---|---|
| `make test` | unit and integration tests | stub, exits 1 with a message | yes, required |
| `make typecheck` | static types | stub, exits 1 with a message | yes, required |
| `make lint` | style and static rules | stub, exits 1 with a message | yes, required |
| `make sast` | static application security testing, secrets | `semgrep --config auto`, `gitleaks detect` | optional additions |
| `make deps` | known vulnerabilities in dependencies | `osv-scanner` over the lock files | optional additions |
| `make check` | all of the above | fixed | no |

The stubs fail on purpose. A project that has not filled a target cannot pass CI, so no gate is
forgotten. A project with no code of a kind (no types, for example) replaces the stub with a
one-line target that prints why and exits 0. That line is reviewed like code.

Rules for every target:

- Exit code 0 means passed. Anything else fails the gate.
- Runs from the repository root, on a clean checkout, without a running service.
- Takes no arguments. Project-specific sub-targets (`make test-frontend`) may exist; `make test`
  calls them.
- Prints the failing output. Quiet success is fine.

## CI mapping

`.github/workflows/quality-gates.yml` runs a matrix over `test typecheck lint sast deps`. Every job
checks out the code, runs `.github/actions/setup` (project-owned: toolchain, caches, dependency
install), then `make <gate>`. The check names are `gates (test)`, `gates (typecheck)` and so on;
`harness/github/ruleset.json` lists them as required.

A gate whose tool is missing on a developer machine prints `übersprungen` and passes there; in CI,
where `CI=true` is set, it fails (`have` in `harness/gates.mk`, decision 0011). Use the same macro
for tools in the project targets: `@if $(call have,<tool>,<gate>,<install hint>); then ...; fi`.

## Default tools for sast and deps

Both defaults are stack-neutral and read the repository as files. They need no build.

- **Semgrep** (`semgrep --config auto --error`): rules by detected language. Add project rules under
  `.semgrep/` and reference them in the Makefile. The `auto` rule set changes over time, so a new
  rule can fail a PR that changed nothing related. For pnpm it requires in `pnpm-workspace.yaml`:
  `minimumReleaseAge: 10080`, `blockExoticSubdeps: true` and `trustPolicy: no-downgrade`.
- **gitleaks** (`gitleaks detect --no-banner --redact`): secrets in the history and the tree. A
  `.gitleaks.toml` allowlist is project-owned and reviewed like code.
- **OSV-Scanner** (`osv-scanner scan --recursive .`): lock files of every ecosystem against the OSV
  database. `osv-scanner.toml` holds ignores with an expiry date and a reason.

Dependabot (`.github/dependabot.yml`) opens the update PRs; `deps` is the gate that catches what is
already in the tree.

## Filling the stubs

Examples, one line each. The project keeps its own commands in `project-rules/testing.md`.

```make
test:       ; pnpm -r test:ci
typecheck:  ; pnpm -r typecheck
lint:       ; pnpm -r lint
```

```make
test:       ; dotnet test Solution.sln --nologo
typecheck:  ; dotnet build Solution.sln --nologo -warnaserror
lint:       ; dotnet format Solution.sln --verify-no-changes
```

```make
test:       ; go test ./...
typecheck:  ; go vet ./...
lint:       ; golangci-lint run
```

## Never weaken a gate

Skipping a test, lowering a coverage floor, adding an ignore rule or a `// nolint` is a change to a
gate. It needs a reason in the PR and, from medium risk, a person's review. An agent that hits a
failing gate reports the output and stops; it does not edit the gate.
