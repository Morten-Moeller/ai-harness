# Policy: versions of the stack

The stack is every runtime, language, framework, database and base image of the project. This
policy fixes which release line a decision takes and how the project finds a line that aged
(decision 0021).

## Rules

- **V1 Newest LTS line.** A stack decision takes the newest release line with long-term support
  (LTS). A product without LTS lines takes the newest line with support. A line that is not LTS,
  while the product has LTS lines, is an older line in the sense of V3.
- **V2 Versions come from a lookup, not from memory.** The knowledge of a model ends months before
  the session. Before a version goes into a roadmap, an ADR, a spec or a manifest, run
  `harness/scripts/stack-check.sh --latest <product>` (product names of
  <https://endoflife.date>). A product that the site does not list: the release page of the vendor.
  The ADR names the line, the date of the lookup and the source.
- **V3 An older line needs a reason.** The ADR of the decision names the component that does not
  support the newest LTS line, with a source (release notes, compatibility matrix, an open issue),
  and the condition under which the project moves to it. "Tried and tested" or "the template uses
  it" is no reason. The entry in `stack` gets `adr:<NNNN>`.
- **V4 The stack is listed.** `stack` in `harness/config.yml` has one entry per release line:
  `"<product> <line>"`. The change that adds or moves a runtime, framework, database or base image
  changes the list in the same pull request, and the same line stands in the files the tools read
  (toolchain file, manifest, `.github/actions/setup/action.yml`, Dockerfile).
- **V5 A line without support has no exception.** The upgrade is the only way; an ADR does not
  lift the block.

## Enforcement

- `make deps` runs `harness/scripts/stack-check.sh` after the dependency scan. It fails for a line
  without support, for a newer LTS line that is LTS for more than `stack_lts_grace_days`
  (`harness/config.yml`, default 30) and has no ADR, for a line that is not LTS without ADR, for an
  ADR that `docs/adr/` does not have, and for an empty list in a repository with a dependency
  manifest. Inside the grace period the newer line is a note with the date of the block.
- A product without LTS lines: a newer line is a note, never a block. Support that ends within 90
  days is a note.
- `/roadmap` and `/adr` run the lookup of V2. The architecture review reports a version change
  without the list entry, and an older line without the reason of V3, as blocking.
- A newer LTS line is handled like any change: a spec for the upgrade, or an ADR by V3.
- After the first production release set `security_watch: true` in `harness/config.yml`: the
  workflow `security-watch.yml` then runs `make deps` every day on the default branch, so a new
  vulnerability or an aged line is found without a pull request (`harness/quality-gates.md`).

## Limits

- The check reads <https://endoflife.date>. Without an answer from the site the gate fails; start
  the run again. A product the site does not list cannot stand in `stack`; name it with its line
  and the lookup in `project-rules/`.
- The check compares release lines. Patch and minor versions inside a line are the work of
  Dependabot and of the dependency scan.
