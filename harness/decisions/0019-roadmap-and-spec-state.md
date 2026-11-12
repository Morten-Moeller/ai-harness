# 0019: Roadmap in waves, a decisions block in the plan, spec state in the front matter

Status: accepted, 2026-11-12. Changes 0010 (spec skill, plan in the spec).

## Context

Every change starts with `/spec` for one topic. For a new project the person breaks the goal down
alone; nothing records the whole picture, the order of the specs or which of them may run at the
same time.

The plan in `## Umsetzung` is written for the agent. In the second test project the plan of 0007
is about 40 lines of files, field types and locking details. A person who reads it reviews code
before the code exists. The three fixes 0007 needed came from the behaviour in the browser, which
no plan review finds. What does need the person is lost in the list: a new dependency
(`@angular/cdk`), a changed API (`PATCH` replaced `setDone`).

Every spec writes its row in the status table of `docs/specs/README.md`, and answered questions
are appended to its `Entscheidungen` table. Two branches that change neighbouring rows or append
a row conflict in git. With one change at a time this never showed; with parallel branches (0020)
it hits every pull request. `/spec` numbers by the highest file in `docs/specs/`, so a spec that
lives on an unmerged branch is invisible to a second session.

## Decision

1. **Skill `roadmap`** (`/roadmap <goal>`, only on request):
   - Asks about the goal, the users, what is out of scope, quality targets and constraints, with
     `AskUserQuestion`, several rounds when needed.
   - Writes `docs/roadmap.md` from `.claude/skills/roadmap/template.md`: goal, users, non-goals,
     quality targets, basic decisions with links to ADRs, and one table row per spec: number,
     title, wave, depends on, areas (directories, contracts, manifests), proposed risk. No status
     column.
   - Basic decisions (stack, persistence, authentication, hosting) become ADRs with status
     `proposed`.
   - Wave 1 of a new project holds one spec: the skeleton (structure, build, gates, one path from
     the screen to the database). A later wave holds specs that do not depend on each other and
     touch separate areas (0020).
   - Writes the specs of the next wave in full, with the steps of `/spec`. Later waves stay one
     row in the roadmap; their specs are written when their wave is next, from the code that
     exists then.
   - One approval question: `Freigeben und Welle umsetzen`, `Nur freigeben`, `Ändern`. The answer
     approves the roadmap, accepts its ADRs and is gate G0 for each spec of the wave.
   - On approval each spec of the wave gets its branch `<type>/<NNNN>-<slug>` from
     `origin/<default_branch>` with the commit `docs(specs): <NNNN> freigegeben`, as with `/spec`.
     The roadmap, the ADRs of this run and the ADR index go on the branch of the first spec, and
     that spec lists them under `Dateien:`; a spec that needs one of these ADRs depends on the first
     one. The branches stay local until `implement` pushes them, so nothing waits for a merge
     before the wave starts. The specs reach the default branch with their code, as today.
   - `Freigeben und Welle umsetzen` continues with `implement` for one spec and with `wave` (0020)
     for several.
   - On an existing roadmap the skill writes the specs of the next wave, or changes the roadmap. A
     change of the roadmap without a spec is a pull request of its own (`docs/roadmap-<date>`).
2. **Decisions block.** `## Umsetzung` starts with `Entscheidungen:`, at most five lines or
   `keine`: new dependencies, contract and API changes, data model and migrations, new modules or
   services, deviations from a rule (ADR). `/spec` and `/roadmap` print it in the approval summary;
   the file list stays for the agent. `implement` stops and asks when it needs a decision of these
   kinds that the block does not name. Paths under `Dateien:` are full paths from the repository
   root, because `wave-check.sh` (0020) reads them.
3. **Spec state in the front matter only:** `status`, `pr`, `updated`, `note`. The status table and
   the `Entscheidungen` table leave `docs/specs/README.md`; it keeps the explanation. An answered
   question stays in its spec: `- [x] <Frage> → <Antwort> (<Wer>, <Datum>)`.
   `harness/scripts/specs.sh [--open]` prints the overview from the front matter, `make specs`
   runs it, and the SessionStart hook prints the specs that are not done with it.
4. **Numbers.** `/spec` and `/roadmap` take the highest number of `docs/specs/NNNN-*`, the spec
   table of `docs/roadmap.md` and the branch names `<type>/<NNNN>-<slug>`, local and on `origin`
   (`git ls-remote --heads origin`), plus one.
5. `docs/specs/0000-template.md` moves to `[diff-only]` in `harness/owned-paths.txt`, so
   `update.sh` shows a project the new template lines.

Not chosen: a separate stop for the plan (the old G1); the decisions block is the part the person
reads. All specs of all waves at once; plans of later waves name files that do not exist yet. A
generated overview file under version control; every pull request would change it, the same
conflict as the table. One pull request with the roadmap and every spec of the wave, merged before
the wave starts: a few specs pass the 200 lines of `low_risk_max_lines`, so it would need the
label, one more stop per wave.

## Consequences

- One stop for the goal and the first wave instead of one per spec.
- The spec overview is no longer a table on GitHub; `make specs` and the session start show it.
- Projects migrate once (CHANGELOG): the columns `PR`, `Stand` and `Notiz` of each row go into the
  front matter of its spec, the rows of `Entscheidungen` into their specs, then both tables go.
  Until then `specs.sh` shows `–` for a missing `pr`.
