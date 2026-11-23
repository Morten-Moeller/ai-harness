# 0021: Newest LTS lines for the stack, checked in the gate deps, and a daily security watch

Status: accepted, 2026-11-23. Adds to 0002.

## Context

The first real project (a coding challenge) was built on Java 21. A reviewer objected: Java 25 is
the LTS line since September 2025. No person chose Java 21. No rule of the harness named a version,
so the agent took the line from the knowledge of its model, which ends months before the session.

The gate `deps` scans the lock files for known vulnerabilities (OSV-Scanner). Three gaps:

- A runtime or a framework line stands in no lock file. A line without support, or a newer LTS
  line, was found by nothing.
- The gate runs on pull requests and on pushes to the default branch. A vulnerability published
  after the merge shows only with the next pull request.
- Dependabot knows only GitHub Actions until a person adds the ecosystems of the project.
  Dependabot alerts were not switched on by `setup-repo.sh`.

## Decision

- Policy `harness/policies/versions.md` (V1 to V5): a stack decision takes the newest LTS line, or
  the newest supported line of a product without LTS lines. The version comes from a lookup on the
  day, never from the memory of a model. An older line needs an ADR with the component that blocks
  the newest line, a source and the condition for the move.
- `stack` in `harness/config.yml` lists the release lines: `"<product> <line>"`, optionally
  `adr:<NNNN>`, with the names of endoflife.date.
- `harness/scripts/stack-check.sh` compares the list with the API of endoflife.date. `make deps`
  runs it after OSV-Scanner. Blocking: a line without support; a newer LTS line without ADR once it
  is LTS for more than `stack_lts_grace_days` (30); a line that is not LTS without ADR; a named ADR
  that does not exist; an empty list in a repository with a dependency manifest. The person chose
  the block for a newer LTS line and the 30 days (session of 2026-11-23).
- `stack-check.sh --latest <product>` is the lookup for `/roadmap`, `/adr` and `/spec`.
- `.github/workflows/security-watch.yml` runs `make deps` every day on the default branch when
  `security_watch: true`. The default is `false`: the person turns it on with the first production
  release. A finding fails the run, so GitHub sends its mail, and goes to Slack when the secret
  `SECURITY_WATCH_SLACK_WEBHOOK` is set.
- The skeleton spec of `/roadmap` fills `stack` and adds the package ecosystems of the project to
  `.github/dependabot.yml`. `setup-repo.sh` turns on Dependabot alerts and security updates.

Not chosen:

- A new gate `stack` with its own required check: every project would need the ruleset again.
  `deps` is required already and reads the network already.
- A block for a newer line of a product without LTS lines (Angular, PostgreSQL): such a product
  supports several lines for years; the newer line is a note.
- An issue per finding from the daily run: the person asked for Slack or mail, and for no daily
  run before production.
- A pass when endoflife.date does not answer: a gate that passes without data hides the finding.
- NVD or CPE matching of the stack list for vulnerabilities of the runtime itself: OSV has no
  uniform data for runtimes, and a runtime line with support gets its fixes as patch versions,
  which the setup action and the base image take.

## Consequences

- A project with a dependency manifest and no `stack` list fails `deps` after the update. Manual
  step in the changelog.
- On day 31 after a line becomes LTS every pull request of a project on the older line fails until
  the upgrade or the ADR merged. The note with the date of the block shows 30 days before.
- `deps` needs `jq` and an answer from endoflife.date. An outage of the site blocks pull requests
  until a new run.
- The daily run needs the toolchain of the setup action and Actions minutes. GitHub sends the mail
  for a failed scheduled run to the person who last changed the schedule of the workflow file, and
  stops scheduled runs of a repository without activity for 60 days.
- The mail and the Slack message carry the output of `make deps`: package names and advisory
  numbers. The webhook belongs to a channel that may read them.
