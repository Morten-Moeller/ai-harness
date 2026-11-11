# 0016: A scheduled workflow deletes the head branch after a merge by a bot

Status: accepted, 2026-11-11.

## Context

Harness 0.3.1 added a job `delete-branch` to `auto-merge.yml`, triggered by `closed`. The first
live merge through it (PR #8, merged by `github-actions`) showed that it never runs: an event caused
by `GITHUB_TOKEN` starts no workflow, and the merge of GitHub auto-merge, enabled with
`GITHUB_TOKEN`, is such an event. The repository setting "Automatically delete head branches" was
on and did not delete the branch either.

## Decision

- `.github/workflows/branch-cleanup.yml` runs every hour and on request. It deletes the head
  branch of each pull request merged by a bot in the last seven days, when the branch still points
  to the merged head commit. Never the default branch, never a branch of a fork.
- The job `delete-branch` and the `closed` trigger leave `auto-merge.yml`.

## Consequences

- A merged branch stays up to an hour. A push to it after the merge keeps it.
- Merges by a person still use the repository setting.
