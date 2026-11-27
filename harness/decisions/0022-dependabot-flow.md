# 0022: Dependabot pull requests that merge, and a tested default branch

Status: accepted, 2026-11-24. Adds to 0003, 0010 and 0021.

## Context

The first project with Dependabot for npm and Maven (harness 0.8.0) got five Dependabot pull
requests in one day: one GitHub Actions patch, two groups of minor and patch updates and two major
updates. The person set the label `human-approved` on all five. None merged. A session found four
gaps.

1. **Groups never reach low risk.** `risk-level.sh` raises low to medium above
   `low_risk_max_lines` (200). A group of minor and patch updates changes the lock file: 390 and
   706 lines in the two groups. CI sets `ai-review` for Dependabot only at level low
   (`ai-review.yml`), so the rule "patch and minor updates merge automatically" held for no group.
2. **From medium a session is needed.** A major update, an Actions update (the workflow file is
   high) and every group need the status `ai-review` from a session, because the project has no
   review token in CI. The label did not show this: `human-gate` passed, the pull requests stayed
   open, and nothing named the missing status as the reason.
3. **The default branch is not tested after a merge.** `quality-gates.yml` runs on a push to
   `main`, but the merge of an auto-merge that `GITHUB_TOKEN` enabled starts no workflow. The
   ruleset does not require a branch to be up to date. Four pull requests merged one after the
   other, each tested alone; the session ran `make check` on the result by hand.
4. **A file against `.gitattributes` blocks every checkout.** Dependabot wrote `mvnw.cmd` with
   CRLF into the repository; `.gitattributes` asks for LF in the repository. After the merge git
   showed the file as modified in every checkout, and `pull`, `rebase` and `stash` failed until a
   pull request with `git add --renormalize` merged.

Two more findings need no change of the harness: an update of a lint tool or a formatter can need
a change of the code (the session added the commit to the Dependabot branch), and Maven 3.10
waits for a file of each repository (fixed in the project with `.mvn/maven.config`).

## Decision

The person chose one option per gap in the session of 2026-11-24.

1. **No size escalator for a Dependabot patch or minor update that changes only manifests and
   lock files.** `risk-level.sh` already computes both facts (`--dependabot`, `manifests_only`).
   The gates `deps`, `sast`, `test`, `lint`, `typecheck` and `e2e` check such a pull request; the
   number of lock file lines says nothing about its risk. Major updates stay medium.
2. **The session start names the pull requests that wait for a review.** The session start hook
   prints the open pull requests whose head has no status `ai-review`, with the command
   (`/review <n>`). The message of `human-gate` names a missing `ai-review` or `verified` status
   when the label is set. No rule changes; the wait becomes visible.
3. **The hourly workflow starts the gates for the head of the default branch when that commit
   has no run.** `quality-gates.yml` gets the trigger `workflow_dispatch`; `branch-cleanup.yml`
   (hourly, exists) starts it with `gh workflow run` (a dispatch by `GITHUB_TOKEN` starts a
   workflow, a push does not). A failed run sends the mail of GitHub and, when the secret of 0021
   is set, the Slack message. A broken combination shows within the hour; the change does not
   prevent it.
4. **A deterministic review rule `zeilenende`.** `review-rules.sh` reports each changed text file
   whose content in the head has CRLF although `.gitattributes` sets LF for the repository
   (`git ls-files --eol`: `i/crlf` with attribute `text`). Blocking, with the fix in the message
   (`git add --renormalize <file>`). CI runs the rule in `review-rules`, so a Dependabot pull
   request fails before the merge.

Not chosen:

- Lock files outside the size escalator for every pull request: wider than the gap; it also
  covers changes of a person to the manifests.
- The review in CI with `CLAUDE_CODE_OAUTH_TOKEN` as the answer to gap 2: stays an option of the
  project; it costs tokens per push and needs the secret per project.
- The label alone merges a Dependabot major update: that removes the AI review for the updates
  with the highest risk.
- An up-to-date branch as a ruleset requirement (`strict_required_status_checks_policy`): it
  prevents the broken combination, but each merge makes every other open pull request stale, and
  a branch update by `GITHUB_TOKEN` starts no gates, so a person or a session updates each branch.
- Documentation only for gaps 2 and 4.

Not verified: with the secret `AUTOMERGE_TOKEN` (a token of a person) the merge may count as a
push of that person and start the gates on its own. The first project has no such secret.

## Consequences

- 1: groups of minor and patch updates merge without a person when the gates pass. A project
  that asks for a person on every dependency update sets `dependency_manifests` paths to medium
  in its matrix; the option stays.
- 2: the session start hook calls the GitHub API (one request for the open pull requests, one
  per head); without network it prints nothing.
- 3: Actions minutes for one more run per merged pull request at most; none when the head of the
  default branch has a run.
- 4: a new rule that can block a pull request in a project that has such files today. The
  changelog names the check (`git ls-files --eol | grep 'i/crlf.*attr/text'`) as a manual step
  before the update.
- Version 0.9.0; `update.sh` brings the scripts and workflows; no ruleset change.
