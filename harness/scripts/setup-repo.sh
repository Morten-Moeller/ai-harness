#!/usr/bin/env bash
# Configures the GitHub repository for the harness: labels, auto-merge, branch ruleset.
#
# Usage (from the project root, gh logged in):
#   setup-repo.sh [--repo owner/name] [--dry-run]
#
# Idempotent: labels are created or updated, the ruleset is created or replaced by name.
set -euo pipefail

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; }

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
REPO=""
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null 2>&1 || { echo "gh is required" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in" >&2; exit 1; }
[ -n "$REPO" ] || REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

run() { if [ "$DRY" = 1 ]; then echo "+ $*"; else "$@"; fi; }

echo "repository: $REPO"

echo "labels"
run gh label create "risk:low"    --repo "$REPO" --color 0E8A16 --description "Risk level low (harness/policies/risk.md)"    --force
run gh label create "risk:medium" --repo "$REPO" --color FBCA04 --description "Risk level medium (harness/policies/risk.md)" --force
run gh label create "risk:high"   --repo "$REPO" --color B60205 --description "Risk level high (harness/policies/risk.md)"   --force
run gh label create "needs-human" --repo "$REPO" --color 5319E7 --description "Blocks auto-merge; a person decides"         --force
run gh label create "human-approved" --repo "$REPO" --color 0052CC --description "G2: a person reviewed this PR (harness/policies/human-approval.md)" --force

echo "repository settings"
run gh repo edit "$REPO" --enable-auto-merge --enable-squash-merge --delete-branch-on-merge

echo "ruleset"
ruleset="$ROOT/harness/github/ruleset.json"
name=$(jq -r .name "$ruleset")
existing=$(gh api "repos/$REPO/rulesets" -q ".[] | select(.name == \"$name\") | .id" 2>/dev/null || true)
if [ -n "$existing" ]; then
  run gh api -X PUT "repos/$REPO/rulesets/$existing" --input "$ruleset" --silent
  echo "ruleset '$name' updated (id $existing)"
else
  run gh api -X POST "repos/$REPO/rulesets" --input "$ruleset" --silent
  echo "ruleset '$name' created"
fi

cat <<MSG

Optional secrets (gh secret set <NAME> --repo $REPO):
  CLAUDE_CODE_OAUTH_TOKEN  from 'claude setup-token' (Claude subscription) so CI runs the review skills itself;
                           without it the skills run in your session and CI only checks their comments
  ANTHROPIC_API_KEY        alternative to the OAuth token
  AUTOMERGE_TOKEN          PAT so auto-merge works on Dependabot PRs (GITHUB_TOKEN is read-only there)

The required status checks in the ruleset appear in GitHub after the first workflow run.
MSG
