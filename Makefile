# Quality gates of the harness repository itself. Projects get harness/templates/Makefile instead.

include harness/gates.mk

SHELL_SCRIPTS := $(shell find harness/scripts .claude/hooks -name '*.sh' -not -path '*/tests/fixtures/*') .githooks/pre-commit
JSON_FILES    := $(shell find . -name '*.json' -not -path './.git/*' -not -path './node_modules/*')
WORKFLOWS     := $(wildcard .github/workflows/*.yml)

.PHONY: test typecheck lint

test: ## Script tests (plain bash, no bats needed)
	harness/scripts/tests/run.sh

typecheck: ## Syntax of every shell script, every JSON file and every workflow
	@for f in $(SHELL_SCRIPTS); do bash -n "$$f" || exit 1; done
	@for f in $(JSON_FILES); do jq empty "$$f" || { echo "invalid JSON: $$f"; exit 1; }; done
	@if $(call have,actionlint,typecheck,https://github.com/rhysd/actionlint#installation); then actionlint $(WORKFLOWS); fi

lint: ## shellcheck and markdownlint
	@if $(call have,shellcheck,lint,https://github.com/koalaman/shellcheck#installing); then shellcheck -x $(SHELL_SCRIPTS); fi
	@if $(call have,markdownlint-cli2,lint,npm i -g markdownlint-cli2); then markdownlint-cli2 "**/*.md" "#node_modules"; fi
