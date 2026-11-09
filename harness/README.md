# AI Development Harness

The harness is the fixed part of every project: how agents and people move a change from an idea
to a merged pull request, which checks a change must pass, and which decisions stay with a person.
The project context (domain, specs, ADRs, contracts, project rules, source code) lives next to it
and is owned by the project.

```text
AI Development Harness
│
├── Workflow                  harness/workflow.md
│   ├── Spec → Implementation → Verification
│   ├── Human Gates G0–G3
│   └── Risk Assessment       harness/policies/risk.md, harness/risk-matrix.yml
│
├── Skills / Agents           .claude/skills/, .claude/agents/
│   ├── /spec  /adr  /domain  /contract
│   ├── /risk  /implement  /verify
│   └── /review  (= /review-code  /review-security  /review-architecture by level)
│
├── Quality Gates             harness/quality-gates.md, Makefile, .github/workflows/quality-gates.yml
│   ├── test  typecheck  lint
│   └── sast  deps
│
└── Policies                  harness/policies/
    ├── When is an ADR required?            adr.md
    ├── When is human approval required?    human-approval.md
    ├── What is low / medium / high risk?   risk.md
    └── What may be merged automatically?   auto-merge.md

Project Context
│
├── AGENTS.md                 user-owned control file, read by every agent
├── docs/
│   ├── domain/               glossary, bounded contexts, invariants
│   ├── adr/                  architecture decision records
│   ├── specs/                one spec per change, status table in README.md
│   └── architecture/         system overview, module boundaries
├── contracts/                API, event and schema contracts
├── project-rules/            frontend.md, backend.md, testing.md
└── src/                      source code
```

## How the pieces connect

1. A person or an agent writes a spec with `/spec`. A person sets its status to `approved`
   (gate G0).
2. `/implement` reads the spec, runs the risk assessment, checks the ADR policy, plans (gate G1 for
   medium and high risk), writes code and tests, runs `make check`, opens a pull request.
3. CI runs the quality gates, computes the risk level and labels the PR. The developer runs
   `/review <PR>` in the session: it starts the reviews the level requires (`review-code`, from
   medium `review-security`, for high `review-architecture`) in parallel and skips those already
   done for the commit. CI checks that their comments exist for the head commit. `/verify` walks
   the acceptance criteria and writes the evidence.
4. Low risk with green gates and no blocking findings merges automatically. Medium and high risk
   wait for a person (gate G2, and G3 for high).

## Harness-owned and project-owned files

Harness-owned files come from this repository and are refreshed with
`harness/scripts/update.sh`. They are listed in `harness/owned-paths.txt`. Everything else is
project-owned: the project edits it freely, the harness never overwrites it.

| Harness-owned | Project-owned |
|---|---|
| `harness/` (except `decisions/` and `CHANGELOG.md` of the harness repository itself) | `AGENTS.md`, `CLAUDE.md` |
| `.claude/settings.json`, `.claude/hooks/`, `.claude/skills/`, `.claude/agents/` | `docs/`, `contracts/`, `project-rules/`, `src/` |
| `.github/workflows/*.yml`, `.github/pull_request_template.md` | `Makefile`, `.github/actions/setup/`, `.github/dependabot.yml`, `.github/CODEOWNERS` |
| `HARNESS_VERSION` | `harness/config.yml` and `harness/risk-matrix.yml` after the first copy |

`harness/config.yml` and `harness/risk-matrix.yml` are copied once by `bootstrap.sh` and then belong
to the project. `update.sh` shows a diff for them and does not overwrite.

## Starting a new project

```bash
harness/scripts/bootstrap.sh /path/to/new-project --name my-project
cd /path/to/new-project
# 1. fill the gate targets in Makefile (test, lint, typecheck)
# 2. fill .github/actions/setup/action.yml with the toolchain setup
# 3. fill project-rules/*.md and docs/domain/glossary.md
# 4. review harness/config.yml and harness/risk-matrix.yml
# 5. set the GitHub side: harness/scripts/setup-repo.sh
```

`setup-repo.sh` creates the labels, enables auto-merge on the repository and imports the branch
ruleset. No secret is needed: the review skills run in the session. Optional: `claude setup-token`
and `gh secret set CLAUDE_CODE_OAUTH_TOKEN` let CI run the review skills itself (works with a
Claude subscription); `AUTOMERGE_TOKEN` (a PAT) lets auto-merge work on Dependabot PRs.

## Updating a project to a newer harness

```bash
harness/scripts/update.sh /path/to/harness-checkout
git diff --stat
```

The script copies the harness-owned paths, keeps the project-owned ones and prints what changed.
The project reviews the diff and commits it as a normal pull request. Breaking changes between
harness versions are listed in `harness/CHANGELOG.md` of the harness repository.

## Enforcement layers

| Rule | Enforced by |
|---|---|
| Agents do not edit `AGENTS.md`, `CLAUDE.md`, the policies, the risk matrix, the config | `permissions.deny` `Edit(...)` rules in `.claude/settings.json` |
| Agents do not merge, approve, force-push or set labels | `permissions.deny` `Bash(...)` rules |
| A change passes every gate | `make check` locally, `quality-gates.yml` as required checks |
| Every PR has a code review without blocking findings | `review-code` check in `ai-review.yml` reads the comment of `/review-code` |
| Medium and high risk need a person | `human-gate` job in `auto-merge.yml` as a required check: label `human-approved` or an approving review |
| Control files need a human review | `.github/CODEOWNERS` |

Known gap: the `Edit(...)` rules cover the file-editing tools. A shell command such as `sed -i` or a
redirect can still write a protected file. CODEOWNERS and the branch ruleset are the second line.
Report an agent that uses the shell to change a control file; it is a policy violation.

## Language

Instructions for agents (this directory, `.claude/`, `.github/`) are written in simplified technical
English. Output for people (pull request comments, reports, spec and ADR documents) uses the
language in `harness/config.yml` (`doc_language`).
