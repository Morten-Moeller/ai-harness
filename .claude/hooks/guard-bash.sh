#!/usr/bin/env bash
# PreToolUse hook for Bash (harness/decisions/0011). Denies what only a person or CI may do:
# merge, PR reviews, labels, rulesets, branch protection, repository settings, secrets, commit
# statuses other than ai-review, force pushes, pushes to the default branch, setup-repo.sh and
# update.sh, and shell writes to the paths of the Edit(...) deny rules in .claude/settings.json.
# A guard against mistakes, not a security boundary: harness/scripts/human-gate.sh checks who set
# the label. Heredoc bodies are not matched, so text that names a command can be written.
#
# Input: the hook JSON on stdin. Output: a deny decision as JSON, or nothing. Exit 0.
set -u

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
input=$(cat)
if ! command -v jq >/dev/null 2>&1; then
  printf '{"systemMessage":"guard-bash.sh: jq is not installed, the Bash guard is inactive."}\n'
  exit 0
fi
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg r "Harness guard: $1 If this is text (commit message, file content), write it from a file or a heredoc." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

default_branch=$(awk '$1 == "default_branch:" { v=$2; gsub(/"/, "", v); print v; exit }' "$ROOT/harness/config.yml" 2>/dev/null)
default_branch=${default_branch:-main}

stripped=$(printf '%s\n' "$cmd" | awk '
  delim != "" {
    line = $0
    if (tabs) sub(/^\t+/, "", line)
    if (line == delim) delim = ""
    next
  }
  {
    print
    s = $0
    while (match(s, /<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
      before = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
      d = substr(s, RSTART, RLENGTH)
      s = substr(s, RSTART + RLENGTH)
      if (before == "<") continue
      tabs = (d ~ /^<<-/)
      sub(/^<<-?[ \t]*/, "", d)
      gsub(/["\047]/, "", d)
      delim = d
      break
    }
  }')

segments=$(printf '%s\n' "$stripped" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')

S='(^|[^A-Za-z0-9_./-])'
W='([[:space:]]|$)'
API="${S}gh[[:space:]]+api([[:space:]]|$)"

regex_escape() { printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g'; }

protected=""
if [ -f "$ROOT/.claude/settings.json" ]; then
  protected=$(jq -r '.permissions.deny[]? | select(startswith("Edit(")) | sub("^Edit\\((\\./)?"; "") | sub("\\)$"; "") | sub("/?\\*\\*$"; "")' "$ROOT/.claude/settings.json" 2>/dev/null)
fi
root_re=$(regex_escape "$ROOT")
protected_re=""
while IFS= read -r p; do
  [ -n "$p" ] && protected_re="${protected_re}${p}"$'\t'"$(regex_escape "$p")"$'\n'
done <<P
$protected
P
writer='(^|[[:space:]])(sed[[:space:]]+(-[A-Za-z]*i|--in-place)|perl[[:space:]]+-[A-Za-z]*i|tee|cp|mv|rm|truncate|rsync|ln|install|dd|patch|git[[:space:]]+(apply|checkout|restore|rm|mv))([[:space:]]|$)'

while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | tr -s ' \t' '  ')
  [ -n "${seg// /}" ] || continue

  [[ $seg =~ ${S}gh[[:space:]]+pr[[:space:]]+merge${W} ]] && deny "Merging is for people and auto-merge.yml (harness/policies/auto-merge.md)."
  [[ $seg =~ ${S}gh[[:space:]]+pr[[:space:]]+review${W} ]] && deny "Pull request reviews are for people (harness/policies/human-approval.md)."
  [[ $seg =~ ${S}gh[[:space:]]+label${W} ]] && deny "Labels are set by people and CI only."
  [[ $seg =~ ${S}gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit)[[:space:]].*[[:space:]](--label|--add-label|--remove-label|-l)([[:space:]=]|$) ]] && deny "Labels are set by people and CI only. Drop the label option."
  [[ $seg =~ ${S}gh[[:space:]]+auth[[:space:]]+token${W} ]] && deny "The gh token stays inside gh."
  [[ $seg =~ ${S}gh[[:space:]]+(secret|variable)${W} ]] && deny "Secrets and variables are set by people."
  [[ $seg =~ ${S}gh[[:space:]]+repo[[:space:]]+(edit|delete|rename|archive)${W} ]] && deny "Repository settings are changed by people (harness/scripts/setup-repo.sh)."
  if [[ $seg =~ $API ]]; then
    [[ $seg =~ labels ]] && deny "Labels are set by people and CI only."
    [[ $seg =~ graphql ]] && deny "gh api graphql can change labels and reviews. Use gh pr commands or REST reads."
    [[ $seg =~ (rulesets|/protection|/actions/(secrets|variables|permissions)|/hooks|/keys|/collaborators|/pulls/[0-9]+/(merge|reviews)|/merges) ]] && deny "Rulesets, branch protection, repository settings, merges and reviews are for people."
    if [[ $seg =~ statuses ]]; then
      contexts=$(printf '%s\n' "$seg" | grep -o 'context=[^[:space:]]*' | wc -l | tr -d ' ')
      if ! [[ $seg =~ context=[\"\']?ai-review[\"\']?([[:space:]]|$) ]] || [ "$contexts" != 1 ]; then
        deny "Commit statuses other than ai-review come from CI. Use harness/scripts/review-status.sh."
      fi
    fi
  fi
  [[ $seg =~ (^|[[:space:]/])setup-repo\.sh${W} ]] && deny "Labels, repository settings and the ruleset are set by a person: ! harness/scripts/setup-repo.sh"
  [[ $seg =~ (^|[[:space:]/])update\.sh${W} ]] && deny "update.sh overwrites .claude/settings.json; a person runs it: ! harness/scripts/update.sh <harness-dir>"
  [[ $seg =~ human-gate\.sh.*--remove-stale ]] && deny "--remove-stale removes labels; only CI runs it."
  [[ $seg =~ api\.github\.com.*(labels|rulesets|protection|statuses|merge|reviews|graphql) ]] && deny "Use gh for the GitHub API; labels, rulesets, statuses, merges and reviews are not for agents."

  if [[ $seg =~ ${S}git[[:space:]]+push${W} ]]; then
    [[ $seg =~ [[:space:]](--force|--force-with-lease|--force-if-includes|--mirror)([[:space:]=]|$) ]] && deny "No force push."
    [[ $seg =~ [[:space:]]-[A-Za-z]*f[A-Za-z]*([[:space:]]|$) ]] && deny "No force push."
    [[ $seg =~ [[:space:]]\+[^[:space:]] ]] && deny "No force push (+refspec)."
    [[ $seg =~ [[:space:]:](refs/heads/)?${default_branch}${W} ]] && deny "No push to $default_branch. Push a branch and open a pull request."
    if [[ $seg =~ ${S}git[[:space:]]+push([[:space:]]+(-[^[:space:]]+|origin))*[[:space:]]*$ ]]; then
      current=$(git -C "$ROOT" symbolic-ref --short HEAD 2>/dev/null || true)
      [ "$current" = "$default_branch" ] && deny "No push to $default_branch. Push a branch and open a pull request."
    fi
  fi

  if [ -n "$protected_re" ]; then
    while IFS=$'\t' read -r p pe; do
      [ -n "$p" ] || continue
      path_re="(^|[[:space:]'\"=>])(\./|${root_re}/)?${pe}(/[^[:space:]'\"]*)?([[:space:]'\";)]|$)"
      [[ $seg =~ $path_re ]] || continue
      [[ $seg =~ $writer ]] && deny "$p is changed by a person only (.claude/settings.json deny rules)."
      [[ $seg =~ \>[[:space:]]*[\'\"]?(\./|${root_re}/)?${pe} ]] && deny "$p is changed by a person only (.claude/settings.json deny rules)."
    done <<P
$protected_re
P
  fi
done <<SEG
$segments
SEG

if [ -n "$protected" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    while IFS= read -r line; do
      case "$line" in *"$p"*) ;; *) continue ;; esac
      [[ $line =~ (open\(|write_text|write_bytes|writeFile|\.write\() ]] && deny "$p is changed by a person only (.claude/settings.json deny rules)."
    done <<L
$cmd
L
  done <<P
$protected
P
fi
exit 0
