# 0007: One review trigger with a rule script, fresh agents and incremental runs

Status: accepted, 2026-11-09. Changed by 0009: commit status, job review-rules.

## Context

The first version had three review skills. Each ran as a fork and started the built-in
`code-review` or `security-review`, which start several agents of their own. On PR #4, with 14
files and mostly Markdown, the three reviews took:

| Review | Tokens | Duration |
|---|---|---|
| code | 88,875 | 689 s |
| security | 106,541 | 524 s |
| architecture | 142,546 | 593 s |

Every push made all three invalid, and the next run started from scratch. Several findings were
mechanical: missing spec, missing ADR link, an edited accepted decision.

## Decision

- One skill, `/review`, replaces the three. It runs `harness/scripts/review-rules.sh` first and
  starts the three read-only reviewer agents directly, without the built-in multi-agent skills.
- The agents run on Sonnet with effort medium, start without the session conversation and read
  only the diff and what it touches.
- A review whose comment names an ancestor of the head reviews only the delta, with the previous
  findings. A delta of only low-risk files carries the result over without an agent.
- Small PRs get one agent run for all reviews.
- CI runs the rule script from the base branch in the job `review-code`.

## Consequences

- Mechanical checks give the same answer every time and cost no tokens.
- Sonnet with effort medium finds less than the built-in multi-agent reviews. For a PR that needs
  a deeper look, the person runs `/code-review` or `/security-review` by hand.
- The rule script is German in its messages, like the rest of the outputs of the harness.
