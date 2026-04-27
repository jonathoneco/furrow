# D6 — Artifact Presentation Protocol

Implementation-ready spec for deliverable `artifact-presentation-protocol`. Codifies the single canonical mode for in-conversation artifact rendering and ships an advisory Stop hook that flags violations without blocking. Wave W6, depends on D2/D1/D3.

## goals

- Formalize `<!-- {phase}:section:{name} -->` (already used in `skills/ideate.md`) as the canonical, single, mandatory presentation mode for artifacts shown in conversation (AC1).
- Provide a per-artifact section-break rules table covering all canonical row artifacts (AC2).
- Anchor presentation as an operator-layer responsibility per D2's vertical layering (AC4).
- Ship `furrow hook presentation-check` as a Go subcommand wired to Claude's Stop hook, advisory severity (AC5–6).
- Register `presentation_protocol_violation` blocker code (AC7).
- Retrofit `skills/{plan,spec,review}.md` and `commands/work.md.tmpl` with additive references — no content rewrites (AC8–9).
- Cover with unit tests + integration test replaying conversational fixtures (AC10–11).

## non-goals

- Inventing new marker syntax. The existing `skills/ideate.md` syntax is preserved exactly (constraint #19).
- Blocking on violation. The hook is severity `warn`, `confirmation_path: silent` — it surfaces telemetry without halting the operator turn (AC5).
- Driver-level presentation. Drivers return phase results; only the operator presents (AC4).
- Any state.json or summary.md mutation (constraint #12).
- Content rewrites of `skills/{plan,spec,review}.md` — additive references only (AC8).

## approach

1. Write `skills/shared/presentation-protocol.md` as the canonical reference doc (single source of truth for the marker mode + per-artifact section table).
2. Implement `internal/cli/hook/presentation_check.go` with stdin JSON parsing matching Claude's Stop-hook payload shape, regex-based artifact-shape detection, and blocker emission via the existing `internal/cli/blocker_envelope.go` helper.
3. Append `presentation_protocol_violation` to `schemas/blocker-taxonomy.yaml` (additive, after D3's codes).
4. Add Stop-hook registration line to `.claude/settings.json` (additive to D3's PreToolUse layer-guard).
5. Add additive references in `skills/{plan,spec,review}.md` Supervised Transition Protocol sections.
6. Add Presentation block in `commands/work.md.tmpl`.
7. Author `tests/integration/test-presentation-protocol.sh` replaying fixture transcripts.

## protocol-doc-structure

`skills/shared/presentation-protocol.md` outline:

1. **Marker convention** — exact syntax `<!-- {phase}:section:{name} -->`. `phase` ∈ {ideate, research, plan, spec, decompose, implement, review, presentation}; `name` is kebab-case; one marker per section, placed on the line immediately preceding the section content. No closing marker.
2. **Per-artifact section-break rules table** — see [section-break-rules-table](#section-break-rules-table) below; embedded verbatim in the doc.
3. **Phase-prefix semantics** — when drafting/revising during step `S`, use `phase=S`. When the operator presents an artifact for user review (mid-step or at gate), use `phase=presentation`. When summarizing during the review step, use `phase=review`. Phase prefix is the disambiguator that lets downstream tooling (and the hook) tell drafting from presentation passes.
4. **Operator-only constraint** — only the operator layer renders artifacts to the user. Phase drivers MUST return structured phase results to the operator; drivers do not call SendMessage to the user with artifact-shaped content. Cross-references `skills/shared/layer-protocol.md` (D2).
5. **Examples** — three end-to-end examples showing: (a) ideate-step decision block with markers, (b) operator presenting a `definition.yaml` for approval, (c) review-step summary section.

## section-break-rules-table

Exhaustive rules for canonical row artifacts (AC2):

| Artifact | Required sections (one marker per row) |
|---|---|
| `definition.yaml` | `objective`; one section per deliverable, `name=<deliverable.name>`; `context_pointers`; `constraints`; `gate_policy` |
| `plan.json` | `step-list`; `dependencies`; `risks` |
| `spec.md` | `goals`; `non-goals`; `approach`; `acceptance`; `open-questions` |
| `summary.md` | `key-findings`; `open-questions`; `recommendations` |
| `research.md` | `method`; `findings`; `gaps` |
| handoff artifact (D1 driver/engine) | one section per top-level schema field (e.g. `target`, `objective`, `grounding`, `constraints`, `return_format`, plus `step`/`row` for driver and `deliverables` for engine) |

Rendering convention: marker on its own line, blank line, then content. Empty sections allowed (marker + blank). Section order follows the rows above.

## presentation-check-hook

File: `internal/cli/hook/presentation_check.go`. Registered in `internal/cli/app.go` under the existing `hook` command group.

**Stdin JSON shape** (Claude Stop-hook input — verified pattern):

```go
type StopInput struct {
    SessionID    string `json:"session_id"`
    StopHookActive bool `json:"stop_hook_active"`
    TranscriptPath string `json:"transcript_path"` // path to JSONL of turn
    HookEventName  string `json:"hook_event_name"` // "Stop"
    AgentID        string `json:"agent_id,omitempty"`
    AgentType      string `json:"agent_type,omitempty"` // "operator" | "driver:{step}" | "engine:*"
}
```

The hook reads the final assistant turn from `transcript_path` (last assistant message content blocks concatenated). Subagent turns are filtered by `agent_type` — see [open-questions](#open-questions).

**Artifact-shape detection** — two regexes (Go RE2 syntax, multiline mode `(?m)`):

1. **Path mention regex**:

   ```
   (?m)\.furrow/rows/[a-z0-9-]+/(definition\.yaml|plan\.json|spec\.md|summary\.md|research\.md|handoffs/[^\s]+\.md)
   ```

2. **Fenced-block-of-artifact-shape regex** (detects long fenced blocks that look like canonical artifacts even if no path is mentioned):

   ```
   (?ms)^```(?:yaml|json|md|markdown)?\s*\n((?:.*\n){30,})```\s*$
   ```

   Then the captured block's first 200 chars are matched against canonical-artifact heuristics:

   ```
   ^(objective:|deliverables:|gate_policy:|## Goals|## Non-Goals|## Acceptance|"step":|"row":|"target":\s*"(driver|engine):)
   ```

**Marker presence check** — within ~10 lines preceding any matched artifact-shaped region, the hook scans for:

```
(?m)^<!--\s*(ideate|research|plan|spec|decompose|implement|review|presentation):section:[a-z][a-z0-9-]*\s*-->\s*$
```

**Detection logic**:

- If artifact-shaped content matches AND no preceding marker is found within window → emit blocker `presentation_protocol_violation`.
- If markers are present → no emit.
- If no artifact-shaped content → no emit.

**Blocker emission** — uses `internal/cli/blocker_envelope.go` `Emit()` helper:

```go
env := blocker.Envelope{
    Code: "presentation_protocol_violation",
    Severity: "warn",
    ConfirmationPath: "silent",
    Path: transcriptPath,
    Detail: fmt.Sprintf("artifact-shaped content at line %d lacks <!-- {phase}:section:{name} --> marker", lineNo),
}
env.EmitJSON(os.Stdout)
return 0 // never exit non-zero — advisory only
```

Exit code is always 0; severity `warn` + `confirmation_path: silent` mean Claude does not surface to user; envelope is captured by hook telemetry only.

## claude-settings-addition

Exact JSON delta to `.claude/settings.json` — additive insert into the existing `Stop` array (D3 owns the PreToolUse `layer-guard` registration; D6 appends to `Stop` only):

```diff
   "Stop": [
     {
       "matcher": "",
       "hooks": [
         { "type": "command", "command": "frw hook work-check" },
         { "type": "command", "command": "frw hook stop-ideation" },
-        { "type": "command", "command": "frw hook validate-summary" }
+        { "type": "command", "command": "frw hook validate-summary" },
+        { "type": "command", "command": "furrow hook presentation-check" }
       ]
     }
   ],
```

Note: `furrow` (Go binary) per constraint #2; `frw` is the legacy shell wrapper. New hooks ship under `furrow hook *`.

## skill-retrofits

Additive paragraph appended to the **Supervised Transition Protocol** section of each of `skills/plan.md`, `skills/spec.md`, `skills/review.md` (verbatim, no content rewrite):

```markdown
**Presentation**: when surfacing this step's artifact for user review, render it
using the canonical mode defined in `skills/shared/presentation-protocol.md` —
section markers `<!-- presentation:section:{name} -->` immediately preceding
each section per the artifact's row in the protocol's section-break table. The
operator owns this rendering; phase drivers return structured results, not
user-facing markdown.
```

`skills/ideate.md` already uses the marker convention and is the source of truth — D6 makes ZERO content edits to it (constraint #19).

## commands-work-tmpl-presentation-section

Section to add to `commands/work.md.tmpl` (joint touch ordering: D4 → D2 → D3 → D6 last per constraint #10). Inserted before the closing of the operator instruction block:

```markdown
## Presentation

When you present row artifacts (`definition.yaml`, `plan.json`, `spec.md`,
`summary.md`, `research.md`, handoffs) to the user in conversation, follow
the canonical mode in `skills/shared/presentation-protocol.md`:

- Use section markers: `<!-- {phase}:section:{name} -->`.
- Phase prefix: current step name when drafting; `presentation` when surfacing
  for user review; `review` during the review step.
- One marker per section listed in the protocol's section-break table.
- Operator-only — drivers return structured phase results, not user markdown.

The advisory `furrow hook presentation-check` Stop hook flags missing markers
(severity warn, silent) for telemetry; it does not block your turn.
```

## blocker-code

YAML to append to `schemas/blocker-taxonomy.yaml` (additive after D3's codes per constraint #4 — appendix-only, no reordering):

```yaml
  - code: presentation_protocol_violation
    category: presentation
    severity: warn
    message_template: "{path}: artifact-shaped content lacks section markers ({detail})"
    remediation_hint: "Wrap each artifact section with <!-- {phase}:section:{name} --> per skills/shared/presentation-protocol.md"
    confirmation_path: silent
    applicable_steps: []
```

## acceptance

Refined ACs with WHEN/THEN scenarios. Each cites the source AC.

- **A1** (AC1): WHEN `skills/shared/presentation-protocol.md` exists THEN it specifies the single canonical mode `<!-- {phase}:section:{name} -->` and explicitly disallows full-file dumps and summary-with-link for in-conversation presentation. **Verify**: `grep -E '<!-- \{phase\}:section:\{name\} -->' skills/shared/presentation-protocol.md && grep -i 'disallowed' skills/shared/presentation-protocol.md`.
- **A2** (AC2): WHEN reading the protocol doc THEN the per-artifact section-break rules table is present and exhaustive for `definition.yaml`, `plan.json`, `spec.md`, `summary.md`, `research.md`, handoff artifacts. **Verify**: `grep -c '|.*|' skills/shared/presentation-protocol.md` returns ≥ 6 artifact rows.
- **A3** (AC3): WHEN an artifact is being drafted in step `S` THEN markers use `phase=S`. WHEN presented for review THEN `phase=presentation`. WHEN summarized in review step THEN `phase=review`. **Verify**: protocol doc enumerates these three rules.
- **A4** (AC4): WHEN `skills/shared/layer-protocol.md` (D2) is read THEN it cross-references `skills/shared/presentation-protocol.md` for the operator-only constraint. **Verify**: `grep presentation-protocol.md skills/shared/layer-protocol.md`.
- **A5** (AC5): WHEN `furrow hook presentation-check` receives stdin JSON describing an assistant turn containing artifact-shaped content with no preceding marker THEN it emits a `presentation_protocol_violation` envelope on stdout (severity `warn`, `confirmation_path: silent`) AND exits 0. **Verify**: `echo '<fixture-no-markers>' | furrow hook presentation-check | jq -r .code` returns `presentation_protocol_violation`; `$?` is 0.
- **A6** (AC5 inverse): WHEN the same content is wrapped with markers THEN the hook emits no envelope. **Verify**: `echo '<fixture-with-markers>' | furrow hook presentation-check` produces empty stdout.
- **A7** (AC6): WHEN `.claude/settings.json` is loaded THEN `furrow hook presentation-check` appears in the `Stop` hook array. **Verify**: `jq '.hooks.Stop[0].hooks[].command' .claude/settings.json | grep presentation-check`.
- **A8** (AC7): WHEN `schemas/blocker-taxonomy.yaml` is parsed THEN code `presentation_protocol_violation` is registered with `severity: warn`, `confirmation_path: silent`. **Verify**: `yq '.blockers[] | select(.code == "presentation_protocol_violation")' schemas/blocker-taxonomy.yaml` returns the entry.
- **A9** (AC8): WHEN reading `skills/{plan,spec,review}.md` THEN each contains an additive Presentation paragraph referencing `skills/shared/presentation-protocol.md` in its Supervised Transition Protocol section. `skills/ideate.md` is byte-identical to its W4 (D2) state. **Verify**: `grep -l presentation-protocol.md skills/plan.md skills/spec.md skills/review.md` returns 3 files; `git diff W4..W6 -- skills/ideate.md` is empty.
- **A10** (AC9): WHEN `commands/work.md.tmpl` is rendered THEN a `## Presentation` section pointing at the protocol exists. **Verify**: `grep '## Presentation' commands/work.md.tmpl`.
- **A11** (AC10): WHEN `tests/integration/test-presentation-protocol.sh` runs THEN it (a) replays a fixture transcript without markers and asserts the hook emits the expected blocker code; (b) replays a fixture with markers and asserts no emission. **Verify**: `bash tests/integration/test-presentation-protocol.sh` exits 0.
- **A12** (AC11): WHEN `go test ./...` runs THEN `internal/cli/hook/presentation_check_test.go` passes covering: artifact-detection regex true/false positives, marker-window scan, stdin JSON parse errors, envelope schema-conformance against `schemas/blocker-taxonomy.yaml`. **Verify**: `go test ./internal/cli/hook/...`.

## open-questions

1. **Operator-only enforcement scope** — the `agent_type` field in Claude Stop-hook input distinguishes operator vs subagent turns. Should the hook:
   - **(a)** scan only `agent_type == "operator"` turns (treating subagent artifact-output as out-of-band, not user-facing); OR
   - **(b)** scan all turns, since subagent output may bleed into the operator's transcript and reach the user; OR
   - **(c)** scan operator turns AND subagents whose `agent_type` matches `driver:*` (drivers return structured results to operator — if a driver is emitting markdown artifacts, that itself is a layer violation worth flagging)?

   **Lean**: (c) — operator turns get the protocol check; driver turns trigger if they produce artifact-shaped markdown at all (since drivers shouldn't render to user anyway, this doubles as a delegation-boundary signal). Engine turns are skipped (engines are Furrow-unaware; they can output anything in their sandbox). Decide at implementation; document final choice in the protocol doc and hook's godoc.

2. **Pi adapter Stop-hook equivalent** — Pi's `@tintinweb/pi-subagents` does not have a direct Stop analogue. Out of scope for D6 (Pi-side presentation enforcement) per the same Pi capability gap acknowledged for D3's layer-guard. Track as follow-up.

3. **Marker placement window** — fixed 10-line lookback before artifact content. Sufficient for typical formatting; revisit if false-negatives surface in fixture testing.

---

**Word count**: ~1450.
