# Quality gates of the harness repository itself. Projects get harness/templates/Makefile instead.

include harness/gates.mk

SHELL_SCRIPTS := $(shell find harness/scripts .claude/hooks -name '*.sh' -not -path '*/tests/fixtures/*')
JSON_FILES    := $(shell find . -name '*.json' -not -path './.git/*' -not -path './node_modules/*')
WORKFLOWS     := $(wildcard .github/workflows/*.yml)

.PHONY: test typecheck lint

test: ## Script tests (plain bash, no bats needed)
	harness/scripts/tests/run.sh

typecheck: ## Syntax of every shell script, every JSON file and every workflow
	@for f in $(SHELL_SCRIPTS); do bash -n "$$f" || exit 1; done
	@for f in $(JSON_FILES); do jq empty "$$f" || { echo "invalid JSON: $$f"; exit 1; }; done
	@command -v actionlint >/dev/null 2>&1 || { echo "make typecheck: actionlint not installed. https://github.com/rhysd/actionlint#installation"; exit 1; }
	actionlint $(WORKFLOWS)

lint: ## shellcheck and markdownlint
	@command -v shellcheck >/dev/null 2>&1 || { echo "make lint: shellcheck not installed. https://github.com/koalaman/shellcheck#installing"; exit 1; }
	shellcheck -x $(SHELL_SCRIPTS)
	@command -v markdownlint-cli2 >/dev/null 2>&1 || { echo "make lint: markdownlint-cli2 not installed. npm i -g markdownlint-cli2"; exit 1; }
	markdownlint-cli2 "**/*.md" "#node_modules"
