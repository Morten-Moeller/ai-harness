#!/usr/bin/env bash
# Refreshes the harness-owned files of a project from a harness checkout or git URL.
#
# Usage (from the project root, or with --target):
#   update.sh <harness-dir | git-url> [--ref <tag|branch>] [--target <project-dir>]
#
# Copies every path in the harness's owned-paths.txt, shows a diff for the [diff-only] paths and
# writes HARNESS_VERSION. Nothing is committed; review with git diff and open a pull request.
set -euo pipefail

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

SOURCE=""
REF=""
TARGET="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) SOURCE="$1"; shift ;;
  esac
done
[ -n "$SOURCE" ] || { usage >&2; exit 2; }
[ -f "$TARGET/HARNESS_VERSION" ] || { echo "not a harness project (no HARNESS_VERSION): $TARGET" >&2; exit 1; }
TARGET=$(cd "$TARGET" && pwd)

CLONE=""
if [ -d "$SOURCE" ]; then
  SOURCE=$(cd "$SOURCE" && pwd)
else
  CLONE=$(mktemp -d)
  trap 'rm -rf "$CLONE"' EXIT
  if [ -n "$REF" ]; then git clone -q --depth 1 --branch "$REF" "$SOURCE" "$CLONE"; else git clone -q --depth 1 "$SOURCE" "$CLONE"; fi
  SOURCE="$CLONE"
fi
[ -f "$SOURCE/harness/owned-paths.txt" ] || { echo "no harness/owned-paths.txt in $SOURCE" >&2; exit 1; }

from_version=$(cat "$TARGET/HARNESS_VERSION")
to_version=$(cat "$SOURCE/HARNESS_VERSION")
echo "harness $from_version -> $to_version"

resolve() { # "src => dst" or "path" -> prints "src<TAB>dst"
  local line="$1"
  case "$line" in
    *"=>"*) printf '%s\t%s\n' "$(printf '%s' "${line%%=>*}" | sed 's/[ \t]*$//')" "$(printf '%s' "${line#*=>}" | sed 's/^[ \t]*//')" ;;
    *) printf '%s\t%s\n' "$line" "$line" ;;
  esac
}

section=copy
while IFS= read -r line || [ -n "$line" ]; do
  line=$(printf '%s' "$line" | sed 's/^[ \t]*//; s/[ \t]*$//')
  [ -z "$line" ] && continue
  case "$line" in
    \#*) continue ;;
    "[diff-only]") section="diff"; continue ;;
    "[copy]") section="copy"; continue ;;
  esac
  IFS=$'\t' read -r src dst <<<"$(resolve "$line")"
  if [ ! -e "$SOURCE/$src" ]; then echo "skip (not in source): $src"; continue; fi
  if [ "$section" = copy ]; then
    if [ -d "$SOURCE/$src" ]; then
      mkdir -p "$TARGET/$dst"
      rsync -a --delete --exclude 'tests/' "$SOURCE/$src" "$TARGET/$dst"
    else
      mkdir -p "$(dirname "$TARGET/$dst")"
      cp "$SOURCE/$src" "$TARGET/$dst"
    fi
    echo "copied: $dst"
  else
    if [ -e "$TARGET/$dst" ]; then
      if ! diff -u "$TARGET/$dst" "$SOURCE/$src" >/dev/null 2>&1; then
        echo "differs (project-owned, not copied): $dst  <- $src"
        diff -u "$TARGET/$dst" "$SOURCE/$src" | sed 's/^/    /' | head -60 || true
      fi
    else
      echo "missing in project (not copied): $dst  <- $src"
    fi
  fi
done < "$SOURCE/harness/owned-paths.txt"

cp "$SOURCE/HARNESS_VERSION" "$TARGET/HARNESS_VERSION"
echo
echo "Done. Review with: git -C $TARGET status --short"
echo "Breaking changes between versions: harness/CHANGELOG.md in the harness repository."
