---
name: review
description: Run every AI review a pull request needs by its risk level - review-code always, review-security from medium, review-architecture for high risk or contract changes - as parallel forked skills, skip the reviews whose comment for the head commit already exists, then rerun the failed CI jobs once. Only on explicit request (/review <PR> [--force]).
when_to_use: Load when the user runs /review or asks for the reviews of a pull request. Do not start it on your own.
argument-hint: <PR number> [--force]
disable-model-invocation: true
---

# Review (all required reviews)

One trigger for the three review skills. Each review is tied to a commit: a comment whose first
line names the head SHA counts as done. `--force` runs every required review again.

## 1. Resolve

1. `gh pr view <n> --json headRefOid,baseRefName,files,comments,labels`. Write the file paths to
   a scratchpad file and `gh pr diff <n>` to another.
2. Level: `harness/scripts/risk-level.sh --files-from <paths> --diff-from <diff> --format level`.
   Author `dependabot[bot]`: pass `--dependabot <update-type>` from the PR title.
3. Architecture flag: any file under `contracts/` or `docs/architecture/`.

## 2. Plan the set

| Review | Needed when | Comment prefix |
|---|---|---|
| `review-code` | always | `Code-Review` |
| `review-security` | level is medium or high | `Security-Review` |
| `review-architecture` | level is high, or the architecture flag is set | `Architektur-Review` |

For each needed review: a comment that starts with the prefix and contains the head SHA exists
and `--force` is not given: `vorhanden`. Otherwise: `läuft`. Not needed: `nicht nötig`.

Print the table (review, status, reason) before running anything. Nothing to run and CI already
green: report and stop. Nothing to run and a review check red: go to step 4.

## 3. Run

Invoke the Skill tool once per review marked `läuft`, all in the same message so they run in
parallel: `review-code` with args `<n> --no-rerun`, `review-security` with args `<n> --no-rerun`,
`review-architecture` with args `<n> --no-rerun`. They run as forked subagents and write their
own comments. Do not review yourself and do not repeat a review that is running. Wait for every
result.

## 4. CI

After every started review has finished, rerun the failed jobs of the AI-review run once:
`gh run list --workflow ai-review.yml --commit <head SHA> --json databaseId --jq '.[0].databaseId'`
and `gh run rerun <id> --failed`. No run for this commit: nothing to do.

## 5. Summary

Per review: `vorhanden`, `gelaufen` with the blocking and non-blocking counts from its result and
the comment URL, or `nicht nötig`. Whether CI was rerun. What the person does next: set the label
`human-approved` (medium, high) or wait for auto-merge (low). Do not repeat the findings; the
comments hold them.
