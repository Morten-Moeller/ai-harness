---
name: review-code
description: Review the code of a pull request for correctness, security, data loss, spec compliance and the hard constraints of AGENTS.md, using the built-in code-review skill or the code-reviewer agent, and write the result as a PR comment that starts with "Code-Review". Runs in CI as a required check and on explicit request (/review-code <PR>).
when_to_use: Load when the user runs /review-code, or when CI calls it with a PR number. Do not start it on your own.
argument-hint: <PR number>
disable-model-invocation: true
---

# Code review

The merge is never part of this skill. In CI the job that calls this skill fails when the comment
reports blocking findings.

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

## 4. Summary

PR, blocking and non-blocking counts, the comment URL. Do not repeat the findings in the chat
when the comment holds them.
