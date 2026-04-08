# Spec: review-consent-isolation

## Interface Contract

File: `skills/review.md`
Section: Supervised Transition Protocol (lines 38-46)
Consumers: agents executing the review step

Behavior change: Add explicit consent isolation rules so each user-facing
question is treated as an independent approval gate.

## Acceptance Criteria (Refined)

1. `skills/review.md` Supervised Transition Protocol section contains: "Each question requiring user input is an independent decision — a 'yes' to one question does NOT carry over to subsequent questions"
2. Anti-pattern documented in the section: "Do not interpret prior user responses as approval for unrelated subsequent decisions (e.g., 'yes to archive' does not mean 'yes to skip TODOs')"
3. The archive approval and any subsequent TODO extraction are explicitly listed as separate consent gates

## Implementation Notes

- Small change — 3-5 lines added to the existing Supervised Transition Protocol
- Consider also adding consent isolation to `skills/shared/summary-protocol.md`
  as a cross-step rule (affects all steps with multi-question flows), but scope
  to review.md for this deliverable
- The TODO extraction flow is triggered by `/furrow:archive` (dynamic skill),
  not by review.md directly — review.md can only instruct the agent about
  consent boundaries, not enforce them structurally

## Dependencies

None — standalone change to a single file.
