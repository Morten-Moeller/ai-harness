# 0001: Distribute the harness as a template repository, not as a Claude Code plugin

Status: accepted, 2026-11-09

## Context

The harness has to reach many projects. Claude Code offers plugins with marketplaces (central
updates, versioned), git submodules (central updates, awkward handling) and plain copying.

## Decision

The repository root is a template. `bootstrap.sh` copies it, `update.sh` refreshes the
harness-owned paths listed in `harness/owned-paths.txt`.

## Consequences

- Every project holds a full copy and works offline and without plugin installation.
- Drift is possible. `HARNESS_VERSION` and `update.sh` make it visible and fixable.
- A plugin cannot ship `permissions` rules; the template can, in `.claude/settings.json`.
- Switching to a plugin later is possible: skills, agents and hooks are already in plugin layout.
