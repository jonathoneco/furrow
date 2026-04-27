# D4 — Context Routing CLI Spec

Deliverable: `context-routing-cli` (W3, depends_on `context-construction-patterns` / D5).
ACs sourced from `definition.yaml` (lines 64-101).

## Goals

- Replace ad-hoc skill/artifact loading with a single primitive: `furrow context for-step`.
- Emit a structured, layer-filtered context bundle conforming to a JSON Schema.
- Implement D5's Builder/Strategy/ChainNode interfaces with one Strategy per step (AC §3, §4).
- Provide the priming-message body for D2 (operator→driver) and the curation source for D1 (driver→engine via handoff render).

## Non-goals

- No state mutation (`state.json`, `summary.md`) — pure read+emit (constraint #13).
- No persona/agent identity awareness — `--target` selects a layer label, nothing more.
- No Claude/Pi runtime concepts — backend-runtime-agnostic (constraint #3).
- No skill front-matter validation here — D3 owns `furrow validate skill-layers` and the `skill_layer_unset` blocker code; D4 only consumes layer tags and emits the same code at load time when missing.

## Approach

`internal/cli/context/` package with:

- `builder.go` — implements `D5.Builder`. Mutable bundle accumulator; `Reset()` zeros state; `Build()` returns immutable `Bundle` value + JSON-serializable.
- `chain.go` — `ChainNode` linked-list applying override layers in fixed order: defaults → step-strategy → row-overrides → target-filter. Each node returns `Next()` and idempotently `Apply(b, src)`.
- `registry.go` — `init()`-registered Strategy map keyed by step name; lookup fails fast if step absent (asserted by D5's `structure_test.go`).
- `strategies/{step}.go` — one file per gate in `evals/gates/*.yaml` (7 files: ideate, research, plan, spec, decompose, implement, review). Each registers via package `init()`. Godoc cites Strategy pattern + step's role in the workflow.
- `cmd.go` — Cobra subcommand wiring. Registered into `internal/cli/app.go` `context` group (joint touch with D1 `handoff` group; sequential per wave plan, AC §13).

## Bundle Schema (`schemas/context-bundle.schema.json`)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://furrow.dev/schemas/context-bundle.schema.json",
  "type": "object",
  "additionalProperties": false,
  "required": ["row", "step", "target", "skills", "references", "prior_artifacts", "decisions"],
  "properties": {
    "row":    { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
    "step":   { "type": "string", "enum": ["ideate","research","plan","spec","decompose","implement","review"] },
    "target": { "type": "string", "pattern": "^(operator|driver|engine|specialist:[a-z][a-z0-9-]*)$" },
    "skills": {
      "type": "array",
      "items": {
        "type": "object", "additionalProperties": false,
        "required": ["path", "layer", "content"],
        "properties": {
          "path":    { "type": "string" },
          "layer":   { "type": "string", "enum": ["operator","driver","engine","shared"] },
          "content": { "type": "string" }
        }
      }
    },
    "references": {
      "type": "array",
      "items": {
        "type": "object", "additionalProperties": false,
        "required": ["path"],
        "properties": {
          "path":    { "type": "string" },
          "content": { "type": "string" }
        }
      }
    },
    "prior_artifacts": {
      "type": "object", "additionalProperties": false,
      "required": ["state","summary_sections","gate_evidence","learnings"],
      "properties": {
        "state":            { "type": "object" },
        "summary_sections": { "type": "object", "additionalProperties": { "type": "string" } },
        "gate_evidence":    { "type": "array",  "items": { "type": "object" } },
        "learnings":        { "type": "array",  "items": { "type": "object" } }
      }
    },
    "decisions": {
      "type": "array",
      "items": {
        "type": "object", "additionalProperties": false,
        "required": ["source","from_step","to_step","outcome","rationale","ordinal"],
        "properties": {
          "source":    { "enum": ["settled_decisions","key_findings_prose"] },
          "from_step": { "type": "string" },
          "to_step":   { "type": "string" },
          "outcome":   { "enum": ["pass","fail","unknown"] },
          "rationale": { "type": "string" },
          "ordinal":   { "type": "integer", "minimum": 0 }
        }
      }
    }
  }
}
```

> **Reconciled post-archive**: `step_strategy_metadata` (originally listed as the
> 8th required key + open-typed object) was removed. Speculative forward-compat
> field with no consumer; per D5/D4 OQ #1 disposition. See commit `eb2a43f`.

`additionalProperties:false` at every level (constraint pattern from `schemas/definition.schema.json`).

## Strategies (one per step)

Each Strategy's `Apply(b Builder, src ContextSource)` does:

- **ideate.go** — loads `skills/ideate.md` (driver/operator-tagged copy filtered by target); pulls `definition.yaml` (objective, deliverable names only — no ACs yet); empty `decisions`. Metadata: `{is_first_step: true}`.
- **research.go** — loads `skills/research.md`; pulls prior `state.json` ideate evidence; empty `prior_artifacts.gate_evidence` for ideate; surfaces ideate's `summary.md` Open Questions section. Metadata: `{topic_count: <int>}`.
- **plan.go** — loads `skills/plan.md`; pulls `research/synthesis.md` + per-topic research files via glob; surfaces ideate→research decision. Metadata: `{has_research: bool}`.
- **spec.go** — loads `skills/spec.md`; pulls `plan.json`, all research artifacts, decisions through plan. Metadata: `{deliverable_count: <int>}`.
- **decompose.go** — loads `skills/decompose.md`; pulls all spec files in `specs/`; decisions through spec. Metadata: `{spec_count: <int>}`.
- **implement.go** — loads `skills/implement.md` + all `specs/*.md` for current wave; pulls `plan.json` waves; decisions through decompose; gate evidence accumulated. Metadata: `{wave: <int>, deliverables: [...]}`.
- **review.go** — loads `skills/review.md`; pulls full `summary.md` + `reviews/` directory + complete decision history; learnings filtered per target. Metadata: `{review_round: <int>}`.

Each strategy's godoc opens with: `// {Step}Strategy implements the Strategy pattern (D5 contract) for the {step} step. ...`. Idempotent on identical `(row,step,target)` inputs (D5 conformance harness asserts).

## Target Filtering

Filter applied as terminal `ChainNode` after strategy assembly:

| `--target`         | `skills` filter                                              | `learnings` filter                | extras                                   |
| ------------------ | ------------------------------------------------------------ | --------------------------------- | ---------------------------------------- |
| `operator`         | `layer in {operator, shared}`                                | all                               | `commands/work.md` content               |
| `driver` (default) | `layer in {driver, shared}`                                  | all                               | step-strategy default                    |
| `engine`           | `layer in {engine, shared}`                                  | `broadly_applicable: true` only   | NO `.furrow/` paths in references        |
| `specialist:{id}`  | `layer in {engine, shared}` + `specialists/{id}.md` injected | `broadly_applicable: true` only   | NO `.furrow/` paths in references        |

Skills without a `layer:` front-matter key fail-load with blocker code `skill_layer_unset` (registered by D3, AC §5). Engine/specialist target additionally strips any `references[*].path` matching `^\.furrow/` to maintain Furrow-unaware constraint #8 — defense in depth alongside D1's EngineHandoff schema rejection.

## Decisions Extraction

Implements T3 finding (49/49 conformance):

```go
var settledRe = regexp.MustCompile(`^- \*\*([a-z_]+)->([a-z_]+)\*\*: (pass|fail) — (.*)$`)
var fallbackRe = regexp.MustCompile(`^- (?:Decision|DECISION): (.+)$`)
```

Algorithm:

1. Open `summary.md`. Locate `## Settled Decisions` heading (line-oriented scan).
2. Until next `^## ` heading: each line matched by `settledRe` → emit `{source: "settled_decisions", from_step, to_step, outcome, rationale, ordinal: i++}`. Non-matching lines inside the section are silently skipped (handles blank lines, stray prose).
3. Locate `## Key Findings`. Each line matching `fallbackRe` → emit `{source: "key_findings_prose", from_step: <current state.json step>, to_step: <current step>, outcome: "unknown", rationale, ordinal: continues}`.
4. **De-dup**: gate-retries (same `from_step+to_step` pair appearing more than once) collapse to **last-wins, preserving original-position ordinal of the surviving entry** — so a re-run that ultimately passed shows up where the first attempt was, not at the end. Non-retry entries pass through unchanged. Test fixture: `model-routing` (2 `plan->spec`) and `post-merge-cleanup` (3 `research->plan`).

Conformance test (`strategies_test.go`): runs extractor against the 7 historic populated rows from T3 research and asserts ≥49 entries returned, all four regex groups non-empty, all `outcome ∈ {pass,fail}`.

## Performance

- Performance budget: AC §9 — <500 ms cold on the reference fixture (a 7-step row).
- Measured cold-run wall-clock on the reference fixture: 4 ms — the budget is met by an order of magnitude without a caching layer.

> **Reconciled post-archive**: this section originally specified a full caching
> layer (`.furrow/cache/context-bundles/{sha256}.json` with sha256-keyed
> bundles, 8-hex-prefix shard dirs, mtime-based invalidation, atomic
> temp-rename writes, edge-case handling for concurrent writers / clock skew /
> missing inputs, and a <50 ms cache-hit target). The cache was stripped after
> empirical measurement showed cold-run perf was already 125× under budget;
> the cache surface added failure modes (stale-cache risk, low-resolution-mtime
> fallback OQ, gitignore gap, row-isolation drift) without earning meaningful
> wall-clock savings. Determinism (identical inputs → identical bytes) is now
> verified by the integration test directly. See commit `60dc80b`.

## CLI Surface

```
furrow context for-step <step>
    --row <name>         (default: focused row from .furrow/focus)
    --target <t>         (default: driver; t in {operator,driver,engine,specialist:<id>})
    --json               (default true; reserved for future text-mode rendering)
```

Exit codes: `0` success; `2` usage; `3` blocker emitted (envelope on stdout, code on stderr); `1` internal error.

JSON envelope on success: the bundle object directly (no wrapping) — keeps `jq` integration trivial.

JSON envelope on failure: blocker envelope per pre-write-validation-go-first pattern: `{ "blocker": { "code": "...", "message": "...", "context": {...}, "confirmation_path": "..." } }`. Codes used: `skill_layer_unset` (D3-registered), `context_input_missing`, `context_strategy_unregistered` (the latter two registered as part of D4's wave append — appendix-only addition to `schemas/blocker-taxonomy.yaml` per joint-ownership ordering).

## Integration with D5

- D4 strategies plug into D5's exported `contracts_test.ConformanceHarness(t, strategy)` (AC §7 of D5). Wave 3 review runs the harness against all 7 strategies — failing strategies block W3 review, surfacing D5 contract gaps.
- Each strategy's godoc opens with `// implements D5 Strategy pattern; see internal/cli/context/contracts.go` and names the design pattern.
- D4's `registry.go` is exercised by D5's `structure_test.go` (asserts one strategy file per gate in `evals/gates/`).

## `commands/work.md.tmpl` Edits

Replace direct skill reads with shell-out:

```
# Before (operator skill body):
Read skills/{{ .Step }}.md
Read skills/work-context.md

# After:
exec: furrow context for-step {{ .Step }} --target operator --json
The bundle's `skills[]` array supplies your driver brief, work-context, and any
shared layer skills. Render `prior_artifacts.summary_sections` for context recovery.
```

Joint-touch order per constraint #10: D4 (W3) is the FIRST writer to `commands/work.md.tmpl`. D2 (W4) appends layered dispatch; D3 (W5) layer-context wrapper; D6 (W6) presentation section. D4 leaves the file ready for D2's additions — minimal scaffolding, no orphan template variables.

## Acceptance Scenarios (WHEN/THEN)

- **AC §1 (command exists)** — WHEN `furrow context for-step plan --target driver --row pre-write-validation-go-first --json` runs, THEN exit 0, stdout is a JSON object validating against `schemas/context-bundle.schema.json`. Verify: `furrow context for-step plan --target driver --row pre-write-validation-go-first --json | jq -e '.target == "driver"'`.
- **AC §2 (schema)** — WHEN bundle includes any non-required key, THEN `additionalProperties:false` rejection at validate-time. Verify: `bin/frw validate-schema schemas/context-bundle.schema.json <(furrow context for-step research --target driver --row test-fixture --json)`.
- **AC §5 (target filter)** — WHEN `--target=engine`, THEN `.skills[] | select(.layer=="operator")` is empty AND `.references[] | select(.path | startswith(".furrow/"))` is empty. Verify: `furrow context for-step research --target engine --row test-fixture --json | jq -e '[.skills[] | select(.layer=="operator")] | length == 0'`.
- **AC §5 (skill_layer_unset)** — WHEN a skill file lacks `layer:` front-matter, THEN exit 3, blocker code `skill_layer_unset` on stderr. Verify: fixture row with one stripped skill; assert exit code.
- **AC §6 (decisions)** — WHEN summary.md contains 7 gate-transition entries with one retry, THEN `.decisions | length == 6` (last-wins) AND ordinal preserves first-occurrence position. Verify against `pre-write-validation-go-first` row.
- **AC §7 (learnings filter)** — WHEN `--target=engine`, THEN `.prior_artifacts.learnings[] | select(.broadly_applicable == false) | length == 0`. Verify with seeded learnings.jsonl fixture.
- **AC §9 (perf)** — WHEN bundle generation runs against the reference fixture, THEN wall-clock < 500ms. Verify: `time furrow context for-step implement --target driver --row test-fixture`. (Reconciled post-archive: removed `--no-cache` flag and "cold cache" wording; cache layer was stripped — see commit `60dc80b`.)
- **AC §10 (determinism)** — WHEN identical inputs, THEN identical output bytes. Verify: `diff <(furrow context for-step ...) <(furrow context for-step ...)` empty. (Reconciled post-archive: was originally cache-identity test with mtime invalidation; rewritten as pure determinism test after cache strip.)
- **AC §12 (integration)** — WHEN tests/integration/test-context-routing.sh runs end-to-end, THEN bundle from `furrow context for-step plan --target driver` round-trips through `furrow handoff render --target driver:plan` (D1) producing a renderable handoff. Note grammar: D4 takes step as positional (`for-step <step>`) + `--target` is layer-only (`driver|engine|operator|specialist:{id}`); D1 takes target as combined layer+step (`driver:{step}|engine:{id}`) since it has no separate step argument. Script exits 0.
- **AC §13 (app registration)** — WHEN `furrow context --help` runs, THEN exit 0 listing `for-step`. Asserts joint-ownership ordering of `internal/cli/app.go` (D1's `handoff` already registered).
- **AC §14 (tests)** — `go test ./internal/cli/context/... && go test ./...` passes.

## Open Questions

1. Should `--target=specialist:{id}` validate that `specialists/{id}.md` exists, or fail-soft with empty injection? Lean: hard fail with `context_input_missing` blocker — silent fail risks engines getting under-curated context, violating constraint #8 spirit.

> **Reconciled post-archive**: two original OQs were resolved by removal — (1) `step_strategy_metadata` JSON Schema typing (the field was stripped entirely; see commit `eb2a43f`), and (2) cache eviction policy (cache layer was stripped; see commit `60dc80b`).

---

## Summary (≤150 words)

**Top 3 implementation risks** (original): (1) **Cache invalidation correctness** — mtime-based heuristic risks stale bundles when an input file is rewritten with identical content but newer mtime, or when filesystem timestamps lose resolution; mitigated by content-hash key (changes only when bytes change) plus mtime as fast-path early-exit. (2) **Joint app.go register order with D1** — D4 must land after D1's `handoff` group; W3 sequential wave plan enforces. (3) **D5 contract drift** — strategies plug into D5's harness during W3 review; if D5's `Apply` signature shifts, all 7 strategies need update; mitigated by in-row D5-before-D4 ordering and conformance harness as gate.

> **Reconciled post-archive**: risk (1) is moot — the cache layer was stripped after empirical perf measurement (4 ms cold << 500 ms budget). See commit `60dc80b`.

**Decisions extraction conformance plan**: Test-fixture: T3's 7 populated rows replayed in `strategies_test.go`; assertion: 49 entries extracted, 100% regex match, retries collapsed last-wins with first-position ordinal. Add the current row to fixtures post-archive.
