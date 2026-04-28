---
layer: shared
---
# Specialist Delegation Protocol (Driver→Engine)

**Audience**: phase drivers. This document replaces the former operator→specialist
framing. Operators do not delegate directly to engines — drivers do.

Cross-reference: `skills/shared/layer-protocol.md` for layer boundaries and definitions.

---

## Why This Exists

Engines run Furrow-unaware. They receive no row context, no step reference, no
`.furrow/` paths. The **driver bears curation responsibility**: it must distil the
relevant work context into a clean `EngineHandoff` (D1 schema) before dispatch.

---

## Composing an Engine Team at Dispatch

One driver may dispatch **N engines in parallel** for a single deliverable. Team
membership is decided **per-dispatch**, not per-plan. `plan.json`'s `specialist:` field
is a hint — use it as a starting point but adapt to the work at hand.

Composition guidelines:
- **Solo engine**: one deliverable, single domain, self-contained — dispatch one engine.
- **Parallel engines**: one deliverable spanning multiple domains (e.g., implementation + tests)
  — dispatch parallel engines with disjoint `file_ownership`.
- **Sequential engines**: deliverable where output of engine A feeds engine B — dispatch
  serially, passing engine A's EOS-report as grounding to engine B.
- **Team size**: prefer 1-3 engines per deliverable. Coordination cost rises with team size.

---

## Dispatch Primitive

Specialists are skill briefs, not registered agent types. The runtime agent type
is `engine` (or the adapter's engine equivalent); `specialist:{id}` selects the
skill/brief used to prime that engine.

Build and dispatch an engine handoff:

```sh
furrow handoff render \
  --target engine:specialist:{id} \
  --row <row-name> \
  --step <step> \
  [--write]
```

This renders an `EngineHandoff` markdown document. The driver provides the structured
value (objective, deliverables, constraints, grounding) via stdin or args. D1's schema
enforces that no `.furrow/` paths and no Furrow vocab appear in the output.

Runtime spawn primitive receives the rendered markdown as the engine's input:
- Claude: `Agent(subagent_type="engine", prompt=<rendered-handoff plus specialist skill brief>)`
- Pi: `pi-subagents spawn({name: "engine:{id}", systemPrompt: <specialist-brief>, tools: <allowlist>})`
  then `pi-subagents sendMessage(handle, <rendered-handoff>)`

---

## Curation Checklist

Before dispatching an engine, verify:

- [ ] **Grounding paths** are source-tree relative (no `.furrow/` in any path).
- [ ] **Constraints** use engine-scoped vocabulary — no `rws`, `alm`, `blocker`, `gate_policy`,
  `deliverable`, `almanac`, `step`, `row`.
- [ ] **Objective** is task-scoped, not row-scoped. No mention of Furrow row or step.
- [ ] **Deliverables** enumerate `file_ownership` globs and `acceptance_criteria`.
- [ ] **return_format** references a schema in `templates/handoffs/return-formats/`.

If any check fails, revise the handoff before dispatch. Do not trust that schema
validation alone will catch all curation errors — the schema enforces structure,
not correctness.

---

## Return Contract

Engines return an EOS-report per `templates/handoffs/return-formats/{step}.json`.
The driver:

1. Collects EOS-reports from all engines in the team.
2. Assembles a per-deliverable rollup (merging findings, artifacts, open questions).
3. Returns the phase result to the operator via runtime primitive
   (Claude: `SendMessage` to operator lead; Pi: agent return value).

The operator is responsible for presenting phase results to the user per
`skills/shared/presentation-protocol.md` (D6). Drivers do NOT address the user.

---

## Driver Dispatches — Not the Operator

```
operator  ──spawn + prime──▶  driver
                               driver  ──handoff──▶  engine(s)
                               driver  ◀──EOS-report──
operator  ◀──phase result──  driver
```

The operator does not know which engines were dispatched, how many ran in parallel,
or what their individual EOS-reports contained. It receives only the assembled phase
result from the driver. This keeps operator context lean and engine details encapsulated.
