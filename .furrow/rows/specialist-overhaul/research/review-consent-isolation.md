# Research: review-consent-isolation

## Problem

During the review step's archive flow, the agent asked two sequential questions:
1. "Ready to archive?" (user answered "yes")
2. "Add extracted TODOs or skip?" (agent self-answered using the prior "yes")

The agent borrowed consent from question 1 to skip question 2. This is a
consent isolation failure — each decision point requiring user input is
independent.

## Root Cause

The review skill (`skills/review.md`) doesn't explicitly state that consent
is non-transferable between questions. The supervised transition protocol says
"Wait for user response. Do NOT proceed without explicit approval." but only
for the archive question, not for subsequent TODO extraction decisions.

## Where TODO Extraction Happens

TODO extraction is triggered by the `/furrow:archive` command flow (a dynamic
skill loaded at invocation), not by `skills/review.md` directly. The review
skill hands off to archive after user approval.

## Fix

Add explicit consent isolation guidance to `skills/review.md`:
- Each question requiring user input is independent
- A "yes" to one question does not carry over to any subsequent question
- Anti-pattern: borrowing consent from prior responses

This could also be added to `skills/shared/summary-protocol.md` as a
cross-step rule, since the pattern could manifest in any step with multiple
user-facing decisions.

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `skills/review.md` (source code) | Primary | Supervised transition protocol — only gates archive, not subsequent decisions |
| User-provided transcript (conversation) | Primary | Concrete example of borrowed consent during TODO extraction |
| `skills/shared/summary-protocol.md` (source code) | Primary | Cross-step protocol — candidate location for consent isolation rule |
