#!/usr/bin/env bash
# Decides whether one quality gate runs in CI for a change (decision 0024). quality-gates.yml calls
# it in the step "Gate active"; on a pull request the copy from the base branch runs, with the
# matrix and the config of the base branch, so a pull request cannot change the rule it is judged by.
#
# Usage:
#   gate-scope.sh --gate <test|typecheck|lint|sast|deps|drift|e2e> [--event <event>]
#                 [--files-from <file>] [--matrix <file>] [--config <file>] [--pr-config <file>]
#                 [--since <sha> --head <sha> [--checks-json <file>] [--repo <owner/name>]]
#                 [--root <dir>]
#
# Prints "run" or "skip: <reason>" and exits 0. Exit 2: usage error.
#
# Rules, in this order:
#   drift  runs only with contracts_generate_target, e2e only with e2e_in_ci: true, in --config or
#          in --pr-config (the config of the pull request may switch a gate on, never off).
#   lint and sast always run.
#   An event other than pull_request (a push to the default branch, workflow_dispatch) runs every
#   gate.
#   A pull request whose files are all documents (docs/**, *.md) skips test, typecheck and deps.
#   deps runs only when a file is a dependency manifest (dependency_manifests of the matrix),
#   harness/config.yml, osv-scanner.toml, or a file that defines the gates (see GATE_FILES).
#   --since: a push whose commits since <sha> change only documents takes over the result of the
#   check "gates (<gate>)" on <sha> when it is success and <sha> is an ancestor of --head. The
#   result comes from --checks-json (a check-runs response of the GitHub API) or from the API.
set -euo pipefail

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GATE=""
EVENT="pull_request"
FILES_FROM=""
MATRIX=""
CONFIG=""
PR_CONFIG=""
SINCE=""
HEAD_SHA=""
CHECKS_JSON=""
REPO=""

value() {
  [ $# -ge 2 ] && [ -n "$2" ] && [[ "$2" != --* ]] || { echo "$1 needs a value" >&2; exit 2; }
}
while [ $# -gt 0 ]; do
  case "$1" in
    --gate) value "$@"; GATE="$2"; shift 2 ;;
    --event) value "$@"; EVENT="$2"; shift 2 ;;
    --files-from) value "$@"; FILES_FROM="$2"; shift 2 ;;
    --matrix) value "$@"; MATRIX="$2"; shift 2 ;;
    --config) value "$@"; CONFIG="$2"; shift 2 ;;
    --pr-config) value "$@"; PR_CONFIG="$2"; shift 2 ;;
    --since) value "$@"; SINCE="$2"; shift 2 ;;
    --head) value "$@"; HEAD_SHA="$2"; shift 2 ;;
    --checks-json) value "$@"; CHECKS_JSON="$2"; shift 2 ;;
    --repo) value "$@"; REPO="$2"; shift 2 ;;
    --root) value "$@"; ROOT=$(cd "$2" && pwd); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$GATE" in test|typecheck|lint|sast|deps|drift|e2e) ;; *) echo "--gate must be one of test typecheck lint sast deps drift e2e" >&2; exit 2 ;; esac
MATRIX=${MATRIX:-$ROOT/harness/risk-matrix.yml}
CONFIG=${CONFIG:-$ROOT/harness/config.yml}
if [ -n "$SINCE" ]; then
  [[ "$SINCE" =~ ^[0-9a-f]{40}$ ]] || { echo "--since must be a full commit SHA" >&2; exit 2; }
  [[ "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]] || { echo "--since needs --head with a full commit SHA" >&2; exit 2; }
fi

GATE_FILES='^(Makefile|.*\.mk|harness/config\.yml|harness/risk-matrix\.yml|harness/scripts/(gate-scope|stack-check|drift)\.sh|osv-scanner\.toml|.*/osv-scanner\.toml|\.github/workflows/.*|\.github/actions/.*)$'

run() { echo "run"; exit 0; }
skip() { echo "skip: $1"; exit 0; }

cfg_value() {
  [ -n "$1" ] && [ -f "$1" ] || return 0
  awk -v key="$2:" '$1 == key { v=$2; gsub(/"/, "", v); print v; exit }' "$1"
}
either() { local a b; a=$(cfg_value "$CONFIG" "$1"); b=$(cfg_value "$PR_CONFIG" "$1"); printf '%s\n%s\n' "$a" "$b"; }

case "$GATE" in
  drift)
    either contracts_generate_target | grep -q . || skip "contracts_generate_target is empty: no generated files to compare."
    ;;
  e2e)
    either e2e_in_ci | grep -qx true || skip "e2e_in_ci is not true: the end-to-end tests run locally (project-rules/testing.md)."
    ;;
esac

case "$GATE" in lint|sast) run ;; esac
[ "$EVENT" = pull_request ] || run
[ -n "$FILES_FROM" ] || run

FILES=$(mktemp)
trap 'rm -f "$FILES"' EXIT
grep -v '^[[:space:]]*$' "$FILES_FROM" > "$FILES" || true
[ -s "$FILES" ] || run

is_doc() { case "$1" in docs/*|*.md) return 0 ;; *) return 1 ;; esac; }

glob_to_regex() {
  awk -v g="$1" 'BEGIN {
    n = length(g); out = "^"
    for (i = 1; i <= n; i++) {
      c = substr(g, i, 1)
      if (c == "*") {
        if (substr(g, i + 1, 1) == "*") {
          if (substr(g, i + 2, 1) == "/") { out = out "(.*/)?"; i += 2 } else { out = out ".*"; i += 1 }
        } else { out = out "[^/]*" }
      } else if (c == "?") { out = out "[^/]" }
      else if (index(".()+^$|{}[]\\", c) > 0) { out = out "\\" c }
      else { out = out c }
    }
    print out "$"
  }'
}
manifest_res() {
  [ -f "$MATRIX" ] || return 0
  awk -v q="'" '
    /^[A-Za-z_]+:/ { cur=$1; sub(/:$/, "", cur); next }
    cur == "dependency_manifests" && /^[ \t]*-[ \t]*/ {
      s=$0; sub(/^[ \t]*-[ \t]*/, "", s); sub(/[ \t]+$/, "", s)
      f = substr(s, 1, 1); l = substr(s, length(s), 1)
      if (length(s) > 1 && f == l && (f == "\"" || f == q)) s = substr(s, 2, length(s) - 2)
      if (s != "") print s
    }
  ' "$MATRIX" | while IFS= read -r g; do glob_to_regex "$g"; done
}

docs_only=1
gate_file=0
manifest=0
res=$(manifest_res)
while IFS= read -r f; do
  is_doc "$f" || docs_only=0
  if [[ "$f" =~ $GATE_FILES ]]; then gate_file=1; fi
  while IFS= read -r re; do
    [ -n "$re" ] || continue
    if [[ "$f" =~ $re ]]; then manifest=1; break; fi
  done <<EOF
$res
EOF
done < "$FILES"

if [ "$docs_only" = 1 ]; then
  skip "the pull request changes only documents (docs/**, *.md)."
fi
if [ "$GATE" = deps ] && [ "$manifest" = 0 ] && [ "$gate_file" = 0 ]; then
  skip "no dependency manifest, harness/config.yml or osv-scanner.toml changed; the run on the default branch scans the dependencies."
fi
[ -n "$SINCE" ] || run

git -C "$ROOT" merge-base --is-ancestor "$SINCE" "$HEAD_SHA" 2>/dev/null || run
git -C "$ROOT" diff --name-only "$SINCE" "$HEAD_SHA" > "$FILES" 2>/dev/null || run
[ -s "$FILES" ] || run
while IFS= read -r f; do is_doc "$f" || run; done < "$FILES"

if [ -n "$CHECKS_JSON" ]; then
  checks=$(cat "$CHECKS_JSON" 2>/dev/null || true)
else
  command -v gh >/dev/null 2>&1 || run
  repo=${REPO:-${GITHUB_REPOSITORY:-}}
  [ -n "$repo" ] || run
  checks=$(gh api "repos/$repo/commits/$SINCE/check-runs?per_page=100" 2>/dev/null || true)
fi
conclusion=$(printf '%s' "$checks" | jq -r --arg n "gates ($GATE)" '
  [.check_runs[]? | select(.name == $n and .status == "completed")] | sort_by(.completed_at) | last | .conclusion // ""
' 2>/dev/null || true)
[ "$conclusion" = success ] || run
skip "the commits since ${SINCE:0:7} change only documents; gates ($GATE) passed on ${SINCE:0:7}."
