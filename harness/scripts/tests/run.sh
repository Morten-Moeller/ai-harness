#!/usr/bin/env bash
# Tests for the harness scripts and hooks. Plain bash, no test framework needed.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
RISK="$ROOT/harness/scripts/risk-level.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $1"
    echo "  expected: $2"
    echo "  actual:   $3"
  fi
}

files() {
  printf '%s\n' "$@" > "$TMP/files"
  echo "$TMP/files"
}

level() { "$RISK" --format level "$@"; }

# Level by path
check "docs only is low" low "$(level --files-from "$(files docs/specs/0001-x.md README.md)")"
check "source file is medium" medium "$(level --files-from "$(files src/orders/service.ts)")"
check "contract is high" high "$(level --files-from "$(files contracts/api/orders.yaml)")"
check "auth under src is high" high "$(level --files-from "$(files src/auth/login.ts)")"
check "unknown path is medium" medium "$(level --files-from "$(files something.xyz)")"
check "highest level wins" high "$(level --files-from "$(files docs/a.md src/b.ts contracts/c.json)")"
check "test dir outside src is low" low "$(level --files-from "$(files tests/orders.test.ts)")"
check "workflow is high" high "$(level --files-from "$(files .github/workflows/ci.yml)")"
check "AGENTS.md is high" high "$(level --files-from "$(files AGENTS.md)")"
check "skill file is medium, not low by *.md" medium "$(level --files-from "$(files .claude/skills/spec/SKILL.md)")"
check "empty change is low" low "$(level --files-from "$(files)")"

# Dependency manifests
check "manifest alone is medium" medium "$(level --files-from "$(files package.json pnpm-lock.yaml)")"
check "dependabot patch on manifests is low" low "$(level --files-from "$(files package.json pnpm-lock.yaml)" --dependabot version-update:semver-patch)"
check "dependabot minor on manifests is low" low "$(level --files-from "$(files go.mod go.sum)" --dependabot version-update:semver-minor)"
check "dependabot major stays medium" medium "$(level --files-from "$(files package.json)" --dependabot version-update:semver-major)"
check "dependabot patch with a source file is medium" medium "$(level --files-from "$(files package.json src/a.ts)" --dependabot version-update:semver-patch)"
check "maven manifest is a dependency manifest" low "$(level --files-from "$(files backend/pom.xml)" --dependabot version-update:semver-minor)"
check "gradle wrapper is a dependency manifest" low "$(level --files-from "$(files gradle/wrapper/gradle-wrapper.properties build.gradle.kts)" --dependabot version-update:semver-patch)"
check "manifest with contract is high" high "$(level --files-from "$(files package.json contracts/x.yaml)")"

# Escalators
check "size raises low to medium" medium "$(level --files-from "$(files docs/a.md)" --lines 300)"
check "size below the limit keeps low" low "$(level --files-from "$(files docs/a.md)" --lines 200)"
check "size does not raise medium" medium "$(level --files-from "$(files src/a.ts)" --lines 5000)"

cat > "$TMP/diff-src" <<'D'
diff --git a/src/a.ts b/src/a.ts
--- a/src/a.ts
+++ b/src/a.ts
@@ -1 +1,2 @@
 x
+const Password = readSecret();
D
check "keyword in source raises medium to high" high "$(level --files-from "$(files src/a.ts)" --diff-from "$TMP/diff-src")"

cat > "$TMP/diff-doc" <<'D'
diff --git a/docs/a.md b/docs/a.md
--- a/docs/a.md
+++ b/docs/a.md
@@ -1 +1,2 @@
 x
+Never commit a password or token.
D
check "keyword in a low file does not raise" low "$(level --files-from "$(files docs/a.md)" --diff-from "$TMP/diff-doc")"

cat > "$TMP/diff-removed" <<'D'
diff --git a/src/a.ts b/src/a.ts
--- a/src/a.ts
+++ b/src/a.ts
@@ -1,2 +1 @@
 x
-const password = "old";
D
check "keyword in a removed line does not raise" medium "$(level --files-from "$(files src/a.ts)" --diff-from "$TMP/diff-removed")"

cat > "$TMP/diff-skip" <<'D'
diff --git a/tests/a.test.ts b/tests/a.test.ts
--- a/tests/a.test.ts
+++ b/tests/a.test.ts
@@ -1 +1,2 @@
 x
+it.skip("slow", () => {})
D
check "gate marker raises low to medium" medium "$(level --files-from "$(files tests/a.test.ts)" --diff-from "$TMP/diff-skip")"
cat > "$TMP/diff-skip-doc" <<'D'
diff --git a/docs/a.md b/docs/a.md
--- a/docs/a.md
+++ b/docs/a.md
@@ -1 +1,2 @@
 x
+Never write it.skip( in a test.
D
check "gate marker in Markdown does not raise" low "$(level --files-from "$(files docs/a.md)" --diff-from "$TMP/diff-skip-doc")"

# Lines counted from the diff
check "lines are counted from the diff" "1" "$("$RISK" --files-from "$(files src/a.ts)" --diff-from "$TMP/diff-removed" --format json | sed 's/.*"lines":\([0-9]*\).*/\1/')"

# Output formats
out=$("$RISK" --files-from "$(files docs/a.md)" --format json)
check "json has docs_only true" "true" "$(printf '%s' "$out" | sed 's/.*"docs_only":\([a-z]*\).*/\1/')"
out=$("$RISK" --files-from "$(files src/a.ts)" --format json)
check "json has docs_only false" "false" "$(printf '%s' "$out" | sed 's/.*"docs_only":\([a-z]*\).*/\1/')"
if command -v jq >/dev/null 2>&1; then
  check "json is valid" "ok" "$("$RISK" --files-from "$(files 'src/we ird.ts' docs/a.md)" --format json | jq -r 'if .level then "ok" else "bad" end')"
fi
check "markdown starts with a heading" "## Risiko: medium" "$("$RISK" --files-from "$(files src/a.ts)" --format markdown | head -1)"
check "text first line" "risk: high" "$("$RISK" --files-from "$(files contracts/a.yaml)" --format text | head -1)"
check "unknown format exits 2" "2" "$("$RISK" --files-from "$(files a.md)" --format nope >/dev/null 2>&1; echo $?)"

# Hooks
out=$(CLAUDE_PROJECT_DIR="$ROOT" "$ROOT/.claude/hooks/session-context.sh"; echo "exit=$?")
check "session hook exits 0" "exit=0" "$(printf '%s' "$out" | tail -1)"
check "session hook names the harness" "yes" "$(printf '%s' "$out" | grep -q 'AI harness' && echo yes || echo no)"
out=$(echo '{"hook_event_name":"Stop","stop_hook_active":false}' | CLAUDE_PROJECT_DIR="$ROOT" "$ROOT/.claude/hooks/stop-reminder.sh"; echo "exit=$?")
check "stop hook exits 0" "exit=0" "$(printf '%s' "$out" | tail -1)"
out=$(echo '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$ROOT" "$ROOT/.claude/hooks/stop-reminder.sh")
check "stop hook is silent when already active" "" "$out"

# Bootstrap into a temporary directory
target="$TMP/demo"
"$ROOT/harness/scripts/bootstrap.sh" "$target" --name demo --owner someone --no-git >/dev/null
check "bootstrap copies the workflow" "yes" "$([ -f "$target/harness/workflow.md" ] && echo yes || echo no)"
check "bootstrap uses the template Makefile" "yes" "$(grep -q 'not configured' "$target/Makefile" && echo yes || echo no)"
check "bootstrap replaces the project name" "yes" "$(grep -q '^demo\.' "$target/AGENTS.md" && echo yes || echo no)"
check "bootstrap sets the owner" "yes" "$(grep -q '@someone' "$target/.github/CODEOWNERS" && echo yes || echo no)"
check "bootstrap drops the harness decisions" "no" "$([ -d "$target/harness/decisions" ] && echo yes || echo no)"
check "bootstrap drops the templates" "no" "$([ -d "$target/harness/templates" ] && echo yes || echo no)"
check "bootstrap uses the template settings" "yes" "$(grep -q 'harness/policies' "$target/.claude/settings.json" && echo yes || echo no)"
check "bootstrap writes the version" "$(cat "$ROOT/HARNESS_VERSION")" "$(cat "$target/HARNESS_VERSION")"
check "bootstrapped make test fails on purpose" "no" "$(make -C "$target" test >/dev/null 2>&1 && echo yes || echo no)"
check "bootstrap copies the dotfiles" "yes" "$([ -f "$target/.claude/hooks/guard-bash.sh" ] && [ -f "$target/.github/workflows/ai-review.yml" ] && echo yes || echo no)"
check "bootstrap registers the guard hook" "yes" "$(jq -e '.hooks.PreToolUse[0].hooks[0].command | test("guard-bash")' "$target/.claude/settings.json" >/dev/null && echo yes || echo no)"
check "bootstrap keeps the default source paths" "  - src" "$(awk '/^source_paths:/ { getline; print; exit }' "$target/harness/config.yml")"
src_copy="$TMP/src-copy"
mkdir -p "$src_copy"
rsync -a --exclude .git "$ROOT/" "$src_copy/"
touch "$src_copy/.DS_Store" "$src_copy/harness/.DS_Store"
target2="$TMP/bootstrap-paths"
"$src_copy/harness/scripts/bootstrap.sh" "$target2" --name demo2 --owner someone --no-git --source-paths frontend/src,backend/src/main >/dev/null
check "bootstrap skips .DS_Store" "" "$(find "$target2" -name .DS_Store)"
check "bootstrap writes the source paths" "$(printf '  - frontend/src\n  - backend/src/main')" "$(awk '/^source_paths:/ { f = 1; next } f && /^[ \t]*-/ { print; next } f { exit }' "$target2/harness/config.yml")"
check "bootstrap keeps the key after the source paths" "yes" "$(grep -q '^contracts_generate_target:' "$target2/harness/config.yml" && echo yes || echo no)"
check "bootstrap rejects a bad --github" "2" "$("$ROOT/harness/scripts/bootstrap.sh" "$TMP/x" --name x --github 'not a repo' >/dev/null 2>&1; echo $?)"
check "bootstrapped make help works" "yes" "$(make -C "$target" help 2>/dev/null | grep -q 'sast' && echo yes || echo no)"

# Update from the harness into the bootstrapped project
echo "changed" >> "$target/harness/workflow.md"
"$ROOT/harness/scripts/update.sh" "$ROOT" --target "$target" >/dev/null
check "update restores an owned file" "no" "$(grep -q '^changed$' "$target/harness/workflow.md" && echo yes || echo no)"
check "update keeps project-owned files" "yes" "$(grep -q '^demo\.' "$target/AGENTS.md" && echo yes || echo no)"

# Human gate
HG="$ROOT/harness/scripts/human-gate.sh"
SHA_A=1111111111111111111111111111111111111111
SHA_B=2222222222222222222222222222222222222222
gate_cfg() { printf 'human_approval_label: %s\nsecond_reviewer_for: %s\n' "$1" "$2" > "$TMP/gate.yml"; echo "$TMP/gate.yml"; }
echo '[]' > "$TMP/no-reviews.json"
printf '[{"commit_id":"%s","user":{"login":"reviewer","type":"User"},"author_association":"COLLABORATOR","state":"APPROVED"}]\n' "$SHA_A" > "$TMP/approved-a.json"
printf '[{"commit_id":"%s","user":{"login":"reviewer","type":"User"},"author_association":"COLLABORATOR","state":"APPROVED"}]\n' "$SHA_B" > "$TMP/approved-b.json"
printf '[{"commit_id":"%s","user":{"login":"author","type":"User"},"author_association":"OWNER","state":"APPROVED"}]\n' "$SHA_A" > "$TMP/approved-self.json"
printf '[{"commit_id":"%s","user":{"login":"reviewer","type":"User"},"author_association":"COLLABORATOR","state":"APPROVED"},{"commit_id":"%s","user":{"login":"reviewer","type":"User"},"author_association":"COLLABORATOR","state":"CHANGES_REQUESTED"}]\n' "$SHA_A" "$SHA_A" > "$TMP/approved-then-changes.json"
printf '[{"event":"labeled","label":{"name":"human-approved"},"actor":{"type":"User"},"created_at":"2026-11-09T12:00:00Z"}]\n' > "$TMP/label-user-noon.json"
printf '[{"event":"labeled","label":{"name":"human-approved"},"actor":{"type":"Bot"},"created_at":"2026-11-09T12:00:00Z"}]\n' > "$TMP/label-bot-noon.json"
printf '[{"commit_id":"%s","user":{"login":"stranger","type":"User"},"author_association":"NONE","state":"APPROVED"}]\n' "$SHA_A" > "$TMP/approved-stranger.json"
printf '[{"commit_id":"%s","user":{"login":"app","type":"Bot"},"author_association":"COLLABORATOR","state":"APPROVED"}]\n' "$SHA_A" > "$TMP/approved-bot.json"
gate() { "$HG" --pr 7 --sha "$SHA_A" --author author --events-json "$TMP/label-user-noon.json" --pushed-at 2026-11-09T11:00:00Z --permissions "reviewer=write,author=admin,stranger=read,app=write,reader=read" "$@" >/dev/null 2>&1 && echo pass || echo fail; }
printf '[{"commit_id":"%s","user":{"login":"reader","type":"User"},"author_association":"MEMBER","state":"APPROVED"}]\n' "$SHA_A" > "$TMP/approved-reader.json"
c=$(gate_cfg human-approved '""')
check "gate: low passes without anything" pass "$(gate --level low --config "$c" --labels "" --reviews-json "$TMP/no-reviews.json")"
check "gate: medium without label or review fails" fail "$(gate --level medium --config "$c" --labels "" --reviews-json "$TMP/no-reviews.json")"
check "gate: label by a person after the push passes" pass "$(gate --level high --config "$c" --labels "risk:high,human-approved" --reviews-json "$TMP/no-reviews.json")"
check "gate: label from before the push fails" fail "$(gate --level high --config "$c" --labels human-approved --reviews-json "$TMP/no-reviews.json" --pushed-at 2026-11-09T13:00:00Z)"
check "gate: label set by a bot fails" fail "$(gate --level medium --config "$c" --labels human-approved --reviews-json "$TMP/no-reviews.json" --events-json "$TMP/label-bot-noon.json")"
check "gate: approval by another person on the head commit passes" pass "$(gate --level high --config "$c" --labels "" --reviews-json "$TMP/approved-a.json")"
check "gate: approval on an older commit does not count" fail "$(gate --level high --config "$c" --labels "" --reviews-json "$TMP/approved-b.json")"
check "gate: approval by an account without write access does not count" fail "$(gate --level high --config "$c" --labels "" --reviews-json "$TMP/approved-stranger.json")"
check "gate: approval by a member with read permission does not count" fail "$(gate --level high --config "$c" --labels "" --reviews-json "$TMP/approved-reader.json")"
check "gate: approval by a bot does not count" fail "$(gate --level high --config "$c" --labels "" --reviews-json "$TMP/approved-bot.json")"
check "gate: approval by the author does not count" fail "$(gate --level high --config "$c" --labels "" --reviews-json "$TMP/approved-self.json")"
check "gate: changes requested after approval does not count" fail "$(gate --level high --config "$c" --labels "" --reviews-json "$TMP/approved-then-changes.json")"
c=$(gate_cfg human-approved high)
check "gate: second reviewer for high ignores the label" fail "$(gate --level high --config "$c" --labels human-approved --reviews-json "$TMP/no-reviews.json")"
check "gate: second reviewer for high accepts an approval" pass "$(gate --level high --config "$c" --labels "" --reviews-json "$TMP/approved-a.json")"
check "gate: second reviewer for high keeps the label for medium" pass "$(gate --level medium --config "$c" --labels human-approved --reviews-json "$TMP/no-reviews.json")"
c=$(gate_cfg human-approved High)
check "gate: unknown second_reviewer_for fails closed" fail "$(gate --level medium --config "$c" --labels human-approved --reviews-json "$TMP/no-reviews.json")"
c=$(gate_cfg '""' '""')
check "gate: switched-off label needs an approval" fail "$(gate --level medium --config "$c" --labels human-approved --reviews-json "$TMP/no-reviews.json")"
c=$(gate_cfg 'risk:high' '""')
check "gate: label named like a CI label is refused" fail "$(gate --level medium --config "$c" --labels risk:high --reviews-json "$TMP/no-reviews.json")"
printf 'doc_language: de\n' > "$TMP/gate-empty.yml"
check "gate: missing keys fall back to the label human-approved" pass "$(gate --level medium --config "$TMP/gate-empty.yml" --labels human-approved --reviews-json "$TMP/no-reviews.json")"
check "gate: bad sha is a usage error" "2" "$("$HG" --level medium --pr 7 --sha abc --author author >/dev/null 2>&1; echo $?)"

# Review rules, in a temporary project repository
RR="$TMP/rr"
mkdir -p "$RR/harness/scripts" "$RR/docs/specs" "$RR/docs/adr" "$RR/src" "$RR/contracts"
cp "$ROOT/harness/scripts/review-rules.sh" "$ROOT/harness/scripts/risk-level.sh" "$RR/harness/scripts/"
cp "$ROOT/harness/risk-matrix.yml" "$RR/harness/"
printf 'doc_language: de\ndefault_branch: main\nsource_paths:\n  - src\nlow_risk_max_lines: 200\nreview_rules_disabled:\n' > "$RR/harness/config.yml"
printf -- '---\nid: "0001"\nstatus: approved\nadrs: []\n---\n\n# Probe\n\n## Akzeptanzkriterien\n\n| Nr | Kriterium | Prüfung |\n|---|---|---|\n| A1 | x | Test |\n| A2 | y | Test |\n\n## Contracts\n\nkeine\n' > "$RR/docs/specs/0001-probe.md"
printf -- '---\nid: "0002"\nstatus: draft\n---\n\n# Draft\n' > "$RR/docs/specs/0002-draft.md"
printf '# 0001: Choice\n\nStatus: accepted\n\n## Kontext\n\nold text\n' > "$RR/docs/adr/0001-choice.md"
printf 'export const a = 1\n' > "$RR/src/a.ts"
rrgit() { git -C "$RR" -c user.email=t@example.com -c user.name=t "$@"; }
rrgit init -q -b main && rrgit add -A && rrgit commit -q -m base
rrgit checkout -q -b change
rr() {
  git -C "$RR" add -A
  git -C "$RR" diff --name-only main > "$TMP/rr.files"
  git -C "$RR" diff main > "$TMP/rr.diff"
  printf '%s\n' "$RR_BODY" > "$TMP/rr.body"
  "$RR/harness/scripts/review-rules.sh" --files-from "$TMP/rr.files" --diff-from "$TMP/rr.diff" \
    --body-from "$TMP/rr.body" --title "$RR_TITLE" --author "${RR_AUTHOR:-dev}" --base-ref main --format tsv 2>/dev/null || true
}
rule_rows() { printf '%s\n' "$1" | awk -F'\t' -v r="$2" '$1 == r { print $4 }' | sort -u | tr '\n' ' ' | sed 's/ $//'; }
RR_BODY=$'| A1 | test a |\n| A2 | test b |'
RR_TITLE="feat: probe (0001)"
printf 'export const a = 2\n' > "$RR/src/a.ts"
out=$(rr)
check "rules: approved spec, criteria covered, clean code has no findings" "" "$out"
RR_BODY='| A1 | test a |'
check "rules: criterion without evidence blocks" "ja" "$(rule_rows "$(rr)" kriterium)"
RR_TITLE="feat: probe"
RR_BODY=""
check "rules: medium without spec blocks" "ja" "$(rule_rows "$(rr)" spec)"
check "rules: dependabot needs no spec" "" "$(RR_AUTHOR=app/dependabot rule_rows "$(RR_AUTHOR=app/dependabot rr)" spec)"
RR_TITLE="feat: draft (0002)"
check "rules: draft spec blocks" "ja" "$(rule_rows "$(rr)" spec)"
RR_TITLE="feat: missing (0009)"
check "rules: a named spec that does not exist blocks" "ja" "$(rule_rows "$(rr)" spec)"
mkdir -p "$RR/harness/templates" "$RR/harness/decisions"
printf '# 0009: Probe\n\nStatus: accepted\n' > "$RR/harness/decisions/0009-probe.md"
check "rules: harness repo, a decision of the PR stands in for the spec of the title" "" "$(rule_rows "$(rr)" spec)"
rm -rf "$RR/harness/templates" "$RR/harness/decisions"
rrgit checkout -q main -- src/a.ts
printf 'more\n' >> "$RR/docs/guide.md"
RR_TITLE="docs: guide"
check "rules: low without spec does not block" "nein" "$(rule_rows "$(rr)" spec)"
rm -f "$RR/docs/guide.md"
RR_TITLE="feat: probe (0001)"
RR_BODY=$'| A1 | t |\n| A2 | t |'
printf 'export const a = 1\n// explain the value\n' > "$RR/src/a.ts"
check "rules: comment in source is reported, not blocking" "nein" "$(rule_rows "$(rr)" kommentar)"
printf 'doc_language: de\nsource_paths:\n  - src\nreview_rules_disabled:\n  - kommentar\n' > "$RR/harness/config.yml"
check "rules: disabled rule is skipped" "" "$(rule_rows "$(rr)" kommentar)"
rrgit checkout -q main -- harness/config.yml
printf 'export const a = 1\nit.skip("slow", () => {})\n' > "$RR/src/a.ts"
check "rules: switched-off test without reason blocks" "ja" "$(rule_rows "$(rr)" gate)"
RR_BODY=$'| A1 | t |\n| A2 | t |\nGate-Änderung: upstream outage, ticket 12'
check "rules: switched-off test with reason does not block" "nein" "$(rule_rows "$(rr)" gate)"
check "rules: gate change asks for a person" "true" "$("$RR/harness/scripts/review-rules.sh" --files-from "$TMP/rr.files" --diff-from "$TMP/rr.diff" --body-from "$TMP/rr.body" --title "$RR_TITLE" --base-ref main --format json 2>/dev/null | jq -r .needs_human)"
rrgit checkout -q main -- src/a.ts
printf '  - %s\n' "'eslint-disable'" >> "$RR/harness/risk-matrix.yml"
check "rules: the pattern list in the risk matrix is no switched-off check" "" "$(rule_rows "$(rr)" gate)"
rrgit checkout -q main -- harness/risk-matrix.yml
awk '/^gate_markers:/ { exit } { print }' "$ROOT/harness/risk-matrix.yml" > "$RR/harness/risk-matrix.yml"
check "rules: a missing gate_markers list blocks" "ja" "$(rule_rows "$(rr)" gate)"
rrgit checkout -q main -- harness/risk-matrix.yml
RR_BODY=$'| A1 | t |\n| A2 | t |'
printf 'openapi: 3.1.0\n' > "$RR/contracts/api.yaml"
out=$(rr)
check "rules: high risk without ADR blocks" "ja" "$(rule_rows "$out" adr)"
check "rules: contract change with spec Contracts 'keine' blocks" "ja" "$(rule_rows "$out" contract)"
RR_BODY=$'| A1 | t |\n| A2 | t |\nADR: docs/adr/0001-choice.md'
check "rules: linked ADR satisfies the ADR rule" "" "$(rule_rows "$(rr)" adr)"
rm -f "$RR/contracts/api.yaml"
printf '# 0001: Choice\n\nStatus: superseded by 0002\n\n## Kontext\n\nold text\n' > "$RR/docs/adr/0001-choice.md"
check "rules: status line change of an accepted ADR is allowed" "" "$(rule_rows "$(rr)" entscheidung)"
printf '# 0001: Choice\n\nStatus: accepted\n\n## Kontext\n\nnew text\n' > "$RR/docs/adr/0001-choice.md"
check "rules: content change of an accepted ADR blocks" "ja" "$(rule_rows "$(rr)" entscheidung)"
rrgit checkout -q main -- docs/adr/0001-choice.md
printf '// Code generated by tool. DO NOT EDIT.\nexport const g = 1\n' > "$RR/src/gen.ts"
check "rules: generated file is reported" "nein" "$(rule_rows "$(rr)" generiert)"
printf '# Shared targets. Owned by the harness; do not edit in a project.\nx:\n' > "$RR/src/gen.ts"
check "rules: a lower-case do-not-edit note is not a generated file" "" "$(rule_rows "$(rr)" generiert)"
rm -f "$RR/src/gen.ts"

# Guard hook (.claude/hooks/guard-bash.sh)
GUARD="$ROOT/.claude/hooks/guard-bash.sh"
GR="$TMP/guard"
mkdir -p "$GR/.claude" "$GR/harness"
printf 'default_branch: main\n' > "$GR/harness/config.yml"
printf '{"permissions":{"deny":["Edit(./AGENTS.md)","Edit(./harness/policies/**)","Bash(gh pr merge*)"]}}\n' > "$GR/.claude/settings.json"
guard() {
  printf '%s' "$1" | jq -Rs '{tool_name: "Bash", tool_input: {command: .}}' \
    | CLAUDE_PROJECT_DIR="$GR" "$GUARD" | jq -r '.hookSpecificOutput.permissionDecision // empty' | grep . || echo allow
}
while IFS='|' read -r expected command; do
  [ -n "$command" ] || continue
  actual=$(guard "$command")
  check "guard: $command" "$expected" "$actual"
done <<'G'
deny|gh pr merge 5 --squash
deny|cd /x && gh pr review 5 --approve
deny|gh label create x
deny|gh pr edit 5 --add-label human-approved
deny|gh pr edit 5 --add-label=human-approved
deny|gh pr edit 5 --remove-label needs-human
deny|gh pr create --title x --body-file b -l human-approved
deny|gh issue edit 5 --add-label x
deny|gh api -X POST repos/o/r/issues/5/labels -f labels[]=x
deny|gh api graphql -f query=x
deny|gh api -X PUT repos/o/r/rulesets/1 --input r.json
deny|gh api -X PUT repos/o/r/pulls/5/merge
deny|gh api repos/o/r/statuses/abc -f state=success -f context=human-gate
deny|gh api repos/o/r/statuses/abc -f state=success -f context=ai-review
deny|harness/scripts/review-status.sh set --sha abc --state success --description x
deny|gh -R o/r pr merge 5
deny|gh --repo=o/r pr review 5 --approve
deny|git -C . push --force origin feat/x
deny|git -C /repo push origin main
deny|N=5; gh api -X PUT repos/o/r/pulls/$N/merge
deny|gh api -X PATCH repos/o/r/issues/5 --input body.json
deny|gh api repos/o/r/issues/5 -f state=closed
deny|gh api repos/o/r/statuses/abc -fstate=success -fcontext=ai-review
deny|gh api -XPOST repos/o/r/statuses/abc
deny|gh api -X post repos/o/r/statuses/abc
deny|gh api -X POST repos/o/r/statuses/abc -X GET
deny|gh auth token
deny|gh secret set X
deny|gh repo edit --enable-auto-merge
deny|curl -X POST https://api.github.com/repos/o/r/issues/5/labels
deny|git push --force origin feat/x
deny|git push -f origin feat/x
deny|git push --force-with-lease origin feat/x
deny|git push origin +feat/x
deny|git push origin main
deny|git push origin HEAD:main
deny|echo x > AGENTS.md
deny|echo x >> ./AGENTS.md
deny|sed -i '' s/a/b/ AGENTS.md
deny|cat new.md | tee harness/policies/risk.md
deny|cp /tmp/x harness/policies/risk.md
deny|git checkout origin/main -- AGENTS.md
deny|harness/scripts/setup-repo.sh
deny|./harness/scripts/update.sh ../ai-harness
deny|bash harness/scripts/human-gate.sh --level medium --pr 5 --remove-stale
allow|gh pr edit 5 --title "feat: x" --body-file /tmp/body.md
allow|gh pr create --title x --body-file b --base main
allow|gh pr view 5 --json labels
allow|gh api repos/o/r/pulls/5
allow|gh api repos/o/r/commits/abc/statuses
allow|gh api repos/o/r/issues/5/comments
allow|gh api -X GET search/issues -f q=repo:o/r
allow|gh api -X PATCH repos/o/r/pulls/5 --input body.json
allow|git push -u origin feat/x
allow|git push --follow-tags origin feat/main-fix
allow|cat AGENTS.md 2>/dev/null
allow|sed -i '' s/a/b/ harness/templates/AGENTS.md
allow|git add AGENTS.md && git commit -F /tmp/msg
allow|grep -n policies harness/policies/risk.md > /tmp/out
allow|harness/scripts/review-status.sh publish --sha abc
G
check "guard: heredoc body is not matched" "allow" "$(guard "$(printf 'cat > doc.md <<'"'"'X'"'"'\ngh pr merge --auto runs in auto-merge.yml\nX\n')")"
check "guard: python write to a protected path" "deny" "$(guard "$(printf 'python3 - <<X\nopen("AGENTS.md", "w").write("x")\nX\n')")"
check "guard: commands after a heredoc are matched" "deny" "$(guard "$(printf 'cat > a <<X\ntext\nX\ngh pr merge 5\n')")"
mkdir -p "$TMP/nojq"
for tool in bash cat awk sed tr grep git env; do ln -s "$(command -v "$tool")" "$TMP/nojq/$tool"; done
nojq() { printf '%s' "$1" | jq -Rs '{tool_name: "Bash", tool_input: {command: .}}' > "$TMP/nojq.json"; PATH="$TMP/nojq" CLAUDE_PROJECT_DIR="$GR" bash "$GUARD" < "$TMP/nojq.json" | grep -o '"permissionDecision":"deny"' || echo allow; }
check "guard: without jq gh is blocked" '"permissionDecision":"deny"' "$(nojq 'gh pr merge 5')"
check "guard: without jq other commands pass" "allow" "$(nojq 'ls -la')"
check "guard: without jq a tab does not hide git" '"permissionDecision":"deny"' "$(nojq "$(printf 'git\tpush origin main')")"
git -C "$GR" init -q -b main
check "guard: bare push on the default branch" "deny" "$(guard 'git push')"
git -C "$GR" checkout -q -b feat/x
check "guard: bare push on a feature branch" "allow" "$(guard 'git push')"

# Review status (harness/scripts/review-status.sh)
RS="$ROOT/harness/scripts/review-status.sh"
c1=1111111111111111111111111111111111111111
c2=2222222222222222222222222222222222222222
c3=3333333333333333333333333333333333333333
SR="$TMP/status-repo"
mkdir -p "$SR" "$TMP/bin"
git -C "$SR" init -q
printf '# no header\n' > "$TMP/no-header.md"
(cd "$SR" && "$RS" save --sha "$c1" --file "$TMP/no-header.md" >/dev/null 2>&1)
check "status: save rejects a result without header" "2" "$?"
printf '<!-- ai-review state=failure level=medium reviews=code,security blocking=1 notes=2 -->\n\n1. a.ts:3\n' > "$TMP/result.md"
(cd "$SR" && "$RS" save --sha "$c1" --file "$TMP/result.md" >/dev/null)
check "status: load returns the saved result" "1. a.ts:3" "$(cd "$SR" && "$RS" load --sha "$c1" | tail -1)"
(cd "$SR" && "$RS" load --sha "$c3" >/dev/null 2>&1)
check "status: load without a result exits 1" "1" "$?"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "%s"\n' "$TMP/gh-args" > "$TMP/bin/gh"
chmod +x "$TMP/bin/gh"
(cd "$SR" && PATH="$TMP/bin:$PATH" "$RS" publish --sha "$c1" --repo o/r >/dev/null)
check "status: publish sets the state from the header" "state=failure" "$(grep '^state=' "$TMP/gh-args")"
check "status: publish uses the context ai-review" "context=ai-review" "$(grep '^context=' "$TMP/gh-args")"
check "status: publish describes the reviews" "description=Code, Sicherheit: 1 blockierend, 2 Hinweise" "$(grep '^description=' "$TMP/gh-args")"
printf '%s\n' "$c1" "$c2" "$c3" > "$TMP/commits"
check "status: last finds the newest commit with a saved result" "$c1" "$(cd "$SR" && "$RS" last --commits-from "$TMP/commits")"
(cd "$SR" && "$RS" save --sha "$c2" --file "$TMP/result.md" >/dev/null)
check "status: last prefers the newer commit" "$c2" "$(cd "$SR" && "$RS" last --commits-from "$TMP/commits")"
printf '%s\n' "$c3" > "$TMP/commits3"
check "status: last prints nothing without a saved result" "" "$(cd "$SR" && "$RS" last --commits-from "$TMP/commits3")"
(cd "$SR" && PATH="$TMP/bin:$PATH" "$RS" publish --sha "$c1" --repo o/r --note "übernommen von 2222222" >/dev/null)
check "status: publish puts the note first" "description=übernommen von 2222222; Code, Sicherheit: 1 blockierend, 2 Hinweise" "$(grep '^description=' "$TMP/gh-args")"

echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
