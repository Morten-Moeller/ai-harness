# 0005: Review skills run in the session; CI checks their comments

Status: accepted, 2026-11-09

## Context

The user works with a Claude subscription, not an API key, and tests the harness alone first.
Running the review skills in GitHub Actions needs a token secret on every repository and spends
the subscription's quota on CI.

## Decision

`/review-code`, `/review-security` and `/review-architecture` run in the developer's Claude Code
session and write one PR comment each with a fixed first line (`<Prefix> <date>, Commit <sha>`)
and a fixed `Ergebnis:` line. `ai-review.yml` checks for that comment on the head commit with
`harness/scripts/check-review-comment.sh`; `review-code` is a required check. When
`CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`) or `ANTHROPIC_API_KEY` is set, the same jobs run
the skill in CI before the check. After posting a comment the skill reruns the failed CI jobs.

## Consequences

- No secret is needed to use the harness. CI stays a verifier, not a reviewer.
- A review is tied to a commit SHA; every push needs a new review.
- A person can still bypass by writing the comment by hand. CODEOWNERS and the audit trail of
  the merged PRs are the counterweight; the harness is not a defence against its own users.
