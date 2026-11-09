---
name: spec
description: Write the spec for one change into docs/specs/NNNN-<slug>.md from the template, with testable acceptance criteria, a risk proposal and the ADR check, and add its row to docs/specs/README.md. Only on explicit request (/spec <topic>).
when_to_use: Load when the user runs /spec or names a change that has no spec yet and wants one written. Do not start it on your own.
argument-hint: <topic or one sentence>
disable-model-invocation: true
---

# Spec

Stage 1 of `harness/workflow.md`. Output: one spec file with status `draft` and one row in the
status table. The approval (`status: approved`) is set by a person, never by this skill.

## 1. Read

- `harness/workflow.md` (stage 1), `harness/policies/risk.md`, `harness/policies/adr.md`.
- `docs/domain/glossary.md`, `docs/architecture/overview.md`, the `project-rules/*.md` of the areas
  the change touches.
- `docs/specs/README.md` and existing specs that share words with the topic (`grep -ril`). A spec
  that already covers the topic: report it and stop.
- `doc_language` in `harness/config.yml`. The document is written in that language; the template
  headings are German and are translated when the language differs.

## 2. Ask

Before writing, ask the person with `AskUserQuestion`, at most five questions in one call:
who the change is for and what they can do afterwards, what is out of scope, which screens or
endpoints change, which contracts or other systems are touched, which constraints hold (deadline,
compatibility, data). Skip a question when the argument answers it. Unanswered questions go to
`## Offene Fragen`; the skill does not guess.

## 3. Write

1. Number: the highest `NNNN` in `docs/specs/` plus one, `0001` when there is none. Slug: lower
   case ASCII, hyphens, at most 40 characters. Path `docs/specs/NNNN-<slug>.md`.
2. Copy `docs/specs/0000-template.md` and fill every section. Frontmatter `id`, `title`,
   `status: draft`, `risk`, `adrs: []`, `owner` (the person from the question or `TBD`), `created`
   (today).
3. Acceptance criteria: `A1..An`, each one checkable by a test, a call or a screen. A criterion
   that names a screen, a button or a text is checked in the browser by `/verify`; say which. No
   criterion of the form "works correctly".
4. Terms: use the glossary as written. A term that is missing goes to `## Begriffe` with a
   definition and a note "neu, mit /domain ins Glossar".
5. Risk: list the paths the implementation will touch, write them to a temp file in the scratchpad
   and run `harness/scripts/risk-level.sh --files-from <file> --format text`. Write the level,
   the reasons and the gates that apply (`harness/policies/human-approval.md`) into `## Risiko`.
6. ADR: walk the list in `harness/policies/adr.md`. Write `ADR nötig: ja, <reason>` or
   `nein, weil <reason>`. Do not write the ADR here; that is `/adr`.
7. Verification plan: `make check`, the test files or areas that the criteria map to
   (`project-rules/testing.md`), the screens for the browser walk or `keiner`.

## 4. Row

Append to the table in `docs/specs/README.md`:
`| NNNN | <title> | <risk> | draft | – | <today> | <open questions count or –> |`.

## 5. Finish

Do not commit. The person reads the spec, answers the open questions, and commits it with
`status: approved` in the frontmatter and the row.

Summary to the user: path, risk level, whether an ADR is required, the open questions, and the
sentence that G0 (approval) is theirs. No other text.
