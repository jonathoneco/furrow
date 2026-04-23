# Spec: archive-and-triage-integration

## Interface Contract

**Files modified**:
- `commands/archive.md` — orchestration doc for the `/archive` slash command.
- `commands/triage.md` — orchestration doc for the `/furrow:triage` slash command (template for Markdown generation).
- `bin/alm` — `cmd_triage` extension adding `active_observations` to both the YAML roadmap output and the JSON stdout analysis blob.

**Contract guarantees**:
- `/archive` invokes `alm observe on-archive "<row>"` as a new step. Output is surfaced to the user; no automatic resolution.
- `alm triage` emits an additive top-level `active_observations` key in the generated `roadmap.yaml` and in the JSON blob printed to stdout. Consumers that don't know the key are unaffected (additive).
- `/furrow:triage`'s generated Markdown includes an "Active Observations" section when the list is non-empty; omitted otherwise.
- No change to `rws archive` CLI behavior. All new behavior is at the `/archive` command-orchestration layer and in `cmd_triage`.

## Acceptance Criteria (Refined)

### `commands/archive.md`

Insert a new step 8 in the "Behavior" numbered list:

```markdown
8. **Observations surface**: Run `alm observe on-archive "{name}"`.
   - Displays any observations whose activation became `active` as a result
     of this row's archival (e.g., row_archived triggers whose `row` matches,
     or rows_since triggers whose count threshold just crossed).
   - **Surface only** — does NOT auto-resolve or auto-dismiss. Users handle
     each with `alm observe resolve <id> ...` or `alm observe dismiss <id> ...`
     as separate explicit steps, outside /archive.
   - If no observations activate, prints a single line and moves on.
```

Renumber current steps 8, 9, 10 → 9, 10, 11.

No other changes to `commands/archive.md`. Preamble, arguments, pre-conditions, output sections unchanged.

### `alm triage` output extension (`bin/alm:cmd_triage`)

- Compute `active_observations`: iterate observations.yaml entries where `lifecycle == open` AND computed activation is `active`. For each, emit `{id, kind, title, activation_reason}`. `activation_reason` is a short human-readable string:
  - `row_archived: <row>` for row_archived triggers.
  - `rows_since: <N>/<target> rows archived since <since_row>` for rows_since triggers, where `N` is the actual observed qualifying count and `target` is the threshold.
  - `manual: activated at <timestamp>` for manual triggers.
- Insert `active_observations: [<list>]` as a top-level key in the YAML roadmap written to `.furrow/almanac/roadmap.yaml`. Place it AFTER existing top-level keys to minimize diff noise in existing consumers (exact placement: after `waves`, before `handoff`).
- Insert `"active_observations": [...]` as a top-level key in the JSON blob printed to stdout (additive; same shape).
- Empty list: omit the key from both outputs (avoid empty-section noise). Consumers must tolerate absence.

### `commands/triage.md` template addition

If the generated roadmap includes a non-empty `active_observations` list, the agent rendering `.furrow/almanac/roadmap.md` adds a section:

```markdown
## Active Observations

Observations whose triggers have fired — re-examination pending user action.

- `{id}` (`{kind}`) — {title}
  - _Activation_: {activation_reason}
  - Resolve: `alm observe resolve {id} ...` • Dismiss: `alm observe dismiss {id} ...`
```

Placement: after the phase table, before the per-phase detail sections. Omit entirely if the roadmap has no `active_observations` key.

### Non-requirements (scoped to THIS deliverable)

- This deliverable does NOT modify `rws archive`, `alm add`, or `alm validate`. (Note: D2 separately extends `alm validate` to cover observations.yaml; that is D2's concern, not D3's.)
- No new CLI flags on existing commands (only the new behavior documented above).

## Test Scenarios

### Scenario: archive-surfaces-activations
- **Verifies**: `/archive` step 8 surfaces activated observations
- **WHEN**: A row X is in review-passed state and has an observation with `triggered_by: {type: row_archived, row: X}`, `lifecycle: open`. User runs `/archive X`.
- **THEN**: The archive workflow reaches step 8 and prints the observation's id, kind, title, and activation reason.
- **Verification**: Manual run of `/archive` on a test row with a pre-seeded observation; grep the transcript.

### Scenario: archive-with-no-activations
- **Verifies**: no-activations case is silent-ish
- **WHEN**: A row Y is archived with no observations triggering off it.
- **THEN**: Step 8 prints one line (e.g., `no observations activated by archive of Y`) and the workflow continues.
- **Verification**: `alm observe on-archive Y` stdout is one line; `/archive` orchestration proceeds to step 9.

### Scenario: triage-emits-active-observations-key
- **Verifies**: `cmd_triage` additive YAML key
- **WHEN**: observations.yaml has 2 entries with `lifecycle: open` and computed activation `active`, 1 with `lifecycle: resolved`, 1 with `lifecycle: open` but `pending`. User runs `alm triage`.
- **THEN**: `.furrow/almanac/roadmap.yaml` has `active_observations` list with exactly 2 items (the 2 active-open). `lifecycle: resolved` is excluded. `lifecycle: open AND pending` is excluded.
- **Verification**: `yq '.active_observations | length' .furrow/almanac/roadmap.yaml` == 2.

### Scenario: triage-omits-active-observations-key-when-empty
- **Verifies**: empty-list omission
- **WHEN**: observations.yaml has no entries with `lifecycle: open AND active`. User runs `alm triage`.
- **THEN**: `roadmap.yaml` does NOT contain an `active_observations` key at all.
- **Verification**: `yq 'has("active_observations")' roadmap.yaml` == `false`.

### Scenario: triage-json-stdout-additive
- **Verifies**: JSON stdout additive key
- **WHEN**: same as scenario 3
- **THEN**: stdout JSON blob includes top-level `"active_observations"` key with matching shape.
- **Verification**: `alm triage | jq '.active_observations | length'` == 2.

### Scenario: existing-triage-consumers-unaffected
- **Verifies**: backwards compatibility
- **WHEN**: a consumer (e.g., `alm next`, or another CLI reading `roadmap.yaml`) reads the YAML.
- **THEN**: Existing fields (`phases`, `waves`, `handoff`, etc.) unchanged; consumer does not error on the new key.
- **Verification**: Re-run any existing command that consumes roadmap.yaml; no regressions.

### Scenario: archive-md-step-renumbering
- **Verifies**: step 8/9/10/11 sequence
- **WHEN**: Reading `commands/archive.md`.
- **THEN**: Step 8 = observations surface; step 9 = `rws archive`; step 10 = regenerate summary; step 11 = git commit. Numbering consistent.
- **Verification**: grep `^\d\.` the file, assert 1..11 in order.

## Implementation Notes

**Reference AD-5, AD-6** (team-plan.md).

**Step 8 insertion in commands/archive.md**: the current file has 10 steps. Renumber 8 → 9, 9 → 10, 10 → 11 (for `rws archive`, regenerate summary, git commit respectively). Insert the new step 8 with the `alm observe on-archive` content. No external files reference these step numbers (verified during research — `research/integration-points.md`).

**`cmd_triage` modification**: locate the function in `bin/alm`. Compute `active_observations` by iterating observations.yaml and applying the same activation predicate as `alm observe list --active` (reuse the `_observe_compute_activation` helper from D2 if accessible at `cmd_triage`'s scope; else inline the logic). Emit into the YAML roadmap via `yq` pipeline; emit into the JSON stdout blob via `jq` merge. Skip emission entirely if the list is empty.

**Triage template (`commands/triage.md`)**: this is an agent-rendering doc, not code. The agent that generates `roadmap.md` from `roadmap.yaml` reads this template for format guidance. Add the "Active Observations" section to the template; mark it as conditional on the YAML having the key.

**Coordination with install-and-merge worktree**: `commands/archive.md` is a shared edit surface. Rebase-time resolution expected if both rows land. No scheduling dependency — both rows can land in either order; the step-list is additive.

## Dependencies

- **Blocks on**: D2 (alm-observe-cli) — `cmd_triage` needs `_observe_compute_activation` or equivalent; `/archive` step 8 needs `alm observe on-archive` to exist.
- **Unblocks**: nothing internal to this row. External: a post-merge follow-up could wire /furrow:merge to the same `on-archive` display helper.
