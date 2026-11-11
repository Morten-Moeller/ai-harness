# 0014: Project rules become checks; documents name their sources

Status: accepted, 2026-11-11.

## Context

`project-rules/*.md` is prose. The reviewer agents check it, and the answer depends on the model
and the run: the same rule is reported in one review and missed in the next. The person found such
findings of little help. The monorepo mentioned in 0012 and 0013 turns its conventions into linter
rules with their own tests (no comments, layering, no interfaces in the feature code) and a
ratchet: a baseline file holds the known findings per rule, and the lint step fails when a count
rises. It also marks documents with the source paths they describe and asks for a check when a
source changes.

## Decision

- Policy in `project-rules/README.md`: a rule that a review reports twice becomes a check in the
  gates. A rule enforced by a check is marked `(geprüft: <check>)`; the reviewer agents skip it.
- `harness/scripts/lint-ratchet.sh`: compares counts per rule from stdin with `lint-baseline.txt`.
  A higher count fails, a lower one asks for `--update`, which only lowers. The baseline is a gate
  file for the rule check (`gate`), so a raise needs a reason and a person.
- A new rule `doku` in `review-rules.sh`: a Markdown file with `sources:` globs in its front matter
  is reported, non-blocking, when a pull request changes a source and not the file. The project
  rule templates carry `sources: []`.

## Consequences

- Reviews get shorter over time: each recurring finding moves into a check that runs in seconds.
- A new linter rule can go live on old code at once; the ratchet stops new findings while old ones
  are cleaned up.
- `doku` findings are hints only. A document without `sources:` is never reported.
