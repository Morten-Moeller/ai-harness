#!/usr/bin/env bash
# One lock per repository for running the application (decision 0020). verify takes it from
# starting the application to stopping it, implement for its end-to-end step, so only one worktree
# runs the application at a time.
#
# Usage:
#   app-lock.sh acquire --owner <name> [--wait <seconds>] [--stale <minutes>]
#   app-lock.sh release --owner <name>
#   app-lock.sh status
#
# The lock is the directory ai-harness/app.lock in the git common directory, which every worktree
# of the repository shares. acquire exits 0 when it took the lock or the owner holds it already,
# and 1 when another owner still holds it after --wait seconds (default 0); a lock older than
# --stale minutes (default 60) is taken over. release exits 0 when the lock is free afterwards and
# 1 when another owner holds it. status prints the owner and the age in minutes, or "free".
set -euo pipefail

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

CMD="${1:-}"
case "$CMD" in
  acquire|release|status) shift ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
OWNER=""
WAIT=0
STALE=60
while [ $# -gt 0 ]; do
  case "$1" in
    --owner) OWNER="$2"; shift 2 ;;
    --wait) WAIT="$2"; shift 2 ;;
    --stale) STALE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
case "$WAIT$STALE" in *[!0-9]*) echo "--wait and --stale take whole numbers" >&2; exit 2 ;; esac
[ "$CMD" = status ] || [ -n "$OWNER" ] || { echo "--owner is required" >&2; exit 2; }

common=$(git rev-parse --git-common-dir 2>/dev/null) || { echo "not a git repository" >&2; exit 2; }
case "$common" in /*) ;; *) common="$(pwd)/$common" ;; esac
mkdir -p "$common/ai-harness"
LOCK="$common/ai-harness/app.lock"

holder() { cat "$LOCK/owner" 2>/dev/null || true; }
age() { # seconds since the lock was taken; 0 while its owner is still being written
  local since
  since=$(cat "$LOCK/since" 2>/dev/null || true)
  [ -n "$since" ] || { echo 0; return; }
  echo $(( $(date +%s) - since ))
}
take() {
  if mkdir "$LOCK" 2>/dev/null; then
    printf '%s\n' "$OWNER" > "$LOCK/owner"
    date +%s > "$LOCK/since"
    return 0
  fi
  [ "$(holder)" = "$OWNER" ] && return 0
  if [ -n "$(holder)" ] && [ "$(age)" -ge $(( STALE * 60 )) ]; then
    echo "stale lock of $(holder) taken over" >&2
    rm -rf "$LOCK"
    take
    return
  fi
  return 1
}

case "$CMD" in
  acquire)
    deadline=$(( $(date +%s) + WAIT ))
    until take; do
      if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "busy: $(holder) holds the application lock since $(( $(age) / 60 )) min" >&2
        exit 1
      fi
      sleep 5
    done
    echo "lock: $OWNER"
    ;;
  release)
    if [ ! -d "$LOCK" ]; then echo "free"; exit 0; fi
    if [ "$(holder)" != "$OWNER" ]; then echo "held by $(holder), not by $OWNER" >&2; exit 1; fi
    rm -rf "$LOCK"
    echo "free"
    ;;
  status)
    if [ -d "$LOCK" ]; then echo "$(holder) $(( $(age) / 60 ))"; else echo "free"; fi
    ;;
esac
