# Context Construction Patterns

Architecture document for `internal/cli/context` — the canonical contract for
Furrow context assembly. Produced by D5 (W1); serves as binding reference for
D4's strategy implementations (W3).

---

## 1. Why patterns here

Furrow assembles context from multiple sources — step skills, references, prior
state, gate decisions, learnings — before delivering it to three distinct
targets: operator (Claude CC), driver (Pi), and engine (future runtime).
Without a structured contract, each new step or target produces a bespoke
loader: a shell `cat` here, a hard-coded path join there, a duplicate YAML
parse somewhere else.

Three symptoms confirmed the need for explicit patterns (audit evidence below):

1. **Scattered loading sites.** Step skill injection lives in `commands/work.md`
   (markdown prompt), `skills/work-context.md` (context budget doc), and
   `bin/frw.d/scripts/measure-context.sh` (shell budget enforcement) — three
   uncoordinated representations of the same rule.

2. **No idempotency guarantee.** `run-gate.sh` emits a prompt YAML by `cat`
   assembly with no mechanism to ensure that running the same gate twice
   produces the same context.

3. **No migration surface.** Adding a new step requires editing shell scripts,
   markdown prompts, and potentially Go CLI code independently. There is no
   single registration point.

The three patterns address these symptoms directly:

- **Builder** isolates schema evolution — one place to add a Bundle field.
- **Strategy** provides one registration point per step — one file to add.
- **ChainNode** provides a composable override mechanism — one node to insert
  per new layer (e.g., runtime-specific adapter filter).

---

## 2. Builder

`internal/cli/context.Builder` (Builder design pattern)

**Intent:** Strategies never construct `Bundle` literals directly. Bundle schema
evolution — adding fields, renaming, versioning — stays single-sourced through
the Builder implementation. Callers use `Add*` methods; `Build` materialises the
result once.

**Contract:**

| Invariant | Consequence of violation |
|-----------|--------------------------|
| `Reset` zeros all state | Stale data from previous step leaks into next |
| `Build` returns `ErrBuilderConsumed` on second call without Reset | Prevents silent duplicate emission |
| `Add*` methods preserve insertion order | Operator context is order-sensitive (layer ordering) |
| `AddArtifact` overwrites (not appends) | Only one prior-artifact snapshot per build |

**Usage pattern:**

```go
b := registry.NewBuilder(row, step, target)
if err := strategy.Apply(b, src); err != nil {
    return fmt.Errorf("apply strategy: %w", err)
}
bundle, err := b.Build()
```

**Conformance:** `TestBuilderConformance(t, factory)` in
`internal/cli/context/contracts.go` sub-tests: `reset_zeros_state`,
`build_returns_added_items`, `double_build_returns_err_consumed`,
`reset_after_build_allows_reuse`, `add_methods_preserve_insertion_order`.

---

## 3. Strategy

`internal/cli/context.Strategy` (Strategy design pattern)

**Intent:** Each workflow step's context rules are encapsulated in a single
Strategy implementation. Strategies plug into a central registry (D4-owned,
`internal/cli/context/strategies/`) without requiring conditional ladders.
Adding a new step means adding `strategies/{step}.go` — no existing file changes.

**Contract:**

| Invariant | Consequence of violation |
|-----------|--------------------------|
| `Step()` matches an entry in `evals/gates/` | Structural test fails; orphan or gap detected |
| `Apply` is idempotent on same source | Double-invocation produces duplicate context |
| `Apply` does not retain `b` reference after return | Builder lifecycle is caller-controlled |
| `Apply` returns error (not panic) on malformed input | Stack traces are non-recoverable in subagent context |

**Registration:** D4's `registry.go` maps `step → Strategy`; the structural
test in `internal/cli/context/structure_test.go` asserts one-to-one coverage
with `evals/gates/*.yaml`.

**Conformance:** `TestStrategyConformance(t, factory, src)` sub-tests:
`step_matches_registered_gate`, `apply_idempotent`, `apply_does_not_panic_on_empty_source`,
`apply_returns_err_when_source_missing_required_field`.

---

## 4. Chain of Responsibility

`internal/cli/context.ChainNode` (Chain of Responsibility design pattern)

**Intent:** Context assembly is layered: defaults → step rules → row overrides →
target filter. Each layer is self-contained as a ChainNode. New layers (e.g.,
a Pi-adapter filter that strips Claude-only tokens) plug in by node insertion
without touching existing nodes. The caller (D4's runner) walks the chain;
nodes do not self-walk.

**Layer ordering (planned):**

```
DefaultsNode  →  StepStrategyNode  →  RowOverridesNode  →  TargetFilterNode  →  nil
```

**Contract:**

| Invariant | Consequence of violation |
|-----------|--------------------------|
| `Next() == nil` terminates the chain | Caller must stop; infinite loops possible otherwise |
| `Apply` does NOT call `Next().Apply` | Caller controls chain walk; double-application possible otherwise |
| `Apply` is idempotent when source unchanged | Retry safety — D4 runner may retry on transient errors |
| Nodes are stateless | Concurrent row builds would share mutable state |

**Conformance:** `TestChainNodeConformance(t, factory, src)` sub-tests:
`next_nil_terminates`, `apply_does_not_walk_chain`, `apply_idempotent_when_source_unchanged`.

---

## 5. When to add a new strategy

Add a new Strategy when a new workflow step is introduced in `evals/gates/`.

**Checklist:**

1. Create `evals/gates/{step}.yaml` with the gate evaluation dimensions.
2. Create `internal/cli/context/strategies/{step}.go` in package `context`.
3. Implement `Strategy` interface; cite the strategy pattern in godoc.
4. Register in `internal/cli/context/registry.go` (D4-owned).
5. Add a test in `internal/cli/context/strategies/{step}_test.go` that calls
   `TestStrategyConformance(t, factory, fixture)`.
6. Run `go test -run TestStructure ./internal/cli/context/...` — must pass.
7. Run `FURROW_STRUCTURE_TEST_REQUIRE_STRATEGIES=1 go test -run TestStructure ./internal/cli/context/...` — must pass after adding the strategy file.

**Do NOT** add step logic to an existing strategy. Do NOT add a `case` in a
`switch` — that is the conditional ladder the pattern eliminates.

**ChainNode nodes** are added when a new override layer is needed across all
steps (e.g., a new target type). A new step-specific override goes into that
step's Strategy, not a new ChainNode.

---

## 6. Audit table — ad-hoc context-loading sites

Every existing site that loads step skills, references, or context artifacts
is enumerated below. Sites migrated in D4 (W3) are marked `D4 (W3)`. Sites
out of D4's scope become explicit follow-up TODOs (slugs registered in
`.furrow/almanac/todos.yaml` at row close).

Grep-verification: every `file:line` below was confirmed with `grep -n` before
inclusion.

| File:line | Current Mechanism | Target Pattern | Migration Owner |
|-----------|-------------------|----------------|-----------------|
| `commands/work.md:25` | `rws load-step "{name}"` — shell command injects current step skill into Claude CC context at route-1 switch | Strategy via `furrow context for-step --target operator` | D4 (W3) |
| `commands/work.md:43` | Inline markdown: `Read and follow skills/ideate.md` — hardcoded step name, no registry | Strategy (ideate) via `furrow context for-step --target operator` | D4 (W3) |
| `commands/work.md:72` | `rws load-step "{name}"` — same as line 25, at route-3 continuation | Strategy via `furrow context for-step --target operator` | D4 (W3) |
| `skills/work-context.md:71` | Static doc text: `skills/{step}.md` named as the step skill location — informational only, not a loader | Builder result documents the resolved path; doc updated to reference pattern | follow-up TODO `migrate-work-context-skill-doc` |
| `skills/work-context.md:91` | Static doc text: step skill loading convention (`Only the current step's skill is active`) — informational | Builder layer field (`Layer: "step"`) encodes this; doc updated at row close | follow-up TODO `migrate-work-context-skill-doc` |
| `skills/work-context.md:137-146` | Static reference list: `references/` files enumerated — informational, not a loader | `ContextSource.ListReferences()` + Builder; references resolved by Strategy per step | follow-up TODO `migrate-work-context-skill-doc` |
| `bin/frw.d/scripts/measure-context.sh:39` | `count_lines "$ROOT/skills/work-context.md"` — shell line count for budget enforcement | Not a context loader; budget enforcement stays in shell (out of scope) | follow-up TODO `migrate-measure-context-to-cli` |
| `bin/frw.d/scripts/measure-context.sh:46` | `step_file="$ROOT/skills/${step}.md"` — iterates 7 step files, counts lines for budget | Not a context loader; budget enforcement stays in shell (out of scope) | follow-up TODO `migrate-measure-context-to-cli` |
| `bin/frw.d/scripts/measure-context.sh:65-66` | `for f in "$ROOT/skills/shared"/*.md` — counts shared skill lines for budget | Budget enforcement only; Strategy.ListSkills() loads shared skills at runtime | follow-up TODO `migrate-measure-context-to-cli` |
| `bin/frw.d/scripts/run-gate.sh:141` | Comment: `skills/shared/gate-evaluator.md` — documents evaluator skill path | Not a loader; prompt YAML construction; evaluator skill path → Strategy meta | follow-up TODO `migrate-run-gate-evaluator-skill` |
| `bin/frw.d/scripts/run-gate.sh:166` | `evaluator_skill: ${FURROW_ROOT}/skills/shared/gate-evaluator.md` — emits evaluator skill path into prompt YAML | Strategy + ChainNode (target filter for gate-evaluator subagent target) | follow-up TODO `migrate-run-gate-evaluator-skill` |
| `bin/frw.d/scripts/doctor.sh:141` | `_sf="$ROOT/skills/${_step}.md"` — verifies step skill exists for each of 7 steps | Doctor validation; not a context loader; stays in shell | follow-up TODO `migrate-doctor-skill-check` |
| `bin/frw.d/scripts/doctor.sh:159-160` | `cat "$ROOT"/skills/*.md` — reads all step skills for dedup check | Doctor validation only; not a context loader; stays in shell | follow-up TODO `migrate-doctor-skill-check` |

### Summary

| Owner | Count |
|-------|-------|
| D4 (W3) | 3 |
| follow-up TODO | 11 |

**D4 migrations (3 sites):** the three `commands/work.md` call sites where
`rws load-step` and the hardcoded `skills/ideate.md` read drive real context
into the operator target. These are the primary migration targets for the
`furrow context for-step` CLI command D4 implements.

**Follow-up TODOs (11 sites):** shell budget scripts (`measure-context.sh`,
`doctor.sh`) and informational markdown docs (`work-context.md`) are not
context loaders in the runtime sense — they enumerate or validate files, not
assemble context for a target. Migrating them is valuable but out of D4's
scope. TODOs registered at row close: `migrate-work-context-skill-doc`,
`migrate-measure-context-to-cli`, `migrate-run-gate-evaluator-skill`,
`migrate-doctor-skill-check`.
