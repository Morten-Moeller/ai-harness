# 0023: The human gate G2 per risk level, and waves that run one after the other

Status: accepted, 2026-11-26. Changes 0006 and 0010. Adds to 0018 and 0020.

## Context

G2 is fixed: every pull request of level medium or high waits for the label `human-approved` of a
person (0006, 0010). `verify_required_for` and `second_reviewer_for` are keys of
`harness/config.yml`; G2 has no key.

For a test project the person reads no pull request. The label is then one click per pull request
without a review behind it, and each click stops the work: `implement` and `wave` end at the pull
request, and the next wave starts only when a person merged the last one and ran `/wave` again.

The person asked on 2026-11-26 for a switch: without G2 the specs of a roadmap are implemented one
after the other and tested, and no pull request waits for a person.

## Decision

### 1. Key `human_gate_for`

`harness/config.yml` gets `human_gate_for`, with the same values as `verify_required_for`:

| Value | G2 (label or approval) applies to |
|---|---|
| `medium` (default, also when the key is missing) | medium and high, as today |
| `high` | high |
| `""` | no level |

Any other value fails the gate. A level to which G2 does not apply is called exempt below.

### 2. An exempt level needs the status `verified`

The person chose this on 2026-11-26. For an exempt level `human-gate.sh` requires the commit
status `verified` = `success` on the head, whatever `verify_required_for` says. The machine
evidence replaces the person: the required gates, `review-rules`, `ai-review` and `verified`.
Pull requests by bots stay exempt from G3, as in 0018.

A commit status starts no workflow, so `human-gate` does not run again when `verify` sets
`verified`. `verify` reruns the failed jobs of the newest run of `auto-merge.yml` for the head
(`gh run rerun <id> --failed`) after it set `success`. This also helps the levels with G2: a label
set before `verified` no longer needs a second label event.

### 3. `needs-human` puts G2 back on one pull request

For an exempt level `human-gate.sh` falls back to G2 as today (label after the last push, or an
approval) when the pull request has the label `needs-human`. `ai-review.yml` sets it when the job
`review-rules` finds a changed gate or a switched-off test; a person can set it on any pull
request. The message names the
reason.

The key applies to every author (the person chose this on 2026-11-26): `auto_merge_allowlist`
plays no part for medium and high, as today. `auto-merge.yml` stays as it is: it enables
auto-merge for medium and high when `human-gate` passed. The whole rule is in `human-gate.sh`,
which runs from the base branch.

`second_reviewer_for` is checked before `human_gate_for`: a level that needs a second reviewer is
never exempt.

### 4. `wave` continues after the merge

New key `wave_continue` (`true` or `false`, default `false`). With `true`, `wave` and `implement`
(started by `roadmap` or `wave`) do not end at the pull request:

1. After the reports of the workers: `gh pr checks <n> --watch` per pull request, then the state of
   the pull request until it is `MERGED`.
2. A pull request that is not merged when its checks are done (a failed check, `human-gate`
   waiting for the label, a conflict) stops the loop. The summary names the pull request and the
   reason. The other pull requests of the wave still merge.
3. All merged: `git fetch`, clean up the worktrees (step 1 of `wave`), then the next wave of
   `docs/roadmap.md`.
   - Its specs are `approved`: start them.
   - Its specs are missing or `draft`: run step 4 of `roadmap` (write the specs of the next wave)
     and put the approval question. G0 and G1 stay one answer per wave.
4. The loop ends with the last wave, a question of a worker without an answer, or a stop of
   step 2.

`parallel_max: 1` runs the specs strictly one after the other.

`wave_continue: true` with `human_gate_for: medium` is allowed: the loop then stops at the first
medium or high pull request and names the label as the reason.

### 5. A criterion that is `nicht prüfbar` merges and becomes a task for a person

The person chose this on 2026-11-26. A criterion that `verify` cannot check (no browser in the
session, a service outside the session) does not block: `verified` is `success` when no criterion
is `nicht erfüllt`, as today. For a pull request of an exempt level `verify` then creates one
GitHub issue before it sets the status:

- title `Prüfen: <spec title> (<NNNN>, #<n>)`, assigned to the account of the session
  (`--assignee @me`), no label (agents set no labels);
- body in `doc_language`: the link to the spec and the pull request, and per criterion the
  number, the text, the reason it was not checked and the steps for the check by hand (screen,
  test data state, expected result).

An issue with that pull request number in the title exists already (a second run of `verify`):
`verify` adds a comment with the new list and creates no second issue. The line `Geprüft:` of the
PR body names the issue.

The person checks after the merge and closes the issue. A criterion that fails becomes its own
change: `/spec` with type `fix`, one per finding, with the issue number in the spec. Nothing is
reverted automatically.

The session start hook prints the open issues whose title starts with `Prüfen:` (one request),
and the summary of `wave` lists the issues of its pull requests.

With G2 on, nothing changes: the person reads the criteria table before the label, and no issue
is created.

### 6. Texts

`harness/policies/human-approval.md` (table, G2, "Always a person"),
`harness/policies/auto-merge.md`, `harness/workflow.md`, the summaries of `implement` and `wave`
and the comment in `auto-merge.yml` name the key. The line "Setting the label `human-approved` on
a medium or high risk PR" under "Always a person" gets "for the levels in `human_gate_for`".

The session start hook prints one line when `human_gate_for` is not `medium`, so the state of the
switch is visible in every session.

Not chosen:

- One key `profile: test | production` that sets several keys: the config is flat on purpose, and
  each key has its own reason (0021 `security_watch`, 0018 `verify_required_for`).
- `human_approval_label: ""` as the switch: it means "approval by another person only" today.
- A criterion `nicht prüfbar` blocks the merge of an exempt level: every screen criterion would
  stop the loop in a session without a browser.
- The task as a file in the repository or as a line in the spec: it would need its own pull
  request to close, and nothing shows it outside the repository.
- Exempt levels without `verified`: then only CI and the AI review stand between an agent and the
  default branch, and no step checks the criteria of the spec.
- `needs-human` without effect when G2 is off: a pull request that switches off a test would merge
  without any person. That contradicts the hard constraint "never weaken a check".
- One approval for all waves of a roadmap: the specs of a later wave are written from the merged
  result of the earlier one (0019).
- The session merges the pull requests itself: agents never merge (AGENTS.md).

## Consequences

- The switch is a decision of a person: `harness/config.yml` is a high risk path, agents cannot
  edit it in a project, and `auto-merge.yml` reads the copy of the base branch. A pull request
  cannot switch off the gate it is judged by. The pull request that changes the key is itself
  high risk and needs the label under the old value.
- With `human_gate_for: ""` code of level high (migrations, authentication, workflows,
  infrastructure) merges without a person. The policy names this as a setting for test projects
  and for nothing with production data.
- `verify` now gates the merge for exempt levels. Code with a criterion that no one checked
  reaches the default branch; the open issue is the only record of it. Later waves build on that
  code, so a fix can touch more than the first change.
- The repository needs issues turned on. `verify` reports a failed `gh issue create` and does not
  set `verified`.
- A session that runs a whole roadmap stays open for hours and waits on CI. A closed session ends
  the loop; `/wave` with the next numbers continues it.
- Tests: `harness/scripts/tests/` gets cases for `human-gate.sh` (each value of the key,
  `needs-human` with and without the label of a person, a bot, the missing key, an unknown value,
  the order with `second_reviewer_for`).
- A pull request by a bot of an exempt level needs neither a person nor `verified`: the gates,
  `review-rules` and `ai-review` are its checks. With `human_gate_for: ""` this includes a
  Dependabot major update and an update of a GitHub Actions workflow (high).
- Version 0.10.0, after 0022 (both change `human-gate.sh`). `update.sh` brings scripts, skills and
  workflows. Manual step: the two new keys in `harness/config.yml`; without them nothing changes.
  No ruleset change.

## Open questions

- [x] Does an exempt level force the status `verified`? → Yes (Morten Möller, 2026-11-26)
- [x] Does the key apply to every author, or does G2 stay for authors outside
  `auto_merge_allowlist`? → Every author (Morten Möller, 2026-11-26)
- [x] Does a criterion `nicht prüfbar` block the merge of an exempt level? → No. It merges, and
  a task for a person is created; fixes follow as single changes (Morten Möller, 2026-11-26)
