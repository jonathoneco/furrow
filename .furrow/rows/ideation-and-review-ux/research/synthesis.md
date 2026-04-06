# Research Synthesis

## Deliverable: decision-format
**Finding**: The decision-documentation format should follow summary-protocol.md's pattern
(compact, table-driven, FORMAT+RULES hybrid). Use Option A/B/C naming (already established
in ideate.md). Include mode behavior as a table (first shared skill to do this).
Budget-compatible at ~40 lines. Per-step decision categories are well-scoped and distinct.

## Deliverable: per-step-collaboration
**Finding**: Each step currently has zero mid-step interaction points (except ideate which
has 2). Research, plan, and spec need inline collaboration guidance with high-value question
examples. The decision-format shared fragment handles recording mechanics; per-step inline
content handles question quality. Keep additions to ~20-30 lines per skill file.

## Deliverable: agent-isolation-audit
**Finding**: Agent tool subagents are genuinely isolated from conversation context. They
receive system injections (CLAUDE.md, memory, MCP) but not conversation history or prior
tool results. Gate-evaluator isolation claims are correct — adequate for gate evaluations.
`claude -p --bare` provides stronger isolation by stripping system context too.

## Deliverable: fresh-session-review
**Finding**: `claude -p --bare` is viable for Phase B review. Key verified capabilities:
`--system-prompt-file` (large prompts), `--json-schema` (structured output), `--max-budget-usd`
(cost cap), `--mcp-config` (selective MCP re-add for Serena/context7). Architecture:
Phase A in-session (deterministic), Phase B via `claude -p` (isolated judgment).
Per-deliverable invocations recommended for final review.

## Cross-Cutting Findings
1. Gate-check hook has a bug: blocks `rws transition` for ideate/implement/review steps
   (pre-step evaluator always excludes them, hook interprets as failure). Recorded as learning.
2. MCP tool allowlist for reviewer needs a review-specific config file (Serena read tools +
   context7, no write tools).
3. `--bare` requires `ANTHROPIC_API_KEY` env var for auth (OAuth/keychain not read).

## Research Completeness
All ideation questions addressed:
- Agent isolation: empirically verified
- `claude -p` mechanisms: verified via CLI help and testing
- Decision format patterns: surveyed existing codebase conventions
- Per-step collaboration needs: mapped from skill file analysis
