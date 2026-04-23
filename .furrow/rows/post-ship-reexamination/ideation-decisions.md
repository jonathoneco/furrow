# post-ship-reexamination — Ideation Decisions

Comment inline. Answers to Decisions 1–4 will drive `definition.yaml`.

## Context (summary)

Two TODOs in Phase 1:

- **`post-merge-watch-list`** — track behavioral signals to validate after rows merge (watch items: "does dual-review actually produce useful findings on real rows?", "do step agents actually dispatch?", "cost delta per row?").
- **`decision-review-todo-type`** — design a TODO type (or something) for post-evidence re-examination: trigger → review question → acceptance criteria. Today `source_type: "decision-review"` exists as a workaround; `re-evaluate-dispatch-enforcement` uses it in the wild.

Roadmap rationale: _"Both design a structured primitive for 'after X ships, re-examine Y.' Watch-list is almanac-level; decision-review is TODO-schema-level — unifying the design may produce one primitive instead of two competing ones."_

---

## Step 1 — Brainstorm

Three angles on the shape of the solution:

**(A) Unified primitive** — one "observation" concept; both watch-items and decision-reviews are instances of the same `trigger → observe → resolve` shape. Build one primitive (e.g., `observations.yaml` or fields on TODO) that covers both.

**(B) Two distinct primitives** — keep them separate. Watch-list items are lightweight signal-tracking (boolean pass/fail, dozens per merge). Decision-reviews are heavyweight re-examinations (questions + options + evidence, few per quarter). Conflating them hurts both.

**(C) Stratified primitive** — one schema, two usage levels via a `kind` discriminator. Same file, same CLI, different required-field profiles.

> **Your comment:**
>
> _…_

---

## Step 2 — Premise challenge

- **Conventional wisdom**: "Extend `todos.yaml` with a `source_type` variant — minimal schema churn." But that's already the workaround in use, and it lacks required fields.
- **Prior art in codebase**: `re-evaluate-dispatch-enforcement` encodes trigger via `depends_on` and acceptance-criteria via prose in `work_needed`. It _works_ but the prose is unstructured and there's no "trigger met" surfacing in `alm triage`. Watch-list signals have no structured home at all — they end up in commit messages or learnings.
- **First principles**: The primitive needs to (1) record at decision-time ("when X ships, ask Y, look for Z") and (2) surface at evidence-time ("X shipped — here's the pending re-examination"). Core fields: **trigger condition**, **question**, **acceptance/resolution**, optionally **evidence**. The defining property is **dormant-until-triggered** — true for both watch-items and decision-reviews; the difference is depth.

**Verdict**: (A) vs (C) is the real tension, not (A) vs (B). (B) is ruled out because the underlying lifecycle is identical. Question is whether to collapse fully or stratify.

> **Your comment:**
>
> _…_

---

## Step 3 — Decisions

### Decision 1 — Unified or stratified primitive?

**Option A — Unified `observations` primitive.** One schema, one file (`.furrow/almanac/observations.yaml`), one CLI surface. A watch-item is just a minimal decision-review (title + trigger + single acceptance question). No `kind` field; field richness is optional.

- Pro: one mental model; lightweight watches naturally upgrade to rich decision-reviews as evidence warrants.
- Con: watch items and decision-reviews have genuinely different cardinality and ceremony. Mixing may make `alm` output noisy (dozens of trivial watches drowning two important reviews).

**Option B — Stratified with `kind` discriminator.** Same file/CLI, but `kind: watch` requires only {title, trigger, resolution}; `kind: decision-review` requires full {trigger, question, options, evidence, acceptance}. Validation enforces the profile.

- Pro: explicit shape for the reader; triage can filter/display differently per kind; one schema still.
- Con: two shapes in one schema — slight discriminator complexity. Risk of premature commitment to the distinction.

**Option C — Field on TODO schema (no new file).** Add `reexamination` block (trigger_condition, review_question, decision_options?, evidence_needed?) to the existing TODO schema. No watches.yaml; watch-items are TODOs with the `reexamination` block populated and `work_needed` minimal.

- Pro: zero new file primitives; existing `alm list/show/triage` works. Stays consistent with "one TODO file, one CLI."
- Con: `todos.yaml` is already long. Decision-reviews have no effort/impact in the usual sense; shoehorning them weakens the TODO concept. Makes watch-list feel heavyweight (still requires all TODO fields).

**My lean**: **Option B (stratified)**, living in `.furrow/almanac/observations.yaml`, with `kind: watch | decision-review`. The two use cases share lifecycle but differ in cardinality and required depth — a stratified schema captures both without collapsing the distinction that triage surfacing needs. A new file prevents `todos.yaml` from being a dumping ground and lets `alm` grow an `observe` subcommand cleanly. Kills `source_type: "decision-review"` as a workaround.

> **Your decision:**
>
> I agree, let's go with Option B

---

### Decision 2 — What is a trigger, concretely?

Three shapes of trigger, each answerable by `alm`:

- **(a) Row-ship trigger** — `triggered_by: { type: row_merged, row: parallel-agent-wiring }`. Activates when that branch merges to main (detectable by commit or by `rws archive`).
- **(b) Count-based trigger** — `triggered_by: { type: rows_since, since_row: parallel-agent-wiring, count: 3 }`. Activates after N subsequent rows land (matches the dispatch-enforcement example).
- **(c) Time-based trigger** — `triggered_by: { type: after_date, date: "2026-05-15" }`. Activates on a calendar boundary.
- **(d) Manual-only trigger** — `triggered_by: { type: manual }`. Activates when user runs `alm observe trigger <id>`. Escape hatch.

**My lean**: support all four via a discriminated union on `triggered_by.type`. MVP implements `row_merged`, `rows_since`, and `manual`; `after_date` follows if needed.

> **Your decision:**
>
> Agreed with the lean, I wonder how we build in the incrementing / observing

---

### Decision 3 — Does this row ship behavior, or just schema + design?

**Option X — Schema + CLI shell + one real migration.** Ship the schema (validated), add `alm observe list/show/add/resolve` subcommands, migrate `re-evaluate-dispatch-enforcement` and any similar TODOs, and integrate with `alm triage` to surface triggered observations. Don't yet auto-detect triggers from archive events.

- Pro: concrete, testable, proves the primitive end-to-end with today's data.
- Con: ~2 session estimate may stretch.

**Option Y — Schema + design doc only.** Define the schema, write a design note in `docs/`, migrate the two TODOs, but do not build the CLI or integrate with triage. Defer to a later row.

- Pro: low-risk, fits "~2 sessions" comfortably.
- Con: unshipped primitives atrophy. Roadmap estimated 2 sessions expecting working behavior.

**Option Z — Full integration with archive/merge hooks.** Auto-populate trigger-state on row archive/merge, auto-surface in triage, add review-step suggestion prompt.

- Pro: the primitive is "alive" from day one.
- Con: couples to merge-skill work (Phase 1's other row). Risks scope creep and cross-row conflict (though roadmap says none).

**My lean**: **Option X**. Ship the primitive with CLI and triage integration, migrate real TODOs, but hold off on merge-hook auto-trigger until after Phase 1's `/furrow:merge` skill lands (natural handoff to a later row).

> **Your decision:**
>
> Option Z, we can deal with conflicts at merge but deferring this work is the wrong move, the furrow:merge skill is being worked on a parallel branch you can look at those artifacts if you want to build this in a compatible way

---

### Decision 4 — File naming

Candidates: `observations.yaml`, `watches.yaml`, `reexaminations.yaml`, `followups.yaml`.

**My lean**: `observations.yaml` — neutral enough for both watches and decision-reviews, aligns with the mental model "record an observation to make later." But `watches.yaml` is more evocative for the common case.

> **Your decision:**
>
> Agreed

---

## Open space — anything else?

Framings to push back on, scope concerns, constraints I missed, etc.

> _…_
