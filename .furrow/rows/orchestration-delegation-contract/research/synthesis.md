# Research Synthesis

**Three topics, three verdicts:**

| Topic | Verdict | Affects |
|---|---|---|
| T1 — Handoff-shape study | **VALID-WITH-CAVEATS** — typed-fields-rendered-to-markdown framing survives the kill-switch | D1 schema field set |
| T2 — Subagent semantics | **GO with required design adjustments** — assumptions A and B both verified; experimental flag required; identity is JSON-on-stdin not env var | D2 driver lifecycle, D3 enforcement mechanism |
| T3 — Decision-format parseability | **Tighten-required (re-pointing, not redesign)** — de-facto gate-transition format is strictly parseable (49/49 entries); canonical spec format unused | D4 decisions extraction |

## Cross-cutting findings

### Kill-switch dispositions (constraints #16, #19)
- **#16 (handoff-prompt framing)** does NOT trigger redirect. Framing is structurally valid; the row proceeds.
- **#19 (subagent semantics)** does NOT trigger redirect, but DOES require concrete design adjustments before spec. Definition refinements applied below.

### D1 — Provisional schema field set (frozen at spec)

Nine required core fields derived from convergent prior art (OpenAI Agents SDK, CrewAI, Claude Code subagents) plus three Furrow-specific additions:

```
schema_version, target, step, row, objective, deliverables,
return_format, grounding, constraints
```

`target` carries layer + id (e.g., `driver:research`, `engine:specialist:python-specialist`) — drives D3 enforcement scoping. `grounding` is a reference to D4's context bundle, not inlined content. `return_format` is the EOS-report schema (analog of OpenAI Agents `output_type`).

**Top risk for spec:** operator→driver vs driver→engine field asymmetry. Spec should evaluate single-schema-with-conditional-requireds vs schema-fork-by-target. Lean: single schema, conditional requireds keyed on `target.layer`.

### D2/D3 — Subagent runtime adjustments (concrete spec inputs)

T2 is the most consequential research output. Six items must land in spec:

1. **Experimental flag precondition.** `SendMessage` requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Add `frw doctor` check; add as definition.yaml constraint.

2. **Identity vocabulary correction.** Subagent addressing is by `agent_id` (runtime-assigned, e.g., `subagent_123`), not by human name. Lead pins a stable `name` at spawn ("call this teammate `driver:research`"); the team config maps name → agent_id. `drivers.json` stores BOTH: `{ '{step}': { pinned_name, agent_id, spawned_at, last_message_at, session_id, agent_type } }`.

3. **Hook stdin-JSON reads, not env var.** `bin/frw.d/hooks/layer-guard.sh` extracts `agent_type` from stdin JSON (`jq -r '.agent_type // "main"'`), NOT from `$CLAUDE_AGENT_NAME` (which doesn't exist). Layer-context filename: `.furrow/.layer-context.${agent_type}` with `main` fallback.

4. **`SubagentStart` / `SubagentStop` hook events.** Use these for layer-context lifecycle: `SubagentStart` writes `.layer-context.{agent_type}`; `SubagentStop` clears it or marks driver complete in `drivers.json`.

5. **Session-resume hazard.** Claude Code's `/resume` does NOT restore in-process teammates. `drivers.json` must detect stale `agent_id`s on session-start and re-spawn affected drivers (replaying any pending phase work). This is a new D2 acceptance criterion.

6. **Layer-context re-assertion on every `SendMessage`.** Driver's own auto-compaction (~95% by default) can drop spawn-time instructions. Operator must prepend a one-line layer-reminder ("Layer: research-driver. See `.furrow/.layer-context.driver:research`.") to every `SendMessage` body.

**Path-injection guard:** validate `agent_type` against the registered allowlist in `drivers.json` before constructing the layer-context filename. New D3 acceptance criterion.

**Pi parity gap:** T2 did not verify whether Pi adapter has equivalent identity-in-tool_call context. Adding a follow-up TODO and a research-step open question for spec.

### D4 — Decisions extraction (clean ship)

T3 quantitative: 49/49 (100%) of gate-transition entries across 7 sampled rows match the regex `^- \*\*([a-z_]+)->([a-z_]+)\*\*: (pass|fail) — (.*)$`. Strict parsing is achievable on the de-facto format. The canonical spec format (`## Decision:` block with `**Options**`/`**Lean**`/`**Outcome**` fields) is unused (0/8 rows) and should be retired as a follow-up TODO.

**D4 spec direction:**
- Primary parser: strict regex against `## Settled Decisions` gate-transition entries.
- Secondary fallback: best-effort `^- Decision:` prose-bullet scraping in `## Key Findings` (catches mid-step pivots like pre-write-validation-go-first's D1 re-scope).
- De-dup policy for gate retries: last-wins, preserving order.
- `skills/shared/decision-format.md` retire-as-canonical follow-up TODO captured at row close.

## Definition.yaml refinements applied this step

- D2 ACs: drivers.json schema updated (pinned_name + agent_id); session-resume re-spawn AC added; SendMessage layer-reminder AC added; SubagentStart/Stop hook lifecycle AC added.
- D3 ACs: layer-guard.sh reads stdin JSON for agent_type; SubagentStart hook writes layer-context; agent_type allowlist validation against drivers.json.
- D4 ACs: decisions extraction parses gate-transition shape (strict regex); fallback to `- Decision:` bullets best-effort.
- Constraint additions: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 precondition + frw doctor check; Pi parity audit follow-up TODO captured.

## Open questions for spec step

1. **D1 single schema vs fork.** Operator→driver and driver→engine field asymmetry is real. Spec must decide: one schema with conditional requireds keyed on `target.layer`, or two related schemas sharing a base. T1 leans single-schema; spec validates against concrete field-by-field analysis.
2. **Pi parity for agent identity.** Does `adapters/pi/furrow.ts` `tool_call` context expose an equivalent of `agent_type`? Spec verifies via Pi adapter audit; if absent, layer-guard.sh-equivalent on Pi needs a different mechanism.
3. **Driver re-assertion content.** What exactly is the one-line layer-reminder appended to every SendMessage? Spec defines the canonical text + format.
4. **Session-resume detection algorithm.** The drivers.json staleness check on session start — exact semantics (compare `session_id` field? validate against Claude Code's session ID surface? wall-clock heuristic?). Spec resolves.

## Sources

- `research/handoff-shape.md` — T1 full report
- `research/subagent-semantics.md` — T2 full report
- `research/decision-format-parseability.md` — T3 full report
