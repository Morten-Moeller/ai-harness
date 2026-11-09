# Shared gate targets. Included by the project Makefile. Harness-owned; do not edit in a project.
# test, typecheck and lint are defined in the project Makefile (see harness/quality-gates.md).

.PHONY: check sast deps help

check: test typecheck lint sast deps ## Run every quality gate

sast: ## Static application security testing (semgrep) and secret scan (gitleaks)
	@command -v semgrep >/dev/null 2>&1 || { echo "make sast: semgrep not installed. https://semgrep.dev/docs/getting-started/quickstart"; exit 1; }
	@command -v gitleaks >/dev/null 2>&1 || { echo "make sast: gitleaks not installed. https://github.com/gitleaks/gitleaks#installing"; exit 1; }
	semgrep scan --config auto --error --quiet
	gitleaks detect --no-banner --redact

deps: ## Known vulnerabilities in dependencies (osv-scanner over the lock files)
	@command -v osv-scanner >/dev/null 2>&1 || { echo "make deps: osv-scanner not installed. https://google.github.io/osv-scanner/installation/"; exit 1; }
	osv-scanner scan source --recursive .

help: ## List every target
	@grep -hE '^[a-zA-Z0-9_:.-]+:.*## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  %-14s %s\n", $$1, $$2}'
