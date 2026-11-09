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
check "bootstrapped make help works" "yes" "$(make -C "$target" help 2>/dev/null | grep -q 'sast' && echo yes || echo no)"

# Update from the harness into the bootstrapped project
echo "changed" >> "$target/harness/workflow.md"
"$ROOT/harness/scripts/update.sh" "$ROOT" --target "$target" >/dev/null
check "update restores an owned file" "no" "$(grep -q '^changed$' "$target/harness/workflow.md" && echo yes || echo no)"
check "update keeps project-owned files" "yes" "$(grep -q '^demo\.' "$target/AGENTS.md" && echo yes || echo no)"

echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
