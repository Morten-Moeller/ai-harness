# 0009: The review result is a commit status, the findings stay in the session

Status: accepted, 2026-11-10. Changes 0005 and 0007.

## Context

`/review` wrote one PR comment per review and run. PR #4 and #5 collected 15 comments of 1,000 to
8,000 characters each, most of them "keine blockierenden Befunde", "Nicht geprüft" and repeated
tables. CI read the first line and the `Ergebnis:` line of these comments. Until the comment
existed, the job `review-code` was red, and `/review` had to rerun it.

## Decision

- `/review` sets the commit status `ai-review` on the head commit
  (`harness/scripts/review-status.sh`): `success` without blocking findings, `failure` with them.
  The description names the reviews and the counts. No PR comment.
- The findings go to the session chat. The result of each run is kept in
  `.git/ai-harness/review/<sha>.md`, local and untracked, for the next incremental run.
- `/review` without a PR number reviews the local branch before the push. After the push the
  head commit has a result already; only the status is set.
- The last reviewed commit is the newest commit of the PR with an `ai-review` status.
- `ai-review.yml` keeps one required job, `review-rules`: the rule check from the base branch.
  For Dependabot patch and minor updates it sets `ai-review` itself.
- The ruleset requires `ai-review` from any source and pins every Actions check to the GitHub
  Actions app (`integration_id` 15368). Before, a commit status with the name `human-gate` set
  through the API satisfied the check of the same name.

## Consequences

- No red check while the review is pending: a required status that is not set yet shows as
  expected, not as failed. No rerun.
- The PR keeps no record of the findings. The status description and the CI logs are the audit
  trail; the findings of a run are in the session and in `.git/ai-harness/`.
- A session can set `ai-review` without a review, as it could write the comment before. The human
  gate for medium and high risk stays the control.
