---
name: wave
description: Implement several approved specs at the same time - check that their plans do not overlap (harness/scripts/wave-check.sh), start one implementer agent per spec in its own git worktree, relay the questions of the workers to the person, resume them with the answers and report one table with pull request, risk, review and verification per spec. The session writes no code itself.
when_to_use: Load when the user runs /wave with several spec numbers, or when the skill roadmap continues after "Freigeben und Welle umsetzen" with more than one spec or with wave_continue true. Not for one spec without wave_continue; that is implement.
argument-hint: <NNNN> <NNNN> ...
---

# Wave

Decision 0020. This session orchestrates: each spec is implemented by an `implementer` agent
(`.claude/agents/implementer.md`) in its own worktree, with the skill `implement` in worker mode,
up to a reviewed and verified pull request. The merge is never part of this skill; with
`wave_continue: true` the skill waits for it and starts the next wave (decision 0023).

## 1. Clean up

`git worktree list --porcelain`. For each worktree under `.claude/worktrees/` whose branch has a
merged pull request (`gh pr list --head <branch> --state merged --json number`):
`git worktree remove <path>`, then `git branch -D <branch>`. A worktree that git refuses to
remove (changes, untracked files) stays; name it in the summary.

## 2. Check

1. Each argument is one spec: `docs/specs/<NNNN>-*.md` on the default branch, or on a local branch
   `<type>/<NNNN>-<slug>` (`git branch --list '*/<NNNN>-*'`, read with `git show <branch>:<path>`).
   Its `status` must be `approved`. Anything else: report and stop.
2. Dependencies: the column `Hängt ab von` of `docs/roadmap.md` (from the branch of the first spec
   while the roadmap is not on the default branch). A spec waits when it depends on a spec of this
   call or on one that is not `done` on the default branch.
3. Plans: each spec into a scratchpad file, then `harness/scripts/wave-check.sh <files>`.
   - `overlap`, `exclusive`: the spec with the higher number waits.
   - `unchecked`, `no-paths`: that spec waits; its plan needs full paths under `Dateien:`.
4. At most `parallel_max` specs run (`harness/config.yml`, 3 when the key is missing); the others
   wait.
5. Print the plan: the specs that run, the specs that wait with the reason, and the command
   `worktree_setup` (`harness/config.yml`) that every worker runs in its worktree. None runs:
   stop.

## 3. Start

1. `git status --porcelain` shows no tracked changes, otherwise stop and report. Then
   `git switch <default_branch>`: a branch can be checked out in only one worktree.
2. One Agent call per running spec, all in one message: `subagent_type: implementer`,
   `isolation: worktree`, `run_in_background: true`, description `implement <NNNN>`, prompt:

```text
Spec <NNNN>, branch <type>/<NNNN>-<slug>, default branch <default_branch>.
Run the skill implement with "<NNNN> --worker".
```

## 4. Questions and results

Each worker ends with one report (format in `.claude/agents/implementer.md`).

- `Frage`: ask the person with `AskUserQuestion` as soon as it arrives. Questions that arrive
  together go into one call, at most four; each names its spec. Resume the worker with
  `SendMessage`: the answer, the person, the date.
- `Fertig`: note the PR, the risk, the review result, `verified` and what is open.
- `Abbruch`: note the reason and the output.

Wait for every worker. This session writes no code and runs no gate; a change goes to the worker
with `SendMessage`.

## 5. Summary

In `doc_language`:

```text
| Spec | PR | Risiko | Review | verified | Offen |
```

Then the open points of the reports (blocking findings, criteria not met or not testable, gates
skipped, failing checks with output), the issues `Prüfen: …` that `verify` opened, the specs that
wait with the reason, the worktrees that stay, and the next step: low risk and the levels that
`human_gate_for` exempts merge after the required checks; the other levels wait for the person's
review and the label `human-approved` after the last push; `/wave` for the waiting specs once
their conflicts are merged.

`wave_continue` in `harness/config.yml` is not `true`: stop here.

## 6. Continue

Only with `wave_continue: true`.

1. For each pull request of the wave: `gh pr checks <n> --watch` in the background, then
   `gh pr view <n> --json state,autoMergeRequest` until `state` is `MERGED`, at most 15 minutes
   after the checks finished (Monitor with an until-loop, no sleep in the foreground).
2. A pull request that is not merged then stops the loop: a failed check, `human-gate` waiting for
   the label (the level is not exempt, or `needs-human` is set), a conflict, auto-merge not
   enabled. Name the pull request and the reason. The other pull requests of the wave still merge;
   wait for them, then stop.
3. All merged: `git fetch -q origin`, `git switch <default_branch>`, `git pull --ff-only`, step 1
   (clean up), then the waiting specs of this call, and then the next wave of `docs/roadmap.md`:
   the lowest wave with a spec that is not `done`.
   - Its specs are `approved` (on the default branch or on their local branches): run this skill
     again with their numbers, from step 2.
   - Its specs are missing or `draft`: run the skill `roadmap` with `next`. Its approval question
     is G0 and G1 of the wave; with `Freigeben und Welle umsetzen` it starts this skill again.
4. The loop ends with the last wave of the roadmap, a question of a worker that the person leaves
   open, an answer `Nur freigeben` or `Ändern` to the approval, or a stop of 2. Print the summary
   of step 5 for every wave, and the open issues `Prüfen: …`
   (`gh issue list --state open --search "in:title Prüfen:"`).
