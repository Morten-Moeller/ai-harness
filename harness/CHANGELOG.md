# Changelog

Versions follow semver. Breaking means: a project needs a manual step after `update.sh`.

## 0.4.1 (2026-11-11)

Decision 0016.

Changes:

- New `.github/workflows/branch-cleanup.yml`: every hour it deletes the head branch of a pull
  request that a bot merged, when the branch still points to the merged commit. The job
  `delete-branch` of 0.3.1 never ran (an event of `GITHUB_TOKEN` starts no workflow) and leaves
  `auto-merge.yml` with its `closed` trigger.

## 0.4.0 (2026-11-11)

Checks instead of prose: generated files against their source, optional end-to-end tests in CI,
project rules as linter rules with a ratchet, documents that name their sources. Project skills
survive updates. Decisions 0012 to 0015.

Manual steps after `update.sh`:

- Run `harness/scripts/setup-repo.sh` after the merge of the update. The ruleset now requires
  `gates (drift)` and `gates (e2e)`; both pass without running until the project configures them.
- `harness/config.yml` (project-owned, `update.sh` shows the diff): add `e2e_in_ci: false`, and
  `doku` to the comment of `review_rules_disabled`. A project with generated files sets
  `contracts_generate_target` to the make target that writes them; the target must be
  deterministic (`harness/quality-gates.md`).
- `Makefile` (project-owned): add the `e2e` target, a stub or the real suite; optional
  `precommit` (`harness/templates/Makefile`).
- `project-rules/testing.md`: take over the sections Areas, End-to-end and Test data from the
  harness template and fill them.
- `AGENTS.md`: the lines of `## Verification` and the test data line of
  `harness/templates/AGENTS.md`.
- Every clone: `make setup` once, so the git hooks run.
- `.gitattributes`: `update.sh` reports it as missing; copy it from the harness and keep the
  project's own lines (generated paths).

Changes:

- New gate `make drift` (`harness/scripts/drift.sh`): runs the generator target and fails when it
  changed a file. `bootstrap.sh --contracts-target <target>` sets the key.
- New gate `make e2e`, required as `gates (e2e)`, runs in CI only with `e2e_in_ci: true`.
  `implement` writes end-to-end tests for screen criteria when the project has them and runs the
  specs of the touched areas; `/verify` runs them too. New skill `test-data`.
- `project-rules/testing.md` template: test levels with the default stance (public interface, real
  database, doubles only for other systems), areas, end-to-end, test data.
- `harness/scripts/lint-ratchet.sh`: known lint findings per rule in `lint-baseline.txt`, counts may
  only fall. Rules marked `(geprüft: <check>)` are skipped by the reviewer agents.
- New review rule `doku`: a Markdown file with `sources:` globs whose sources changed while it did
  not. `lint-baseline.txt` and `.githooks/` are gate files.
- `update.sh` copies `.claude/skills/*/` and `.claude/agents/*.md` one by one and keeps the skills
  and agents of the project; `[remove]` in `owned-paths.txt` deletes dropped harness paths.
- `.githooks/pre-commit` runs `make precommit` when defined; `make setup` and `bootstrap.sh` set
  `core.hooksPath`. The guard hook denies `--no-verify` and `git commit -n`.
- `.gitattributes` (project-owned, `[diff-only]`): LF for text files.
- The settings template no longer denies edits of `harness/config.yml` and
  `harness/risk-matrix.yml`; both stay high risk, and the rule check in CI reads the config of the
  base branch (`review-rules.sh --config`).
- `/contract` adds the generator target and the config key in the same change when they are
  missing.

## 0.3.1 (2026-11-10)

Changes:

- `auto-merge.yml` deletes the head branch after a merge by `github-actions`; the repository
  setting "Automatically delete head branches" acts only on merges by a person.
- The guard hook denies `bootstrap.sh --github`, because it runs `setup-repo.sh`.
- Note on 0.3.0: its fix of `review-rules.sh` (a decision stands in for a spec id in the title of
  a harness PR) takes effect from the first PR after 0.3.0, because CI runs the rule script of the
  base branch.

## 0.3.0 (2026-11-10)

Fewer interruptions: two decisions per feature (spec approval, label), no review comments.
Decisions 0009, 0010, 0011.

Manual steps after `update.sh`:

- Run `harness/scripts/setup-repo.sh` from the update branch before its merge. The ruleset now
  requires `review-rules` and `ai-review` instead of `review-code`, and pins the Actions checks to
  the GitHub Actions app. Without the new ruleset the update PR waits for `review-code`, which no
  longer exists.
- Copy the Maven and Gradle entries of `dependency_manifests` into `harness/risk-matrix.yml` when
  the project uses them; `update.sh` shows them in the diff of the matrix.
- `AGENTS.md`: the line "Medium and high risk stop after the plan and wait for a person" becomes
  "The person approves the spec with its plan in the session. For medium and high risk the
  person's label on the pull request is the merge decision.", plus the line "After every push to a
  pull request branch, run the skill `review` for it." (`harness/templates/AGENTS.md`).
- Specs in `draft`: add the section `## Umsetzung` before the approval.

Changes:

- `/review` sets the commit status `ai-review` (`harness/scripts/review-status.sh`) and reports
  the findings in the session; no PR comments. Results are kept in `.git/ai-harness/review/`.
  Without a PR number it reviews the local branch before the push.
- `ai-review.yml` keeps one job for the rule check, `review-rules`, which also runs on PR body
  edits, and sets `ai-review` for Dependabot patch and minor updates. `check-review-comment.sh` is
  gone.
- `/spec` writes the implementation plan into the spec (`## Umsetzung`), asks the open questions
  together with the approval, and on approval commits the spec on the feature branch and
  continues with `implement`. G1 is approved with the spec.
- `implement` runs up to a reviewed pull request: gates, review and fixes before the push, PR with
  evidence per criterion, status, CI watch and fixes. It stops only when the change leaves the plan.
- `auto-merge.yml` enables auto-merge for medium and high risk when `human-gate` passes, so the
  label is the merge decision, and never on a branch without required status checks.
- `/verify` and `/risk` write into the PR body instead of comments.
- A PreToolUse hook (`.claude/hooks/guard-bash.sh`) guards Bash: merge, reviews, labels, rulesets,
  secrets, foreign commit statuses, force pushes, pushes to the default branch, `setup-repo.sh`,
  `update.sh` and shell writes to protected paths. The deny rule for `gh pr edit` is gone, so the
  agent writes PR title and body.
- Local gates skip a missing tool with `übersprungen`; CI still fails (`have` in `harness/gates.mk`).
- `bootstrap.sh`: `--source-paths`, `--github owner/name`, no `.DS_Store`. `setup-repo.sh` says
  when the plan lacks rulesets or auto-merge and exits 1.
- Risk matrix: Maven and Gradle files count as dependency manifests.

## 0.2.1 (2026-11-09)

Manual steps after `update.sh`:

- Copy the list `gate_markers` into `harness/risk-matrix.yml`; `update.sh` shows it in the diff of
  the matrix. Without it every pull request gets a blocking finding of the rule `gate`.
- Projects on 0.1: the update pull request runs without rule check and with `human-gate.sh` from
  the pull request, because the base branch has neither yet. Review it by hand before the label.

Changes:

- An approval counts for G2 only from a person with the permission write, maintain or admin
  (collaborators API). Since 0.2.0 approvals also have to be on the head commit and from an
  account of type `User`.
- `review-rules.sh` blocks when the list `gate_markers` is missing or empty.
- `/review` decides the combined agent run by the size of the diff it reviews, the delta for an
  incremental run.
- The rule check in CI takes its scripts only from the base branch and removes a `needs-human`
  label that CI set when no gate finding is left. Decision 0008.

## 0.2.0 (2026-11-09)

Manual steps after `update.sh`:

- Add `human_approval_label: human-approved`, `second_reviewer_for: ""`,
  `review_combined_max_lines: 150` and `review_rules_disabled:` to `harness/config.yml`; remove
  `reviewer_model`. Rerun `harness/scripts/setup-repo.sh`: it creates the label and removes the
  code-owner requirement from the ruleset.
- Apply the new `.github/workflows/auto-merge.yml` by hand when the project keeps it on the deny
  list. `human-gate` now runs `harness/scripts/human-gate.sh` from the base branch (decision 0006).
- Set `cooldown.default-days: 7` in `.github/dependabot.yml`. The semgrep rule
  `dependabot-missing-cooldown` treats smaller values as missing and fails `make sast`.

Changes:

- G2 by label or by an approval of the head commit, decision 0006.
- `/review` replaces `/review-code`, `/review-security` and `/review-architecture`: rule script,
  reviewer agents on Sonnet, incremental runs, decision 0007.
- New scripts `review-rules.sh` and `human-gate.sh`; `ai-review.yml` runs the rule check.
- The PR template has a section `Gate-Änderung`.

## 0.1.0 (2026-11-09)

First version. Workflow with gates G0–G3, risk policy with machine-readable matrix, ADR, human
approval and auto-merge policies, ten skills, three reviewer agents, two hooks, four workflows,
bootstrap, update and setup scripts. Review skills run in the session; CI checks their comments
and runs them itself only with a token secret (decision 0005).
