#!/usr/bin/env bash
# SessionStart hook. Prints the harness version, the specs that are not done and the open pull
# requests whose head has no status ai-review = success (decision 0022). The ruleset requires that status, and
# without a review token in CI only a session sets it for medium and high risk.
# stdout of a SessionStart hook becomes context for the session.
set -u
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
version=$(cat "$ROOT/HARNESS_VERSION" 2>/dev/null || echo unknown)
echo "AI harness $version. Read AGENTS.md. Workflow: harness/workflow.md (spec with plan approved in the session, implement up to a reviewed PR, the label of a person merges medium and high risk)."
if [ -x "$ROOT/harness/scripts/specs.sh" ]; then
  rows=$("$ROOT/harness/scripts/specs.sh" --open --dir "$ROOT/docs/specs" 2>/dev/null || true)
  if [ -n "$rows" ]; then
    echo "Specs not done (harness/scripts/specs.sh):"
    echo "$rows"
  fi
fi

unreviewed() {
  command -v gh >/dev/null 2>&1 || return 0
  git -C "$ROOT" remote get-url origin 2>/dev/null | grep -q 'github\.com' || return 0
  (cd "$ROOT" && gh pr list --state open --limit 50 --json number,isDraft,statusCheckRollup \
    --jq '.[] | select(.isDraft | not)
          | ([.statusCheckRollup[]? | select(.context == "ai-review") | .state] | first // "none") as $s
          | select($s != "SUCCESS")
          | "  #\(.number): ai-review \($s | ascii_downcase), /review \(.number)"')
}

out=$(mktemp 2>/dev/null) || exit 0
unreviewed > "$out" 2>/dev/null &
pid=$!
i=0
while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
if kill -0 "$pid" 2>/dev/null; then
  { kill "$pid"; wait "$pid"; } 2>/dev/null
elif [ -s "$out" ]; then
  echo "Open pull requests without ai-review = success; the merge waits for it:"
  cat "$out"
fi
rm -f "$out"
exit 0
