# Team Plan — post-ship-reexamination

## Architecture decisions

### AD-1 — Stratified schema with `allOf` + `if/then` + `const` discriminator

Source: `research/discriminator-idiom.md`; `research/synthesis.md` ("D1 — observations-schema").

Both the `kind` discriminator and the `triggered_by.type` discriminator use the same JSON Schema idiom: `allOf: [{if: {properties: {<discriminator>: {const: <value>}}, required: [<discriminator>]}, then: {...}}, ...]`. `required: [<discriminator>]` inside every `if` is mandatory — omitting it causes vacuous match and wrong-branch firing (primary-source-verified).

Rejected: `oneOf`. The Python `jsonschema` library treats `if/then` as a "strong match" for error reporting; `oneOf` is in WEAK_MATCHES and produces a cascade of unrelated-branch failures that obscure validation errors.

This schema sets the house style for discriminated unions; no existing repo precedent.

### AD-2 — Split status model (persisted lifecycle, computed activation)

Source: ideation dual-review (`.furrow/rows/post-ship-reexamination/reviews/ideation-cross.json`), codex finding #1 on status-model contradiction.

Observation state is split by concern:

- **Persisted on the observation**: `lifecycle` enum `open | resolved | dismissed` — user-driven state.
- **Computed at query time**: activation `active | pending` — trigger-driven state, derived from `.furrow/rows/*/state.json:archived_at`. Never stored on the observation.

The ONE permitted exception is `manual_activation_at` (ISO 8601 timestamp) stored when `alm observe activate` is called for a `triggered_by.type == manual` observation, because manual triggers have no other signal to derive from.

Rationale: dual-review surfaced the contradiction between "stateless" and "status stored on entity." Splitting the two concerns preserves the stateless-triggers invariant while giving users an explicit way to close an observation.

### AD-3 — Validation inline in `bin/alm:cmd_validate`, split per file

Source: `research/alm-extension-blueprint.md` ("Validation plumbing"); `research/synthesis.md` ("MATERIAL FINDING" + Q4 resolution).

Following the actual pattern in the repo: todos validation is inline in `cmd_validate` at `bin/alm:827-937`; no shell script wraps it. Observations validation mirrors that pattern: either extend `cmd_validate` in place or split into `cmd_validate_todos` + `cmd_validate_observations` dispatched by a thin `cmd_validate "<path>"`. The `cmd_validate "<path>"` signature must be preserved — `cmd_add` (bin/alm:198) and `cmd_triage` (bin/alm:523) call it.

Implementation guidance for the implementer: copy the `yq | python3 Draft202012Validator` heredoc byte-identical, parameterize the schema file path, introduce `SCHEMA_FILE_TODOS` and `SCHEMA_FILE_OBSERVATIONS` constants rather than reusing the existing `SCHEMA_FILE` global.

### AD-4 — Pull-model activation via `find_active_rows` template

Source: `research/alm-extension-blueprint.md` ("Pull-model activation query plan"); `research/synthesis.md` ("D2 — alm-observe-cli").

The pull-model "count archived rows since baseline" query template already exists at `bin/rws:169-183` (`find_active_rows`). Copy-paste with the filter flipped (include archived, not exclude). Concrete:

```sh
_count=0
for _state_file in "${ROWS_DIR}"/*/state.json; do
  _archived="$(jq -r '.archived_at // "null"' "$_state_file" 2>/dev/null)" || continue
  [ "$_archived" = "null" ] && continue
  if [ "$_archived" \> "$_baseline_archived" ]; then
    _count=$((_count + 1))
  fi
done
```

Correctness depends on the ISO-8601 `Z`-normalized invariant (all timestamps in UTC with trailing Z). The rest of the repo already depends on this invariant; no new risk introduced. If a stray offset-timestamped row ever appears, it will sort incorrectly — document the invariant in a comment.

### AD-5 — `alm triage` additive `active_observations` key

Source: `research/integration-points.md` ("alm triage output structure & insertion"); `research/synthesis.md` ("D3 — archive-and-triage-integration").

`cmd_triage` writes `.furrow/almanac/roadmap.yaml` AND prints a JSON analysis blob to stdout. Add a top-level `active_observations` key in both. Because it is additive and optional, existing consumers do not break. The Markdown at `.furrow/almanac/roadmap.md` is agent-generated via `commands/triage.md` — update that template to render an "Active Observations" section from the new YAML key.

### AD-6 — `/archive` insertion as new step 8

Source: `research/integration-points.md` ("/archive insertion point"); `research/synthesis.md` ("D3 — archive-and-triage-integration").

Insert `alm observe on-archive "<name>"` as a new step 8 in `commands/archive.md`, between current step 7 ("TODO pruning") and current step 8 (`rws archive "<name>"`). Renumber 8→9, 9→10, 10→11. No external files reference these numbers; renumbering is safe.

Surface-only: observation resolution or dismissal is ALWAYS a separate explicit action (`alm observe resolve|dismiss`). The archive step prints what activated; the user decides.

### AD-7 — D4 migration as a single atomic commit with ordered validation

Source: definition.yaml D4 AC (migration ordering); ideation dual-review fresh-agent finding C (D4 migration ordering fragility); `research/synthesis.md` ("D4 — migration-and-review-prompt").

Migration order INSIDE a single commit:

1. Add migrated entry to `.furrow/almanac/observations.yaml`. Run `alm validate`. (Must pass — observations valid, todos still valid because the source_type enum hasn't been touched yet.)
2. Remove original entry from `.furrow/almanac/todos.yaml`. Run `alm validate`. (Must pass — todos valid, `decision-review` still in the enum but unused.)
3. Remove `decision-review` from the `source_type` enum in `adapters/shared/schemas/todos.schema.yaml`. Run `alm validate`. (Must pass — schema change fully absorbed.)

Land as ONE commit. If any step fails, abort and reset; partial commits risk leaving `todos.yaml` with an orphan enum reference or a schema that rejects valid data.

## Waves and specialist assignments

### Wave 1 — D1: observations-schema

- **Specialist**: `harness-engineer` (schema + validation infrastructure is its core)
- **File ownership**: `adapters/shared/schemas/observations.schema.yaml`, `.furrow/almanac/observations.yaml`
- **Inputs**: AD-1, AD-2; `adapters/shared/schemas/todos.schema.yaml` (sibling pattern)
- **Outputs gate D2**: schema must validate; empty `observations.yaml` must validate; `alm validate` extended in D2 must successfully run against it

### Wave 2 — D2: alm-observe-cli

- **Specialist**: `harness-engineer` (bin/alm CLI + validation plumbing)
- **File ownership**: `bin/alm`
- **Inputs**: AD-3, AD-4; research `alm-extension-blueprint.md`
- **Outputs gate D3, D4**: all seven `_observe_<verb>` helpers pass happy-path manual smoke; `alm validate` exits non-zero on either file failing

### Wave 3 — D3 ∥ D4 (parallel; disjoint file ownership)

**D3: archive-and-triage-integration**

- **Specialist**: `harness-engineer`
- **File ownership**: `commands/archive.md`, `commands/triage.md`, `bin/alm` (triage extension only)
- **Inputs**: AD-5, AD-6

**D4: migration-and-review-prompt**

- **Specialist**: `migration-strategist` (explicit ordered migration with atomic-commit discipline)
- **File ownership**: `.furrow/almanac/todos.yaml`, `.furrow/almanac/observations.yaml`, `adapters/shared/schemas/todos.schema.yaml`, `skills/review.md`, `skills/shared/summary-protocol.md`
- **Inputs**: AD-7

**Cross-deliverable wave 3 non-overlap check**: D3 touches `commands/` + `bin/alm`; D4 touches `.furrow/almanac/` + `adapters/shared/schemas/` + `skills/`. No file overlap.

## Risk register

| Risk | Mitigation |
|---|---|
| Discriminator-idiom `required` omission causes wrong-branch firing | D1 AC explicitly requires `required: [<discriminator>]` in each `if` block; implementer must read AD-1 before writing schema |
| ISO-8601 TZ-offset inconsistency breaks lexicographic compare | Document `Z`-normalized invariant in schema/comment; the codebase already depends on this |
| `commands/archive.md` file-level merge conflict with `work/install-and-merge` | Already acknowledged. Mitigation: rebase this row onto main after `install-and-merge` merges (or vice versa if this row lands first). No scheduling dependency required — file's step list is additive and both rows add separate steps. |
| D4 migration partially applied (commit order violated) | AD-7 explicit single-commit constraint + `alm validate` between each sub-step |
| `cmd_validate` signature change breaks `cmd_add`/`cmd_triage` callers | Implementer preserves `cmd_validate "<path>"` signature; split is internal |

## Decompose validation

Cross-checks performed at the decompose step (plan.json and team-plan.md were authored during the plan step; decompose validates them against decompose-specific invariants):

- **Every deliverable appears in exactly one wave** — D1→W1, D2→W2, D3→W3, D4→W3. Pass.
- **`depends_on` ordering respected across waves** — D2.depends_on=[D1] → D2 in W2 > W1; D3.depends_on=[D2] → D3 in W3 > W2; D4.depends_on=[D2] → D4 in W3 > W2. Pass.
- **`file_ownership` globs non-overlap within a wave** — W1 solo; W2 solo; W3: D3={commands/archive.md, commands/triage.md, bin/alm} ∩ D4={.furrow/almanac/*.yaml, adapters/shared/schemas/todos.schema.yaml, skills/*} = ∅. Pass.
- **Vertical slicing** — each deliverable is independently testable end-to-end:
  - D1: schema + empty data file validate via `alm validate` (after D2 ships) — but D1's own AC is "schema is syntactically valid JSON Schema," which is testable standalone with any JSON Schema validator.
  - D2: all 7 verbs + extended validate — testable against the D1 schema.
  - D3: /archive step 8 + triage extension — testable against a synthetic row + pre-seeded observation.
  - D4: migration — testable by dry-run validate-between-each-step.
- **Team sizing**: 4 deliverables, 2 specialists (harness-engineer, migration-strategist). Within the 2-3 specialist guideline for 2-3 deliverables (slightly more deliverables than specialists because D1-D3 share one specialist who handles them serially across waves). Acceptable.
- **Skills**: `skills: []` on every assignment. No step-level skill overrides needed — the implement skill handles all 4 well, and specialist templates provide domain reasoning.
- **Branch**: `work/post-ship-reexamination` (set by `rws init` during ideate). Implement step does NOT need to branch again.

No decompose-specific corrections required. Plan-step output is implementation-ready.

## Acceptance cadence

- Wave 1: D1 passes validation on the schema itself and on empty observations file.
- Wave 2: D2 all seven verbs pass happy-path smoke; `alm validate` extended.
- Wave 3: D3 activates in a synthetic `/archive` run; D4 migration lands as one atomic commit with `alm validate` green at each of the three sub-steps.
