# 0020: A wave of specs implemented in parallel, one worktree per spec

Status: accepted, 2026-11-12.

## Context

The specs of one wave (0019) do not depend on each other, yet one session implements them one
after another. Claude Code starts subagents in parallel, each in its own git worktree
(`isolation: worktree`), and a subagent may start further agents, by default up to three levels
below the session, so it can run the reviewer agents itself. A subagent cannot ask the person:
`AskUserQuestion` is not available to it. Sources: code.claude.com/docs/en/sub-agents.md and
code.claude.com/docs/en/worktrees.md, read 2026-11-12.

Parallel work collides in three places:

- **Files.** Two branches change the same file; the second pull request needs a rebase. A rebase
  is a push, so review, `verify` and the label of the person start again (G2 counts after the last
  push). The ruleset does not require an up-to-date branch, so only a real conflict costs that.
- **Numbers.** Two migrations with the same version, two specs with the same number.
- **Runtime.** Two checkouts on one machine share ports, the database and the dev server. A test
  command with a fixed port (Quarkus tests use 8081 by default) fails when it runs twice at once.

## Decision

1. **Skill `wave`** (`/wave <NNNN> <NNNN> …`, or from `/roadmap`). The session that runs it is the
   orchestrator; it writes no code.
   - Checks: every spec is `approved`, on its branch from `/roadmap` or `/spec` or on the default
     branch; no spec of the call depends on another one that is not merged (column `Hängt ab von`
     in `docs/roadmap.md`);
     `harness/scripts/wave-check.sh` finds overlaps in the `Dateien:` lists: the same path, or two
     specs that each touch a path of the new list `wave_exclusive` in `harness/risk-matrix.yml`
     (dependency manifests, `contracts/**`, migrations, the generated files of the project). At
     most `parallel_max` specs run (`harness/config.yml`, default 3).
   - A spec that overlaps another or exceeds the limit waits for the next `/wave`; the plan the
     skill prints names it and the reason.
   - Switches its own checkout to the default branch, because a branch can be checked out in only
     one worktree. Then starts one agent `implementer` per spec (`.claude/agents/implementer.md`,
     `isolation: worktree`), all in one message, in the background.
   - A worker that returns with a question: the orchestrator collects the questions of all
     workers, asks the person in one `AskUserQuestion` call, and resumes each worker with its
     answer (`SendMessage`).
   - At the end one table: per spec the PR, the risk, the review result, `verified` and what is
     open; then the next step (the label for medium and high risk).
   - At its start it removes the worktrees of merged branches (`git worktree remove`).
2. **Worker.** The agent runs the skill `implement` in worker mode:
   - It switches to the branch of its spec (local branches are shared by all worktrees), or
     creates it from `origin/<default_branch>`, then runs the command `worktree_setup`
     (`harness/config.yml`, default `make setup`; the project adds its dependency install).
   - Where `implement` stops and asks, the worker returns the question with its state (branch,
     commits, worktree) and waits to be resumed. It never guesses.
   - Everything else is unchanged: gates, review with the reviewer agents, push, pull request,
     status `ai-review`, CI, `verify`. The summary goes back to the orchestrator.
3. **Runtime.**
   - New rule T3.6 in `harness/testing.md`: the test command takes free ports and its own data;
     two runs in two checkouts on one machine at the same time pass. Fixed ports belong to the
     started application. A project that cannot follow it records an ADR and sets
     `parallel_max: 1`.
   - `harness/scripts/app-lock.sh acquire|release|status --owner <branch> [--wait <seconds>]`: one
     lock per repository under the git common directory, so every worktree sees it. `verify` takes
     it from starting the application to stopping it, `implement` for its end-to-end step. A lock
     older than 60 minutes counts as stale.
4. `.claude/worktrees/` goes into `.gitignore`.

Not chosen: the orchestrator runs review, pull request, CI and `verify` for every branch; its
context would hold every diff, and nested agents make it unnecessary. Several terminal sessions
with `claude --worktree`; that stays possible by hand, but every session asks on its own and
nothing checks overlaps. A waiting spec that starts by itself once a conflicting one merges; the
merge waits for the label, so the wave would wait for the person. A port offset per worktree; it
depends on the stack, the lock does not.

## Consequences

- A wave of three specs gives three pull requests at about the same time. Each needs the person's
  review and label; G2 and G3 do not change.
- The subscription usage grows with the number of workers; `parallel_max` limits it.
- `verify` of the workers runs one after another because of the lock.
- A file outside the plan can still collide; then the second pull request needs a rebase, a new
  review, `verify` and the label.
- Projects with a fixed test port change it (T3.6) before their first parallel wave.
