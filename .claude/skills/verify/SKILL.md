---
name: verify
description: Verify a pull request against the acceptance criteria of its spec - run make check and the affected tests, walk the application when a criterion names a screen, write the result table into the PR body and set the spec row to fertig or in Arbeit. Only on explicit request (/verify <PR>).
when_to_use: Load when the user runs /verify, or names a PR in status Review and asks for the check against the spec. Do not start it on your own.
argument-hint: <PR number | spec id>
disable-model-invocation: true
---

# Verify

Stage 3 of `harness/workflow.md`. The merge is never part of this skill. `fertig` means: every
criterion met, ready for the merge decision.

## 1. Resolve and gate

1. Argument is a PR number or a spec id. From a PR: `gh pr view <n> --json title,headRefName,
   headRefOid,baseRefName,body,files`; the spec id is in the title `(NNNN)` or the body.
   From a spec id: the `PR` column of the row. No PR: report and stop.
2. Read the spec: acceptance criteria, verification plan. Read `project-rules/testing.md` for how
   affected tests are selected and how the browser checks run.
3. The PR body has a line `Geprüft: <date>, Commit <sha>` that names the same `headRefOid`: this
   state is verified. Report and stop.
4. Row status must be `Review` or `in Arbeit`. Otherwise report and stop.

## 2. Scope

Write the scope down before testing:

| Changed files | Automated | Browser |
|---|---|---|
| only docs, tests, config | `make check` | no |
| source paths (`harness/config.yml`) | `make check`, the unit, integration and end-to-end tests of the touched areas (`project-rules/testing.md`) | yes, for every criterion that names a screen, button or text and has no end-to-end test |
| `contracts/` | `make check`, contract validation, consumers' tests | as above |

No criterion names a screen: the body says `Kein Browser-Test: <Grund>`.

## 3. Check out

1. `git status --porcelain` must show no tracked changes. Otherwise stop and report.
2. Note the current branch. `git fetch origin`, `git checkout <headRefName>`,
   `git merge-base --is-ancestor origin/<base> HEAD`. Behind the base: note it in the body, do
   not rebase.
3. The project's services, when the criteria need them: start or ask as `project-rules/testing.md`
   says. Ask the person with `AskUserQuestion` when a service runs outside this session.

## 4. Automated checks

Run `make check` and the tests of the touched areas, end-to-end included. Test data with the steps
of `.claude/skills/test-data/SKILL.md`. Keep the output of every failing check. Never weaken a
check or a test to make it pass. A gate that prints `übersprungen` did not run; the line
`Automatisch` names it, and the CI result of that gate counts.

## 5. Browser walk

Only when the scope says yes and a browser tool is available in this session (the Chrome skill or
the project's Playwright setup named in `project-rules/testing.md`). None available: every screen
criterion is `nicht prüfbar: kein Browser in dieser Session`.

Walk every criterion that names a screen. Screenshot before and after each action into the
scratchpad. Record per criterion `erfüllt`, `nicht erfüllt` (what was seen instead),
`nicht prüfbar` (why).

## 6. PR body

Replace the section `## Akzeptanzkriterien` of the PR body (`gh pr view <n> --json body`) and
write it back with `gh pr edit <n> --body-file <file>`. No PR comment. Language: `doc_language`.

```text
## Akzeptanzkriterien

Geprüft: <YYYY-MM-DD>, Commit <head SHA>, Branch hinter <base>: <ja/nein>
Automatisch: make check <grün | FEHLER: Gate>; Tests <Auswahl>: <grün | FEHLER: ...>
Browser: <Umfang | Kein Browser-Test: Grund>

| Kriterium | Nachweis | Ergebnis |
|---|---|---|
| A1 | Test `<pfad>` / Browser: was zu sehen war | erfüllt / nicht erfüllt / nicht prüfbar |
```

The output of a failing check goes to the chat, not into the body.

## 7. Row

- Every check green and no criterion `nicht erfüllt`: `Status` = `fertig`. Otherwise `in Arbeit`.
- `Stand` = today. `Notiz` = criteria `nicht prüfbar` or the failing check, one line.
- Commit only `docs/specs/README.md` on the PR branch: `docs(specs): <NNNN> <fertig|in Arbeit>
  nach Test`, with the attribution line from the session. Push.

`nicht prüfbar` alone does not block `fertig`. Name it in the summary so the person decides.

## 8. Summary

PR, row status, failing checks with output, criteria not met or not testable, the branch checked
out before. The working tree stays on the PR branch. Do not report passing checks.
