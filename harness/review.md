# Review

`/review <PR>` is the one trigger for every review a pull request needs. A script checks what
needs no judgement. Reviewer agents check the rest, and only what is new since the last review.

```text
/review <PR>
  1. collect        PR data, diff, risk level, spec
  2. rule check     harness/scripts/review-rules.sh            no model, seconds
  3. plan           which reviews, which state per review
  4. agents         code-reviewer, security-reviewer, architecture-reviewer
  5. comments       one per review, first line names the commit
  6. CI             rerun the failed jobs of ai-review.yml once
```

## Rule check

`harness/scripts/review-rules.sh` runs in `/review` and again in CI (job `review-code`, copy of the
script from the base branch). Its findings go into the Code-Review comment. A blocking rule finding
fails `review-code` even when the comment says otherwise.

| Rule | Checks | Blocking |
|---|---|---|
| `spec` | the PR names a spec, `(NNNN)` in the title or `docs/specs/NNNN-*.md` in the body, and its status is not `draft` | missing spec from medium risk; spec in `draft` always |
| `adr` | a high-risk PR links an ADR: body, changed files or `adrs:` of the spec | yes |
| `entscheidung` | an accepted ADR or decision changes only in its `Status:` line | yes |
| `gate` | added lines that switch off a check (`.skip(`, `@ts-ignore`, `nolint`, `continue-on-error: true`, ...), changed gate files (`Makefile`, `*.mk`, ignore files, linter configs) | switched-off check without a line `Gate-Änderung: <Grund>` in the PR body |
| `kommentar` | comment lines added in code under `source_paths` (AGENTS.md) | no |
| `generiert` | changed files with a generated-file header | no |
| `kriterium` | every acceptance criterion of the spec has a row with evidence in the PR body | yes |
| `contract` | a change under `contracts/` is named in the `## Contracts` section of the spec | yes |

The patterns for switched-off checks are the list `gate_markers` in `harness/risk-matrix.yml`.
`risk-level.sh` reads the same list and raises a low-risk PR with such a line to medium, so it
never merges automatically (`harness/policies/auto-merge.md`). CI also sets the label
`needs-human` on any `gate` finding and removes it again when a later run finds none and the label
was set by CI. A `needs-human` set by a person stays.

The scripts read the matrix and the config each with their own few lines of awk. They stay
self-contained on purpose: CI copies single scripts from the base branch into a temporary
directory, where a shared helper file would be missing (decision 0008).

Dependabot PRs skip `spec` and `adr`. A project switches a rule off in `harness/config.yml`
(`review_rules_disabled`).

In the harness repository itself a decision record in `harness/decisions/` takes the place of the
spec and of the ADR: the repository has no `docs/specs/` of its own, because `docs/` is the project
template.

## Which reviews

| Review | Needed when | Agent |
|---|---|---|
| code | always | `code-reviewer` |
| security | risk medium or high | `security-reviewer` |
| architecture | risk high, or a file under `contracts/` or `docs/architecture/` | `architecture-reviewer` |

## State per review

The newest comment of a review names the commit it reviewed.

| State | When | Cost |
|---|---|---|
| `vorhanden` | the comment names the head commit | none |
| `übernommen` | the PR files changed since then are none, or only low-risk files | none, a short comment |
| `inkrementell` | the reviewed commit is an ancestor of the head | an agent on the delta diff, with the previous findings |
| `voll` | first review, rebase or force push, or `--force` | an agent on the whole diff |

## Cost control

- The agents start without the conversation of the session and read only the diff and what it
  touches.
- Model and effort are set in `.claude/agents/*.md` (default: Sonnet, effort medium). Raise them
  there for a project that needs it.
- When the diff under review has at most `review_combined_max_lines` changed lines
  (`harness/config.yml`), one agent run covers all reviews. For an incremental run that is the
  delta, not the whole PR.
- Secrets and vulnerable dependencies are left to the gates `sast` and `deps`.
- The built-in `/code-review` and `/security-review` skills are not part of `/review`. Run them by
  hand on a PR that needs a deeper look.

## CI without a session

With the secret `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` each job of `ai-review.yml` runs
`/review <PR> <type> --no-rerun` before its check.
