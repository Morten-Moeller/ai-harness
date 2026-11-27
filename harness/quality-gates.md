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
| `make deps` | known vulnerabilities in dependencies, release lines of the stack | `osv-scanner` over the lock files, `stack-check.sh` over `stack` in `harness/config.yml` | the list `stack`, optional additions |
| `make drift` | committed generated files match their source | runs `contracts_generate_target` of `harness/config.yml`, passes when it is empty | the generator target |
| `make check` | all of the above | fixed | no |
| `make e2e` | user flows against the running application | stub that prints "no end-to-end tests configured" and exits 0 | optional; in CI only with `e2e_in_ci: true` |
| `make precommit` | fast checks on staged files, run by `.githooks/pre-commit` | not defined | optional |

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

`.github/workflows/quality-gates.yml` runs a matrix over `test typecheck lint sast deps drift e2e`.
Every job checks out the code, asks `harness/scripts/gate-scope.sh` whether its gate runs, then
runs `.github/actions/setup` (project-owned: toolchain, caches, dependency install) and
`make <gate>`. A gate that does not run passes without setup and prints the reason, so the check
names of the ruleset stay.

Which gate runs (decision 0024; on a pull request the script, the matrix and the config come from
the base branch):

| Change | `test` `typecheck` `drift` `e2e` | `lint` `sast` | `deps` |
|---|---|---|---|
| pull request of documents only (`docs/**`, `*.md`) | skip | run | skip |
| pull request without a dependency manifest, `harness/config.yml`, `osv-scanner.toml` or gate file | run | run | skip |
| any other pull request | run | run | run |
| push to the default branch, `workflow_dispatch` | run | run | run |

- `drift` runs only with `contracts_generate_target`, `e2e` only with `e2e_in_ci: true`; the config
  of the pull request may switch either on, never off.
- Gate files: `Makefile`, `*.mk`, `harness/risk-matrix.yml`, `harness/scripts/gate-scope.sh`,
  `harness/scripts/stack-check.sh`, `harness/scripts/drift.sh`, `.github/workflows/`,
  `.github/actions/`.
- A push to a pull request whose commits since the push before change only documents takes over
  the result `success` of each gate on the commit before (the push of `verify`, the push that
  writes `pr:` into the spec). `lint` and `sast` run again.
- A vulnerability published for an unchanged dependency shows on the next run on the default
  branch, not on a pull request.
- `verify` reads the results per gate on the head (`review-status.sh gates`) and runs only the
  gates that are not `success`.
The check names are `gates (test)`, `gates (typecheck)` and so on; `harness/github/ruleset.json`
lists them as required.

The workflow also runs on a push to the default branch. A merge through `GITHUB_TOKEN` (auto-merge)
starts no workflow, so `branch-cleanup.yml` starts `quality-gates.yml` every hour by
`workflow_dispatch` when the head of the default branch has no run of it (decision 0022). Pull
requests that merge one after the other are each tested alone; this run tests their combination.
A failed run shows within the hour and does not undo the merge.

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
  database, which holds the CVE and GHSA advisories. `osv-scanner.toml` holds ignores with an
  expiry date and a reason.

Dependabot (`.github/dependabot.yml`) opens the update PRs; `deps` is the gate that catches what is
already in the tree. The file is project-owned: the skeleton spec adds the package ecosystems of
the project (npm, maven, gradle, nuget, gomod, pip, docker), otherwise Dependabot updates only the
GitHub Actions. `setup-repo.sh` turns on Dependabot alerts and security updates.

## Stack versions

`make deps` then runs `harness/scripts/stack-check.sh` (decision 0021,
`harness/policies/versions.md`). It reads the list `stack` of `harness/config.yml` and the release
data of <https://endoflife.date>, and needs `jq`.

| Finding | Result |
|---|---|
| a line without support | fails, with or without ADR |
| a newer LTS line, LTS for at least `stack_lts_grace_days` days (30), entry without `adr:<NNNN>` | fails |
| a line that is not LTS while the product has LTS lines, entry without `adr:<NNNN>` | fails |
| `adr:<NNNN>` without a file `docs/adr/NNNN-*.md` | fails |
| an empty list in a repository with a dependency manifest | fails |
| a product or a line that endoflife.date does not have, an entry of another form | fails, exit 2 |
| no answer from endoflife.date | fails; start the run again |
| a newer LTS line inside the grace period or with ADR, support that ends within 90 days, a newer line of a product without LTS lines | note |

`harness/scripts/stack-check.sh --latest <product>` prints the line a new decision takes and the
other supported lines.

## Daily run

`.github/workflows/security-watch.yml` runs `make deps` every day on the default branch, so a
vulnerability published after the merge and a line that aged are found without a pull request. It
runs only with `security_watch: true` in `harness/config.yml`; set it with the first production
release. A manual start (`gh workflow run security-watch.yml`) always runs.

A finding fails the run. GitHub sends its mail for a failed scheduled run to the person who last
changed the schedule of the workflow file. With the secret `SECURITY_WATCH_SLACK_WEBHOOK` (a Slack
incoming webhook) the run also posts the end of the output to that channel. GitHub stops scheduled
runs of a repository without activity for 60 days.

## Generated files

`make drift` (`harness/scripts/drift.sh`, decision 0012) runs the make target named in
`contracts_generate_target` and fails when it changed a file: the committed generated copy does
not match its source. The new output stays in the working tree; review it and commit it with the
source. Locally the gate compares only what the generator touched, so other uncommitted work does
not count.

Rules for the generator target:

- It writes every generated file the project commits: contracts, API types, client code.
- The same source gives the same bytes. No timestamps, no unsorted maps, no absolute paths.
- It needs no running service; a build is fine (`mvn package`, `dotnet build`).
- A tool that is missing locally uses `have` like the other gates; CI runs it.

Set the key at project start (`bootstrap.sh --contracts-target <target>`) or in the change that
adds the generator. A change to `harness/config.yml` is high risk; CI judges it by the config of
the base branch.

## End-to-end tests

`make e2e` drives the application in a browser (decision 0013). It is not part of `make check`:
`implement` and `/verify` run the specs of the touched areas (`project-rules/testing.md`, table
Areas). Two ways to run:

- **Self-starting**: the test runner starts the application (Playwright `webServer`, a compose
  file) and needs only the toolchain of the setup action. Then set `e2e_in_ci: true`, and the
  required check `gates (e2e)` runs the suite on every pull request. The setup action installs the
  browsers.
- **Against a running environment**: the application or its services run outside the tests
  (`make dev`, a separate infrastructure repository). Then `e2e_in_ci` stays `false`; the check
  passes without running, and the specs run locally.

A criterion of a spec that names a screen gets an end-to-end test when the project has them;
otherwise `/verify` walks the screen in the browser.

## Git hooks

`make setup` points `core.hooksPath` to `.githooks/` (bootstrap does it for the first clone). The
harness-owned `pre-commit` runs `make precommit` when the project `Makefile` itself defines it (a
target in an included file is not found): fast checks on the staged files, such as the formatter in
check mode. The guard hook denies `--no-verify`.

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
