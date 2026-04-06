# Fresh-Session Review via claude -p

## Verified CLI Capabilities

### Flags for Isolated Review
```
claude -p \
  --bare \                          # Strip hooks, memory, CLAUDE.md, MCP
  --tools "Read,Glob,Grep,Bash" \   # Restrict to read-oriented tools
  --mcp-config serena.json \        # Optionally re-add specific MCP tools
  --model opus \                    # Explicit model selection
  --system-prompt-file prompt.md \  # Reviewer contract + artifact paths
  --json-schema '...' \             # Structured output schema
  --max-budget-usd 2.00 \          # Cost cap per review
  --no-session-persistence \        # Don't save session
  --output-format json              # Parseable output
```

### JSON Output Structure
```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "result": "...",
  "total_cost_usd": 0.295,
  "duration_ms": 2490,
  "num_turns": 1,
  "structured_output": { ... },
  "errors": [ ... ]
}
```

### Error Handling
- Exit code is 0 even on errors with JSON output — must check `is_error` field
- Budget exceeded: `"subtype": "error_max_budget_usd"` with message in `errors[]`
- Parse `structured_output` for review results; fall back to `result` text if missing

## Review Architecture

### Phase A (in-session, unchanged)
Deterministic shell checks via `frw check-artifacts`:
- Artifact files exist
- Acceptance criteria have evidence
- Planned files were touched

### Phase B (fresh-session via claude -p)
Quality judgment with full isolation:
1. Build system prompt from template (`templates/review-prompt.md`)
2. Inject: definition.yaml, eval dimensions, artifact paths
3. Spawn `claude -p --bare` with restricted tools
4. Parse `structured_output` for per-dimension PASS/FAIL + evidence
5. Record in `reviews/{deliverable}.json`

### System Prompt Template Needs
The `templates/review-prompt.md` must be self-contained:
- Reviewer contract (what to evaluate, how to score)
- Artifact paths (what to read)
- Eval dimensions (loaded from evals/dimensions/)
- Prohibited context list (do NOT read summary.md, state.json, conversation history)
- Output schema instructions

### MCP Tool Allowlist Decision
Useful for review:
- **Serena**: `find_symbol`, `find_referencing_symbols`, `get_symbols_overview` — code navigation for reviewing implementation quality
- **context7**: `query-docs`, `resolve-library-id` — verify claims about library APIs

Not useful:
- Serena write tools (`replace_symbol_body`, `insert_*`) — reviewer should be read-only
- Memory tools — reviewer shouldn't access project memory

Recommendation: Include Serena and context7 via `--mcp-config` but note that MCP config
files need to exist at known paths. May need to generate a review-specific MCP config.

## Re-Review Flow
1. Phase B fails → results recorded in `reviews/{deliverable}.json`
2. User fixes issues in current session
3. `/review --re-review` spawns fresh `claude -p` (no memory of prior findings)
4. Each re-review is independent — prevents anchoring to previous findings

## Cost Considerations
- Each Phase B invocation: ~$0.30-2.00 depending on artifact size and model
- `--max-budget-usd` prevents runaway costs
- Multi-deliverable reviews: one `claude -p` per deliverable vs. single session for all
  - Per-deliverable is cleaner (isolated per artifact) but more expensive
  - Single session is cheaper but reviewer may cross-contaminate between deliverables
  - Recommendation: per-deliverable for final review, batched for quick checks

## Sources Consulted
- Primary: `claude --help` output (v2.1.92)
- Primary: Empirical test of `--json-schema`, `--max-budget-usd`, `--output-format json`
- Primary: skills/review.md, commands/review.md (existing review architecture)
