# 0024: Gates run by the scope of the change

Status: accepted, 2026-11-26. Changes 0002 and 0018. Adds to 0022.

## Context

`quality-gates.yml` runs seven jobs for every push to a pull request branch. Each job checks out
the code, runs the setup action of the project (toolchain, dependency install) and one gate. The
paths of the change play no part.

One pull request of level medium or high gets these pushes:

1. the code;
2. zero to two pushes with fixes after the review or after CI;
3. the push of `verify`: only the front matter of the spec under `docs/specs/`.

Push 3 starts all seven jobs again for a commit that changed one Markdown file, and `implement`
waits for them (`gh pr checks --watch`, step 9.3). A pull request that changes only documents (a
roadmap, an ADR, a spec) runs tests, type check and the dependency scan of code it did not touch.

`deps` reads the lock files and two external sources (OSV, endoflife.date). On a pull request
that changes no manifest its result depends only on the day, not on the change. A new advisory
fails pull requests that have nothing to do with it.

`verify` runs `make check` again when it is started on its own (`/verify <n>`, a worker of a wave,
a second round after a fix), although CI ran the same gates on the same commit. Started from
`implement` without a change in between it uses the results of `implement` already (0018).

Measured: nothing. The decision rests on the count of runs, not on minutes. The local
`make check` before the push stays as it is: on a machine without `semgrep`, `gitleaks` and
`osv-scanner` it runs only `test`, `typecheck`, `lint` and `drift`.

## Decision

### 1. `harness/scripts/gate-scope.sh` says whether a gate runs

`gate-scope.sh --gate <name> --files-from <file> [--matrix <file>] [--config <file>]` prints
`run` or `skip: <reason>` and exits 0. The step "Gate active" of `quality-gates.yml` calls it; it
holds the two rules for `drift` and `e2e` that are in the workflow today. The script and the
matrix come from the base branch on a pull request, as in `ai-review.yml`.

Rules for a pull request, by the files of the whole pull request (`base...head`):

| Change | `test` `typecheck` `drift` `e2e` | `lint` `sast` | `deps` |
|---|---|---|---|
| only documents (`docs/**`, `**/*.md`) | skip | run | skip |
| no dependency manifest, not `harness/config.yml`, not `osv-scanner.toml` | run | run | skip |
| anything else | run | run | run |

- Dependency manifests are the list `dependency_manifests` of `harness/risk-matrix.yml`.
  `harness/config.yml` counts because of the list `stack`.
- `lint` runs for documents because a project may lint Markdown; `sast` because of the secret
  scan.
- The person chose "`deps` only with a manifest change" on 2026-11-26.
- A push to the default branch and a `workflow_dispatch` (0022) run every gate. This is the run
  that shows a new advisory for an unchanged dependency.
- A skipped job passes without the setup action, with the reason in its log. The check names stay,
  so the ruleset does not change.
- Files that define a gate count as "anything else" for `deps`: `Makefile`, `*.mk`,
  `harness/risk-matrix.yml`, `harness/scripts/gate-scope.sh`, `stack-check.sh`, `drift.sh`,
  `.github/workflows/`, `.github/actions/`.
- `drift` and `e2e` keep their switches (0012, 0013). The base config decides; the config of the
  pull request may switch a gate on, never off.

### 2. A push that changes only documents takes over the results of the commit before

On `synchronize`, `gate-scope.sh --since <before sha>` skips a gate when all of this is true:

- `before` is an ancestor of the head (no force push);
- `git diff --name-only before..head` has only `docs/**` and `**/*.md`;
- the check `gates (<gate>)` on `before` has the conclusion `success`.

Otherwise the rules of decision 1 apply. `lint` and `sast` always run. `quality-gates.yml` gets
the permission `checks: read`.

This covers the push of `verify` and the push of `implement` that writes `pr:` into the spec.

### 3. `verify` reads the results of CI

Step 4 of `verify`: for each gate of `make check`, when the check `gates (<gate>)` on the head has
the conclusion `success`, the gate is not run again. Any other state: `verify` runs `make <gate>`.
`harness/scripts/review-status.sh` gets a subcommand that prints the state per gate for a commit
(`gh api repos/<repo>/commits/<sha>/check-runs`).

`verify` still runs what CI does not: the tests of the touched areas that the criteria name, the
end-to-end tests when `e2e_in_ci` is not `true`, and the browser walk. The line `Automatisch` of
the PR body names the source per gate: `CI <sha>` or `lokal`.

Not chosen:

- Local `make check` reduced to the fast gates: no gain on a machine without the scanners, and a
  second target would need a rule for when each one applies.
- `test`, `typecheck` and `lint` in one job: fewer setup runs, but a longer wait and one required
  check in place of three, so a ruleset change in every project.
- No run on the default branch when the merged tree is equal to a tested tree: needs a compare of
  tree hashes across runs and saves one run per merge at most.
- Rules by the touched area of the project (frontend only, backend only): the project owns that
  split; it belongs to its `Makefile` and its setup action.
- `deps` skipped everywhere, the daily `security-watch.yml` as the only run: that workflow is off
  until production (0021).
- `paths` filters of GitHub on the workflow: a required check that never starts blocks the merge.

## Consequences

- A vulnerability published for an unchanged dependency no longer fails a pull request. It shows
  on the next run on the default branch: the push after a merge by a person, the hourly start of
  0022 after a merge by `GITHUB_TOKEN`, or the daily run with `security_watch: true`. In a
  repository without merges and without the daily run nothing shows it, as today.
- The same holds for a release line of the stack that loses support: `stack-check.sh` runs with
  `deps`.
- A pull request can skip gates only through its file list, and the rule script and the matrix
  come from the base branch. A pull request that removes a path from `dependency_manifests` is
  high risk by its change of `harness/risk-matrix.yml`.
- With `human_gate_for: ""` (0023) no person stands behind that last point. A change of
  `harness/risk-matrix.yml`, `harness/config.yml` or a workflow runs every gate: `gate-scope.sh`
  treats these paths as "anything else".
- A project whose tests read files under `docs/` or Markdown files loses that run for a
  documents-only change. The changelog names it; such a project moves the files or keeps the old
  workflow until a key for it exists.
- Decision 2 calls the GitHub API once per job. Without an answer the gate runs.
- Tests: `harness/scripts/tests/` gets cases for `gate-scope.sh` (each row of the table, each
  gate, `--since` with a force push, with a code change, with a failed check before, the rules of
  `drift` and `e2e` moved from the workflow) and for the new subcommand of `review-status.sh` with
  a JSON file as input.
- Version 0.11.0, after 0022 (both change `quality-gates.yml`) and after 0023. `update.sh` brings
  the script, the workflow and the skill. No manual step, no ruleset change.

## Open questions

- [x] `deps` on a pull request without a manifest change? → Skipped; the run on the default
  branch covers it (Morten Möller, 2026-11-26)
- [x] `lint` for a documents-only change: run or skip? → It always runs (Morten Möller,
  2026-11-26)
