#!/usr/bin/env bash
# Checks that a review comment for the head commit of a pull request exists and reports no
# blocking findings. Used by ai-review.yml; the comment is written by the review skills, in the
# developer's session or by Claude in CI.
#
# Usage: check-review-comment.sh --pr <number> --sha <head sha> --prefix <Code-Review|Security-Review|Architektur-Review> --skill <skill name>
# Exit 0: comment found, "Ergebnis: keine blockierenden Befunde". Exit 1: missing or blocking.
set -euo pipefail

PR=""; SHA=""; PREFIX=""; SKILL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="$2"; shift 2 ;;
    --sha) SHA="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --skill) SKILL="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$PR" ] && [ -n "$SHA" ] && [ -n "$PREFIX" ] || { echo "usage: --pr <n> --sha <sha> --prefix <prefix> [--skill <name>]" >&2; exit 2; }

comment=$(gh pr view "$PR" --json comments --jq \
  "[.comments[] | select(.body | startswith(\"$PREFIX\")) | select(.body | contains(\"$SHA\"))] | last | .body // empty")

if [ -z "$comment" ]; then
  echo "No '$PREFIX' comment for commit $SHA on PR #$PR."
  echo "Run /${SKILL:-the review skill} $PR in a Claude Code session on this branch, or set CLAUDE_CODE_OAUTH_TOKEN so CI runs it."
  exit 1
fi
if printf '%s\n' "$comment" | grep -q '^Ergebnis: keine blockierenden Befunde'; then
  echo "$PREFIX for $SHA: no blocking findings."
  exit 0
fi
printf '%s\n' "$comment" | grep '^Ergebnis:' || echo "Ergebnis line missing in the comment."
exit 1
