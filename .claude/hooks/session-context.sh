#!/usr/bin/env bash
# SessionStart hook. Prints the harness version, the specs that are not done, the state of the
# switch human_gate_for (decision 0023), the open pull requests whose head has no status
# ai-review = success (decision 0022) and the open issues "Prüfen: ..." that verify opened for a
# check by a person (decision 0023). Only numbers come from GitHub, no titles.
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

gate_for=$(awk '$1 == "human_gate_for:" { v=$2; gsub(/"/, "", v); print "=" v; exit }' "$ROOT/harness/config.yml" 2>/dev/null)
case "$gate_for" in
  "=") echo "human_gate_for: \"\". Risk medium and high merge without the label once verify passed; the label needs-human puts the label back (decision 0023)." ;;
  "=high") echo "human_gate_for: high. Risk medium merges without the label once verify passed; the label needs-human puts the label back (decision 0023)." ;;
esac

github() {
  command -v gh >/dev/null 2>&1 || return 0
  git -C "$ROOT" remote get-url origin 2>/dev/null | grep -q 'github\.com' || return 0
  (cd "$ROOT" && gh pr list --state open --limit 50 --json number,isDraft,statusCheckRollup \
    --jq '.[] | select(.isDraft | not)
          | {n: .number, s: ([.statusCheckRollup[]? | select(.context == "ai-review") | .state] | first // "none")}
          | select(.s != "SUCCESS")
          | "pr\t  #\(.n): ai-review \(.s | ascii_downcase), /review \(.n)"')
  (cd "$ROOT" && gh issue list --state open --limit 50 --search 'in:title Prüfen' --json number,title \
    --jq '.[] | select(.title | startswith("Prüfen:")) | "issue\t  #\(.number)"')
}

out=$(mktemp 2>/dev/null) || exit 0
github > "$out" 2>/dev/null &
pid=$!
i=0
while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
if kill -0 "$pid" 2>/dev/null; then
  { kill "$pid"; wait "$pid"; } 2>/dev/null
else
  if grep -q '^pr	' "$out"; then
    echo "Open pull requests without ai-review = success; the merge waits for it:"
    sed -n 's/^pr	//p' "$out"
  fi
  if grep -q '^issue	' "$out"; then
    echo "Open issues for a check by a person (criteria that verify could not check):"
    sed -n 's/^issue	//p' "$out"
  fi
fi
rm -f "$out"
exit 0
