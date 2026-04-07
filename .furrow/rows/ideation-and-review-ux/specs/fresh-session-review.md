# Spec: fresh-session-review

## Interface Contract

**Modified files**:
- `commands/review.md` — add Phase B `claude -p` invocation logic
- `skills/review.md` — document Phase A/B split, update reviewer contract

**New files**:
- `templates/review-prompt.md` — self-contained system prompt for `claude -p` reviewer

**CLI invocation** (constructed by commands/review.md):
```sh
claude -p \
  --bare \
  --tools "Read,Glob,Grep,Bash" \
  --model "${model}" \
  --system-prompt-file "${prompt_file}" \
  --json-schema "${schema}" \
  --max-budget-usd 2.00 \
  --no-session-persistence \
  --output-format json \
  "${review_prompt}"
```

**Output**: JSON with `structured_output` containing per-dimension PASS/FAIL + evidence.

## Acceptance Criteria (Refined)

1. **Reviewer receives ONLY artifacts + eval dimensions**
   - `--bare` flag strips hooks, memory, CLAUDE.md, MCP, auto-discovery
   - System prompt file contains: reviewer contract, artifact paths, eval dimension definitions, prohibited context list
   - Prohibited: summary.md, state.json, conversation history, definition.yaml rationale fields

2. **--bare flag strips hooks/memory/CLAUDE.md**
   - Verified in research: `--bare` skips hooks, LSP, plugin sync, attribution, auto-memory, CLAUDE.md auto-discovery
   - Auth: requires `ANTHROPIC_API_KEY` env var. commands/review.md must verify this is set before spawning.

3. **Tool allowlist is audited**
   - Base tools: `Read,Glob,Grep,Bash` (via `--tools`)
   - Optional MCP: Serena (read-only tools: find_symbol, find_referencing_symbols, get_symbols_overview, search_for_pattern) + context7 (query-docs, resolve-library-id)
   - MCP inclusion via `--mcp-config` with a review-specific config (if Serena/context7 configs are accessible)
   - If MCP config is not available, proceed without — base tools are sufficient for review

4. **Structured JSON output with per-dimension PASS/FAIL + evidence**
   - JSON schema for `--json-schema` flag:
     ```json
     {
       "type": "object",
       "required": ["deliverable", "dimensions", "overall"],
       "properties": {
         "deliverable": { "type": "string" },
         "dimensions": {
           "type": "array",
           "items": {
             "type": "object",
             "required": ["name", "verdict", "evidence"],
             "properties": {
               "name": { "type": "string" },
               "verdict": { "type": "string", "enum": ["PASS", "FAIL"] },
               "evidence": { "type": "string" }
             }
           }
         },
         "overall": { "type": "string", "enum": ["PASS", "FAIL"] }
       }
     }
     ```
   - Parse `structured_output` from response JSON
   - Record in `reviews/{deliverable}.json`

5. **Re-review works without knowledge of prior findings**
   - Each `claude -p` invocation is a fresh process with no session persistence
   - `--no-session-persistence` prevents saving
   - No reference to prior review results in the system prompt

6. **Error handling for API failures, timeout, malformed output**
   - Check `is_error` field in response JSON (exit code is 0 even on errors)
   - If `is_error: true`: report error message from `errors[]` array, skip review recording
   - If `structured_output` is missing: attempt to parse `result` text as fallback
   - If budget exceeded (`subtype: "error_max_budget_usd"`): report budget limit, suggest increasing `--max-budget-usd`
   - If `claude` command not found: error with installation guidance

## Implementation Notes

### templates/review-prompt.md structure
```
# Review Contract
You are an independent reviewer...
## Prohibited Context
Do NOT read: summary.md, state.json, ...
## Artifacts to Review
{artifact paths — injected at runtime}
## Evaluation Dimensions
{dimension definitions — loaded from evals/dimensions/ and injected}
## Output
Produce structured JSON matching the schema provided via --json-schema.
```

### commands/review.md changes
- After Phase A passes, construct the review prompt:
  1. Read `templates/review-prompt.md`
  2. Inject artifact paths from definition.yaml
  3. Load eval dimensions from `evals/dimensions/{artifact-type}.yaml`
  4. Write assembled prompt to temp file
  5. Construct `claude -p` command with all flags
  6. Run via Bash, capture JSON output
  7. Parse `structured_output`, record in `reviews/{deliverable}.json`
- Per-deliverable invocations (one `claude -p` per deliverable)
- `--max-budget-usd 2.00` default, adjustable

### skills/review.md changes
- Document Phase A (in-session, deterministic) vs Phase B (fresh-session, isolated)
- Update reviewer contract to reference `templates/review-prompt.md`
- Remove/update any language assuming reviewer is an in-session subagent

## Dependencies

- `agent-isolation-audit` deliverable (informs isolation strategy — already complete)
- Eval dimension files in `evals/dimensions/` (existing, not modified)
