# Workflow

Every change moves through three stages. Four human gates sit between them. The risk level of the
change decides which gates apply.

```text
  /spec            G0           /implement          CI + reviews + /verify        merge
Spec (draft) ──► approved ──► Implementation ──► Verification ─────────────────► done
                               │  G1 (plan, medium+)                 │ G2 (merge, medium+)
                               │                                     │ G3 (evidence, high)
```

## Stage 1: Spec

- Skill: `/spec <topic>`. Output: `docs/specs/NNNN-<slug>.md` with status `draft`, and a row in
  `docs/specs/README.md`.
- The spec names the goal, the scope, the terms from `docs/domain/glossary.md`, numbered acceptance
  criteria A1..An that a test or a walk-through can check, the contracts it touches, a proposed
  risk level and whether an ADR is required (`harness/policies/adr.md`).
- Open questions are listed, not resolved by guessing. The skill asks the person.

**Gate G0, spec approval.** A person sets `status: approved` in the spec frontmatter and the row.
Agents never set this status. `/implement` stops when the status is anything else.

## Stage 2: Implementation

- Skill: `/implement <spec-id>`.
- Steps: check G0; run `harness/scripts/risk-level.sh` and `/risk`; check the ADR policy and write
  the ADR with `/adr` when one is required; write the plan.

**Gate G1, plan approval.** For medium and high risk the skill ends after the plan and waits for a
person. Low risk continues without a pause.

- Then: code and tests on a branch named `<type>/<spec-id>-<slug>`, `make check`, a pull request
  from `.github/pull_request_template.md` with the spec link, the risk level and the ADR links.
- The spec row moves to `in Arbeit`, then `Review` when the PR is open.

## Stage 3: Verification

Three independent sources of evidence:

1. **Quality gates** in CI: `test`, `typecheck`, `lint`, `sast`, `deps`. All required.
2. **AI reviews** in CI by risk level: `/review-code` always, `/review-security` from medium,
   `/review-architecture` from high or whenever `contracts/` or `docs/architecture/` changed. Each
   writes one PR comment. `review-code` is a required check and fails on blocking findings.
3. **`/verify <PR>`**: walks the acceptance criteria of the spec, runs the affected tests, walks the
   application when a criterion names a screen, writes a table (erfüllt / nicht erfüllt / nicht
   prüfbar) as a PR comment and sets the spec row to `fertig` or `in Arbeit`.

**Gate G2, merge.** Medium and high risk need an approving review by a person. The `human-gate`
check in `auto-merge.yml` passes only then. Low risk passes the gate without a review.

**Gate G3, verification evidence.** High risk needs the `/verify` comment on the final commit
before a person approves. The person reads the table, not the diff alone.

## Merge

- Low risk: `auto-merge.yml` enables GitHub auto-merge when the conditions in
  `harness/policies/auto-merge.md` hold. GitHub merges after every required check is green.
- Medium and high risk: a person merges. No skill merges. `gh pr merge` is denied for agents.
- After the merge the spec row moves to `done` with the PR number.

## Spec status values

| Status | Set by | Meaning |
|---|---|---|
| `draft` | `/spec` | written, not approved |
| `approved` | a person | G0 passed, implementation may start |
| `in Arbeit` | `/implement`, `/verify` | code in progress or findings to fix |
| `Review` | `/implement` | PR open, waiting for gates, reviews, verification |
| `fertig` | `/verify` | every criterion met, ready to merge |
| `done` | a person or `/verify` after merge | merged |
| `blockiert` | anyone | waits for a decision; the note names it |

## Rules that hold in every stage

- Never weaken a check, a test or a policy to make a change pass. Surface the conflict.
- Edge cases without an answer in the spec go back to the person. No silent workarounds.
- A skill updates only its own row in the status table and only its own PR comment.
- Report failing checks with their output. Do not report passing checks.
