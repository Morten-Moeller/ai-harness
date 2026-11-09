# Policy: what may be merged automatically

Automatic merge means: `auto-merge.yml` enables GitHub auto-merge on the pull request, and GitHub
merges it as soon as every required check is green. No agent runs `gh pr merge`.

## All conditions must hold

1. **Risk level low**, computed by `harness/scripts/risk-level.sh` inside the auto-merge job. The
   `risk:*` label is not trusted; the job recomputes.
2. **Author on the allowlist** in `harness/config.yml` (`auto_merge.allowlist`), or the change is
   documentation only (every file matches a `low` pattern under `docs/` or `*.md`).
3. **Dependabot** PRs: update type `version-update:semver-patch` or `version-update:semver-minor`
   from `dependabot/fetch-metadata`, and no file outside the manifests and lock files.
4. **No label `needs-human`** on the PR, and the PR is not a draft. CI sets `needs-human` when
   the rule check finds a changed gate.
5. **Every required check green**: `gates (test|typecheck|lint|sast|deps)`, `risk`, `review-code`,
   `human-gate`. GitHub enforces this part; the job only enables auto-merge.
6. **`review-code` without blocking findings.** The job runs the rule check
   (`harness/scripts/review-rules.sh`) and reads the `Code-Review` comment for the head commit. It
   fails on blocking rule findings, on a missing comment and on blocking findings in the comment,
   so this is part of condition 5. The review runs in a Claude Code session (`/review <PR>`) or,
   with a token secret, in CI.

## Never automatically

- Medium or high risk.
- Any file in `contracts/`, `.github/workflows/`, `harness/`, `AGENTS.md`, `CLAUDE.md`.
- A PR whose base is not the default branch.
- A PR that changes a gate (Makefile targets, ignore files, coverage floors).

## Merge method

Squash merge. The PR title becomes the commit subject, so the title follows
`<type>(<scope>): <summary>` and names the spec id. The branch is deleted after the merge
(`setup-repo.sh` sets `--delete-branch-on-merge`).

## Audit

Every automatic merge is traceable: the `risk` job summary shows the matched patterns, the
`review-code` comment shows the review, the `auto-merge` job log shows the conditions it checked.
A person reads the merged PRs of the week; `/wochenbericht`-style reports can list them.

## Turning it off

Remove `enable-auto-merge` from the `jobs` of `auto-merge.yml` or set `auto_merge.enabled: false`
in `harness/config.yml`. The `human-gate` check keeps working.
