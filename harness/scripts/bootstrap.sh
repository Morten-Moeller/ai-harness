#!/usr/bin/env bash
# Creates a new project from the harness template.
#
# Usage:
#   bootstrap.sh <target-dir> --name <project> [--owner <github-login>] [--doc-language de] [--no-git]
#   bootstrap.sh --in-place --name <project> [--owner <github-login>]   (inside a "Use this template" checkout)
#
# Copies the template, applies harness/templates/* (Makefile, AGENTS.md, README.md, settings.json,
# setup action), replaces {{PROJECT_NAME}} and {{PROJECT_OWNER}}, removes the files that belong
# to the harness repository only, writes HARNESS_VERSION and initialises git.
set -euo pipefail

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

HARNESS=$(cd "$(dirname "$0")/../.." && pwd)
TARGET=""
NAME=""
OWNER=""
DOC_LANGUAGE=""
IN_PLACE=0
NO_GIT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --doc-language) DOC_LANGUAGE="$2"; shift 2 ;;
    --in-place) IN_PLACE=1; shift ;;
    --no-git) NO_GIT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

[ -n "$NAME" ] || { echo "--name is required" >&2; usage >&2; exit 2; }
if [ "$IN_PLACE" = 1 ]; then
  TARGET="$HARNESS"
else
  [ -n "$TARGET" ] || { echo "target directory is required" >&2; usage >&2; exit 2; }
  if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    echo "target is not empty: $TARGET" >&2; exit 1
  fi
  mkdir -p "$TARGET"
  TARGET=$(cd "$TARGET" && pwd)
fi

if [ -z "$OWNER" ]; then
  if command -v gh >/dev/null 2>&1; then OWNER=$(gh api user -q .login 2>/dev/null || true); fi
  OWNER=${OWNER:-OWNER}
fi

if [ "$IN_PLACE" = 0 ]; then
  rsync -a \
    --exclude '.git/' \
    --exclude 'harness/decisions/' \
    --exclude 'harness/CHANGELOG.md' \
    --exclude 'harness/scripts/tests/' \
    --exclude 'harness/templates/' \
    --exclude '.markdownlint-cli2.jsonc' \
    --exclude 'Makefile' \
    --exclude 'README.md' \
    --exclude 'AGENTS.md' \
    --exclude '.claude/settings.json' \
    --exclude '.claude/settings.local.json' \
    --exclude '.github/actions/setup/action.yml' \
    --exclude '.github/CODEOWNERS' \
    "$HARNESS/" "$TARGET/"
fi

apply_template() {
  local src="$HARNESS/harness/templates/$1" dst="$TARGET/$2"
  mkdir -p "$(dirname "$dst")"
  sed -e "s/{{PROJECT_NAME}}/$NAME/g" -e "s/{{PROJECT_OWNER}}/$OWNER/g" "$src" > "$dst"
}
apply_template Makefile Makefile
apply_template AGENTS.md AGENTS.md
apply_template README.md README.md
apply_template settings.json .claude/settings.json
apply_template setup-action.yml .github/actions/setup/action.yml
apply_template CODEOWNERS .github/CODEOWNERS

if [ -n "$DOC_LANGUAGE" ]; then
  sed -i.bak -e "s/^doc_language: .*/doc_language: $DOC_LANGUAGE/" "$TARGET/harness/config.yml" && rm -f "$TARGET/harness/config.yml.bak"
fi
sed -i.bak -e "/^auto_merge_allowlist:/,/^[a-z]/ s/\"Morten-Moeller\"/\"$OWNER\"/" "$TARGET/harness/config.yml" && rm -f "$TARGET/harness/config.yml.bak"

if [ "$IN_PLACE" = 1 ]; then
  rm -rf "$TARGET/harness/decisions" "$TARGET/harness/templates" "$TARGET/harness/scripts/tests" \
         "$TARGET/harness/CHANGELOG.md" "$TARGET/.markdownlint-cli2.jsonc"
fi

cp "$HARNESS/HARNESS_VERSION" "$TARGET/HARNESS_VERSION"

if [ "$NO_GIT" = 0 ] && [ "$IN_PLACE" = 0 ] && [ ! -d "$TARGET/.git" ]; then
  default_branch=$(awk '$1 == "default_branch:" { print $2; exit }' "$TARGET/harness/config.yml")
  git -C "$TARGET" init -q -b "${default_branch:-main}"
fi

cat <<MSG
Project $NAME created in $TARGET (harness $(cat "$HARNESS/HARNESS_VERSION")).

Next steps:
  1. Fill test, typecheck and lint in Makefile            (harness/quality-gates.md)
  2. Fill .github/actions/setup/action.yml with the toolchain
  3. Fill project-rules/*.md and docs/domain/glossary.md
  4. Review harness/config.yml and harness/risk-matrix.yml
  5. Create the GitHub repository, push, then: harness/scripts/setup-repo.sh
MSG
