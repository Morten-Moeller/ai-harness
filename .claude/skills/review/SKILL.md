---
name: review
description: Review a pull request in one run - deterministic rule check (harness/scripts/review-rules.sh), then the AI reviews its risk level needs (code always, security from medium, architecture for high risk or contract changes) by read-only reviewer agents, incremental against the last reviewed commit and as one combined agent run for small diffs, then one PR comment per review. Only on explicit request (/review <PR> [code] [security] [architecture] [--force] [--no-rerun]).
when_to_use: Load when the user runs /review or asks for the reviews of a pull request, or when CI runs it with a PR number. Do not start it on your own.
argument-hint: <PR number> [code] [security] [architecture] [--force] [--no-rerun]
disable-model-invocation: true
---

# Review

Rules, cost model and states: `harness/review.md`. The merge is never part of this skill.

This session collects data, decides which reviews run, starts the agents and posts the comments.
It does not review code itself. The agents read and return findings; they start without this
conversation and on the model of their agent file.

Work directory: `<scratchpad>/review-<PR>-<first 7 characters of the head SHA>/`.

## 1. Collect

1. `gh pr view <n> --json title,body,author,headRefOid,baseRefName,files,comments,commits`.
2. `git fetch -q origin <base> "pull/<n>/head"`.
3. `files.txt`: the paths. `diff.patch`: `gh pr diff <n>`.
4. Dependabot author: the update type is the line `update-type:` in the message body of the first
   commit. Pass it to `risk-level.sh` as `--dependabot <type>`.
5. `harness/scripts/risk-level.sh --files-from files.txt --diff-from diff.patch --format json`:
   fields `level` and `lines`.
6. `harness/scripts/review-rules.sh --pr <n> --format markdown > rules.md`. Exit 1 means blocking
   rule findings; continue.
7. Spec: `docs/specs/NNNN-*.md` from `(NNNN)` in the title or a path in the body. In the harness
   repository (`harness/templates/` exists) a `harness/decisions/NNNN-*.md` of the PR takes its
   place.

## 2. Plan

| Review | Needed when | Agent | Comment prefix |
|---|---|---|---|
| code | always | `code-reviewer` | `Code-Review` |
| security | level medium or high | `security-reviewer` | `Security-Review` |
| architecture | level high, or a file under `contracts/` or `docs/architecture/` | `architecture-reviewer` | `Architektur-Review` |

Type arguments (`code`, `security`, `architecture`) restrict the run to those reviews.

State of each review, from its newest comment. The first line of a comment names the reviewed
commit (`Commit <sha>`).

| Case | State |
|---|---|
| `--force`, or no comment | `voll` |
| comment names the head commit | `vorhanden` |
| comment names an ancestor of the head (`git merge-base --is-ancestor <old> <head>`) | from the delta, below |
| anything else (rebase, force push) | `voll` |

Delta: `git diff --name-only <old> <head>`, only the paths that are also in `files.txt`, into
`delta-<type>.txt`.

- No path left: `übernommen`.
- `risk-level.sh --files-from delta-<type>.txt --format level` prints `low`: `übernommen`.
- Otherwise: `inkrementell`. Write `git diff <old> <head> -- <delta paths>` to
  `delta-<type>.patch` and the old comment body to `prev-<type>.md`.

Print the table (review, state, reason). No review in state `voll` or `inkrementell`: go to
step 4.

## 3. Agents

**Combined run**: two or more reviews in state `voll` or `inkrementell`, and the reviewed diff has
at most `review_combined_max_lines` changed lines (`harness/config.yml`). The reviewed diff is
`diff.patch` for `voll` and `delta-<type>.patch` for `inkrementell`; count the lines that start
with `+` or `-`, without the `+++` and `---` headers, and take the largest of the reviews that run. One Agent call with subagent type
`code-reviewer` covers all of them, one section per review.

**Separate runs** otherwise: one Agent call per review, all in the same message.

Prompt, filled in and nothing more:

```text
Review PR #<n>, head <sha>, risk <level>.
Mode: <voll | inkrementell seit <old sha>>.
Diff: <diff.patch | delta-<type>.patch>. Changed files: <files.txt>.
Spec: <path | keine>.
Rule check: <rules.md>. Its items are checked; do not report them again.
[inkrementell] Previous comment: <prev-<type>.md>. Mark each previous finding behoben or offen.
[combined] Sections: <Code | Sicherheit | Architektur>. Sicherheit follows
.claude/agents/security-reviewer.md, Architektur follows .claude/agents/architecture-reviewer.md.
Return per section the table of the agent file and one line "Nicht geprüft: ...".
```

Wait for every agent.

## 4. Comments

One comment per review in state `voll`, `inkrementell` or `übernommen`:
`gh pr comment <n> --body-file <file>`. Language: `doc_language` in `harness/config.yml`. CI reads
the first line and the `Ergebnis:` line; keep their form.

```text
<Prefix> <YYYY-MM-DD>, Commit <head sha>

Ergebnis: <keine blockierenden Befunde | n blockierende Befunde>

[inkrementell] Inkrementell seit Commit <old sha>.

| Früherer Befund | Status |
|---|---|

[Code-Review only] <content of rules.md>

| Datei:Zeile | Kategorie | Befund | Blockiert |
|---|---|---|---|

[Security-Review] Checkliste: <line from the agent>
[Architektur-Review] ADR: <line from the agent>

Nicht geprüft: <line from the agent>
```

The count in `Ergebnis:` is the blocking findings of the agent, plus the previous blocking findings
that are `offen`, plus, in the Code-Review, the blocking findings of `rules.md`.

State `übernommen`, no agent:

```text
<Prefix> <YYYY-MM-DD>, Commit <head sha>

Ergebnis: <count>

Übernommen von Commit <old sha>. Seit dem geändert: <delta paths | keine Datei dieses PR>, Risiko
dieser Änderung low.
```

For the Code-Review the count is the blocking rows of the agent table in the old comment plus the
blocking findings of the current `rules.md`, and the current `rules.md` goes into the comment. For
the other reviews the `Ergebnis:` line of the old comment stays as it is.

## 5. CI

Without `--no-rerun`: `gh run list --workflow ai-review.yml --commit <head sha> --json databaseId
--jq '.[0].databaseId'`, then `gh run rerun <id> --failed`. No run yet: nothing to do.

## 6. Summary

A table: review, state, blocking and non-blocking counts, comment URL. Whether CI was rerun. The
next step for the person: the label `human-approved` after their own review (medium, high), or
nothing (low). The findings are in the comments; do not repeat them.
