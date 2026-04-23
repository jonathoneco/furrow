# Plan Step — Phase 3: Schema-level improvement design

**Row**: `agent-host-portability-research`
**Step**: plan
**Phase**: 3 of 4
**Purpose**: Design the three schema-level improvements we're keeping in this row (per P-3 split). Behavior-level improvements are in almanac TODOs.

In-scope for this row (host-independent, apply to CC + Pi automatically via core):

- **Typed JSON-Schema blocks for almanac** (rationale, roadmap, todos + potentially seeds)
- **Typed `produces:` outputs per deliverable** (in definition.yaml)
- **Specialist YAML-contract-layer frontmatter** (including `dispatch:` from P2-3)

Answer inline. One-liners or "agree with lean" fine.

---

## P3-1 — Almanac schema location + enforcement

Where do the per-block schemas live, and when do they run?

- **(a) Schemas in `schemas/`** (alongside existing `definition.schema.json`, `state.schema.json`, etc.); `alm` enforces at pre-write time.
  - Pro: single schemas/ directory; matches existing pattern.
  - Con: top-level `schemas/` grows.

- **(b) Schemas in `.furrow/almanac/schemas/`** (co-located with the blocks they describe); `alm` enforces at pre-write time.
  - Pro: local to the data; self-describing directory.
  - Con: schemas are harness-level, not user-data-level — arguably belong with other schemas.

- **(c) Schemas in `schemas/` + validate at write time + also at load time in `alm list/show/query`** (defense in depth).
  - Pro: catches schema drift introduced by manual edits (the exact problem we just hit).
  - Con: slower reads; more failure surfaces.

**My lean: (c)**. The schema-drift problem we hit this turn (todos.yaml `open_questions` field not in schema) is exactly what defense-in-depth catches. The small read-time cost is worth the early-detection.

> YOUR ANSWER: Agreed

---

## P3-2 — Almanac migration strategy for existing entries

Existing almanac files have entries that don't conform (todos.yaml has `open_questions`, entry 67 had `decision` source_type pre-fix).

- **(a) Strict: fail loud on non-conforming entries** — run a one-time normalization pass, then enforce strict going forward.
  - Pro: clean slate.
  - Con: normalization is a destructive pass; might lose intent from bad entries.

- **(b) Permissive bootstrap**: add `schema_version` field per entry; old entries grandfathered at v1, new ones v2+ must conform.
  - Pro: no data loss; gradual migration.
  - Con: v1 stays forever; drift continues.

- **(c) Document-then-normalize**: freeze almanac writes except via `alm`, run normalization script, commit, re-enable writes strict.
  - Pro: closes the drift door; single explicit migration.
  - Con: requires the normalization script to preserve intent.

**My lean: (c)**. We have the drift evidence; clean it once and prevent recurrence. The `alm` CLI already wants to be the sole writer — just enforce that.

> YOUR ANSWER: Agreed

---

## P3-3 — Typed `produces:` schema shape

How does a deliverable declare its typed outputs?

- **(a) Flat map**: `produces: { interface_spec: docs/architecture/pi-adapter-interface.md, pi_binding: adapters/pi/src/index.ts }`
  - Pro: simple.
  - Con: no metadata (required/optional, content check, generator).

- **(b) Array of objects**: `produces: [{ name: interface_spec, path: docs/..., required: true }, ...]`
  - Pro: extensible (can add fields later).
  - Con: more verbose.

- **(c) Map with structured values**: `produces: { interface_spec: { path: docs/..., required: true, content_check: optional-schema-id } }`
  - Pro: keyed lookup + metadata.
  - Con: nested YAML; harder to skim.

**My lean: (c)**. Matches the dict-of-structs pattern used for deliverables. Extensibility wins as we inevitably add `required`, `content_check`, `generator`, etc.

> YOUR ANSWER: Agreed

---

## P3-4 — Relationship between `produces:` and existing `file_ownership:`

Deliverables today use `file_ownership` (a list of globs). `produces:` introduces a new contract.

- **(a) `produces:` replaces `file_ownership:`**. Glob list becomes the set of paths produces-declared.
  - Pro: single source of truth.
  - Con: loses glob flexibility (e.g., `adapters/pi/**`); breaking change.

- **(b) `produces:` complements `file_ownership:`**. Ownership = write scope (broad); produces = specific artifacts (narrow, verifiable).
  - Pro: additive, no breaking change.
  - Con: two fields to keep aligned.

- **(c) `produces:` is optional, `file_ownership:` required**. Adoption is opt-in per deliverable.
  - Pro: gradual rollout.
  - Con: most deliverables won't adopt; value is diluted.

**My lean: (b) complements**. `file_ownership:` is the _area_ (`adapters/pi/**`) that a specialist can write to; `produces:` is the _artifact contract_ (`adapters/pi/src/index.ts` must exist and conform). Different semantics.

> YOUR ANSWER: Agreed

---

## P3-5 — Review-step verification of `produces:`

When a deliverable is reviewed, what does the review step check?

- **(a) Existence only**: every `produces:` path must exist on disk.
- **(b) Existence + content_check** (if declared): path exists, AND if `content_check` is set, content matches (schema / grep / LSP / user-defined).
- **(c) Existence + structural diff**: compare produces-declared paths against actual files written in this row's session. Flag missing (declared-but-not-written) and surprise (written-but-not-declared).

**My lean: (c)**. The bidirectional check catches "forgot to write the spec" AND "wrote to a file outside the contract." Matches Furrow's correction-limit philosophy of hard-blocking drift.

> YOUR ANSWER: Agreed

---

## P3-6 — Specialist YAML-contract-layer frontmatter keys

At minimum `dispatch:` (from P2-3). What else should the frontmatter include?

Proposed set:

```yaml
---
name: api-designer
description: HTTP API design — resource modeling, error handling, backward compatibility
dispatch:
  model_hint: sonnet # existing
  effort_hint: medium # per existing roadmap TODO
  prompt_mode: replace # per P2-3
  skills: false
  inherit_context: false
  disallowed_tools: [write, edit, bash]
consumes: # OPTIONAL: what context the specialist expects
  - path: docs/architecture/**
    purpose: read-only reference
produces: # OPTIONAL: what the specialist writes
  - file_pattern: docs/architecture/api-design-*.md
    required: true
---
```

- **(a) Minimal — just `dispatch:` + existing `model_hint`**. Add others later.
- **(b) Full — add `consumes:` + `produces:` now** so the contract is complete.
- **(c) Minimal + opt-in advanced** — core is `dispatch:` + `model_hint:`; `consumes:`/`produces:` are optional.

**My lean: (c)**. `dispatch:` is load-bearing for Pi subagent use. `consumes:`/`produces:` are valuable but can be backfilled per specialist as needs arise. Existing 22 specialists get `dispatch:` defaults; advanced keys opt-in.

> YOUR ANSWER: Agreed

---

## P3-7 — Existing specialist migration

22 existing specialists need `dispatch:` frontmatter. How?

- **(a) Script-generated defaults** — one-shot script reads existing `model_hint:`, emits `dispatch:` block with defaults for the 4 other keys. Commits per specialist.
  - Pro: fast; audit-friendly via git history.
  - Con: defaults may be wrong for some specialists (e.g., security-engineer may need bash access).

- **(b) Per-specialist hand-written** — review each of 22, author appropriate `dispatch:` per specialist's role.
  - Pro: correct per specialist.
  - Con: 22-way work; tedious.

- **(c) Script + review** — script emits defaults; human review pass on the 22 PRs/commits before merge. Flag any that need manual tuning.
  - Pro: scales; catches outliers.
  - Con: still tedious but focused.

**My lean: (c)**. Let a subagent generate defaults, human reviews. Pair with validation test that all 22 parse + dispatch correctly.

> YOUR ANSWER: Agreed

---

## P3-8 — Validation surface for specialist frontmatter

Where does specialist frontmatter validation live?

- **(a) `alm specialists validate`** — new alm subcommand that loads all specialists and checks each against a schema.
- **(b) At dispatch-time in the TS adapter** — Pi adapter reads specialist markdown, validates frontmatter when resolving a specialist name, errors early on mismatch.
- **(c) Both**: `alm specialists validate` for CI/audit, adapter validates at dispatch-time as defense-in-depth.

**My lean: (c)**. Matches the P3-1 defense-in-depth pattern. Write-time validation via `alm`, runtime validation at adapter boundary.

> YOUR ANSWER: Agreed

---

## What comes next after Phase 3 is locked

- **Phase 4** — `plan.json` with wave ordering, `team-plan.md` with specialist assignments per deliverable, dual-reviewer dispatch (fresh Claude + codex), transition research → plan (wait, we're IN plan — transition plan → spec).
