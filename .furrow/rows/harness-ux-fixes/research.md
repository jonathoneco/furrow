# Research: Harness UX Fixes

## summary-protocol-fragment

**Pattern to follow**: Existing shared fragments in `skills/shared/` (6 files) are protocol-style markdown documents referenced from step skills under "Shared References" with the line "Read these when relevant to your current action:". Each fragment is standalone and declarative.

**Step-aware guidance needed**: The ideate step produces Open Questions (from brainstorming) but may not yet have Key Findings or Recommendations. Research+ steps should populate all three. The fragment should declare this mapping explicitly.

**Content threshold**: validate-summary.sh (line 70) checks `>=2 non-empty lines` per section. The fragment must state this threshold so agents know the minimum.

**Insertion point in step skills**: Each step skill has a "Shared References" section with a bulleted list. Add one line referencing summary-protocol.md. Ideate gets an annotated reference noting only Open Questions applies.

## summary-transition-block

**Current step-transition.sh flow** (lines 71-134):
1. Record gate (line 73-83)
2. Validate step artifacts — `validate-step-artifacts.sh` (line 88-91)
3. Regenerate summary — `regenerate-summary.sh` (line 123)
4. Advance step — `advance-step.sh` (line 129)

**Required change**: Insert validate-summary.sh call between step 2 and step 3 (after artifact validation, before summary regeneration). This ensures agent-written content is validated while still intact — regeneration can't clobber it before the check runs.

**validate-summary.sh modifications needed**:
- Accept optional second argument: step name (current step being exited)
- When step is "ideate": only require Open Questions section (skip Key Findings, Recommendations)
- When step is "research" or later: require all three sections
- The structural section check (lines 54-58) stays unchanged

**Current validate-summary.sh skip conditions** (relevant):
- Line 45-48: Skips if last gate was `prechecked` — this is for auto-advanced steps. Keep this.
- It's currently a stop hook. Adding it as a step-transition blocker is a second call site. The hook can remain for session-stop warnings; the transition call is the hard blocker.

## state-schema-init-hints

**state.json schema** (`schemas/state.schema.json`): Uses `additionalProperties: false` so both new fields must be explicitly added.

**New fields to add**:
- `source_todo`: `{"type": ["string", "null"], "pattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$", "description": "TODO entry ID this work unit was created from, or null"}` — default null
- `gate_policy_init`: `{"type": ["string", "null"], "enum": ["supervised", "delegated", "autonomous", null], "description": "Init-time gate policy hint for ideate step, or null"}` — default null

**init-work-unit.sh changes**:
- Add `--source-todo` flag parsing (after line 64, similar to --gate-policy pattern)
- Validate kebab-case pattern (same as name validation, line 105)
- Add both fields to jq template (lines 133-158): `source_todo: $source_todo, gate_policy_init: $gate_policy`
- Remove `.gate_policy_hint` file creation (delete lines 162-166)
- gate_policy is always resolved (lines 95-101) — write it to state.json `gate_policy_init` field

**Both schema copies must sync**: `schemas/state.schema.json` and `adapters/shared/schemas/state.schema.json`

## ideate-reads-init-hints

**Current ideate.md** references:
- Lines 13-25: 6-part ceremony. Step 5 is "Section-by-section approval" which includes gate_policy.
- Step 5 already mentions gate_policy — need to add: "Read `gate_policy_init` from state.json as default"
- Add: "Read `source_todo` from state.json; if non-null, include in definition.yaml"

**Minimal change**: Add 2-3 lines to the ideation ceremony step 5 referencing both state.json fields.

## Cross-cutting: File interaction

Both T11 and T12 modify `skills/ideate.md`:
- T11 adds summary-protocol reference to Shared References
- T12 adds source_todo/gate_policy_init reading to ceremony step 5

These are different sections of the file — no conflict.
