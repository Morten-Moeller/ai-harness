# ai-harness

A template repository for software projects that are built together with AI agents. It fixes the
workflow (spec, implementation, verification), the human gates, the risk assessment, the review
skills, the quality gates and the policies. Projects copy it once and refresh the harness-owned
parts with a script.

Start here: [`harness/README.md`](harness/README.md).

## Create a project from it

```bash
git clone https://github.com/Morten-Moeller/ai-harness.git
ai-harness/harness/scripts/bootstrap.sh /path/to/new-project --name new-project
```

Or use "Use this template" on GitHub and run `harness/scripts/bootstrap.sh --in-place --name
new-project` inside the new checkout.

## Layout

| Path | Purpose |
|---|---|
| `harness/` | workflow, quality gates, policies, risk matrix, config, scripts, this repository's own decisions |
| `.claude/` | skills, agents, hooks and permissions for Claude Code |
| `.github/` | quality-gate, risk, AI-review and auto-merge workflows |
| `docs/`, `contracts/`, `project-rules/`, `src/` | project context, templates only in this repository |
| `harness/templates/` | files that differ between this repository and a project (`Makefile`, `AGENTS.md`, `README.md`, setup action) |

## Developing the harness

This repository runs its own gates: `make check` lints the shell scripts, the workflows and the
Markdown, validates the JSON and runs the script tests. Decisions about the harness itself are in
`harness/decisions/`. Changes that need a manual step in projects go into `harness/CHANGELOG.md`.

Language: instructions in simplified technical English, outputs for people in the language of
`harness/config.yml`.
