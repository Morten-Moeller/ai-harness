---
name: review-code
description: Review the code of a pull request for correctness, security, data loss, spec compliance and the hard constraints of AGENTS.md, using the built-in code-review skill or the code-reviewer agent, and write the result as a PR comment that starts with "Code-Review". Run in the session on explicit request (/review-code <PR>); CI checks the comment as a required check and runs the skill itself only when a token secret is set.
when_to_use: Load when the user runs /review-code, or when CI calls it with a PR number. Do not start it on your own.
argument-hint: <PR number>
disable-model-invocation: true
---

# Code review

The merge is never part of this skill. The CI job `review-code` fails when the comment for the
head commit is missing or reports blocking findings.

## 1. Resolve

1. `gh pr view <n> --json title,body,headRefOid,headRefName,baseRefName,files,comments`.
   `gh pr diff <n>` into a scratchpad file.
2. A comment that starts with `Code-Review` and names the same `headRefOid`: this state is
   reviewed. Report and stop.
3. The spec id from the title `(NNNN)` or body. Read the spec's acceptance criteria when it
   exists. No spec on a non-trivial change: that is a finding (category `process`, blocking for
   medium and high risk).

## 2. Review

- The skill `code-review` is available: invoke it with args `<n> high`.
- Otherwise: run the agent `code-reviewer` with the diff path, the spec path, `AGENTS.md` and the
  `project-rules/*.md` of the touched areas, and take its findings.

Add these checks in every case:

- every acceptance criterion has code and a test or a named `/verify` check
- no comments in code, glossary terms used, no anthropomorphic names
- no weakened check, test, gate or ignore file
- no generated file edited by hand (`contracts/README.md`)

Blocking categories: `correctness`, `security`, `data-loss`, `process` (criterion not covered,
gate weakened, generated file edited). Non-blocking: `simplification`, `efficiency`,
`test-coverage`, `style`, `docs`.

Only verified findings. A finding has a file and line, a failure scenario (input and state that
produce the wrong result) and a category. Guesses are left out.

## 3. Comment

`gh pr comment <n> --body-file <file>`. Language: `doc_language` in `harness/config.yml`.

```text
Code-Review <YYYY-MM-DD>, Commit <head SHA>

Ergebnis: <keine blockierenden Befunde | n blockierende Befunde>

| Datei:Zeile | Kategorie | Befund | Blockiert |
|---|---|---|---|
| ... | ... | ... | ja/nein |

Nicht geprüft: <was außerhalb des Diffs lag oder nicht verifizierbar war, oder "nichts">
```

The first line and the `Ergebnis:` line are read by CI. Keep their form exactly.

## 4. CI check

The job `review-code` in `ai-review.yml` checks for this comment. When the PR already had a run for
this commit, rerun its failed jobs so the check turns green:
`gh run list --workflow ai-review.yml --commit <head SHA> --json databaseId --jq '.[0].databaseId'`,
then `gh run rerun <id> --failed`. No run yet: nothing to do; the next run finds the comment.

## 5. Summary

PR, blocking and non-blocking counts, the comment URL, whether the CI run was rerun. Do not
repeat the findings in the chat when the comment holds them.
