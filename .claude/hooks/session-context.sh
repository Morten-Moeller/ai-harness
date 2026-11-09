#!/usr/bin/env bash
# SessionStart hook. Prints the harness version and the specs that are not done.
# stdout of a SessionStart hook becomes context for the session.
set -u
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
version=$(cat "$ROOT/HARNESS_VERSION" 2>/dev/null || echo unknown)
echo "AI harness $version. Read AGENTS.md. Workflow: harness/workflow.md (spec first, risk level, gates; a person merges medium and high risk)."
if [ -f "$ROOT/docs/specs/README.md" ]; then
  rows=$(grep -E '^\| [0-9]{4} ' "$ROOT/docs/specs/README.md" 2>/dev/null | grep -v '| done |' || true)
  if [ -n "$rows" ]; then
    echo "Specs not done (docs/specs/README.md):"
    echo "$rows"
  fi
fi
exit 0
