# Spec: pi-step-ceremony-backfill

Source: research.md Topic 1 §Canonical deliverable list (primary). All deliverable
names, statuses, commits, and evidence anchors are drawn from that section.

## Interface Contract

**Artifact produced**: `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml`

**CLI invocation** (depends on D1 `repair-deliverables-cli`):

```
furrow row repair-deliverables pi-step-ceremony-and-artifact-enforcement \
  --manifest .furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml
```

**Inputs**: the manifest file (written by this deliverable) + the D1 CLI binary.  
**Outputs**:
- `state.json.deliverables` populated (count = 3) — mutated atomically by D1's CLI, not directly.
- Audit trail entry appended by D1's CLI with `decided_by=manual`, commit reference `e4adef5`, and a timestamp.

**Exit code**: 0 on success; non-zero if precheck fails or manifest is rejected by CLI.

**File ownership** (narrow):
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml` (new, owned by this deliverable)
- `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/state.json` (mutated exclusively through D1's CLI)

## Manifest Content

Full manifest to write verbatim (source: research.md Topic 1 §Canonical deliverable list):

```yaml
# Repair manifest for pi-step-ceremony-and-artifact-enforcement
# Backfills deliverables map from commit e4adef5.
# Generated: 2026-04-24

version: "1"
decided_by: manual
commit: e4adef5

deliverables:
  - name: backend-work-loop-support
    status: completed
    commit: e4adef5
    evidence_paths:
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "3-45"
        note: "test coverage for row init/focus, seed visibility, blocker reporting, scaffolding"
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "63-72"
        note: "post-spec validation pass"
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md
        lines: "9-16"
        note: "outcome summary — what is now real in the repo"

  - name: pi-work-command
    status: completed
    commit: e4adef5
    evidence_paths:
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "46-52"
        note: "headless /work command validation"
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "53-61"
        note: "supervised loop with --complete --confirm"
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "86-92"
        note: "spec->decompose boundary advancement"
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "152-156"
        note: "archived-row blocking"

  - name: validation-and-doc-drift
    status: completed
    commit: e4adef5
    evidence_paths:
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "1-173"
        note: "full test coverage document"
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md
        lines: "73-84"
        note: "almanac validate + doctor passes"
      - path: .furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md
        lines: "25-48"
        note: "files changed in this session"
```

## Run Sequence

Execute in order. Abort if any step fails.

1. **Precheck** — confirm commit is reachable:
   ```
   git cat-file -e e4adef5
   ```
   Must exit 0. If it fails, do not proceed; the manifest references a commit that
   cannot be verified in the current repo.

2. **Write manifest** — write the YAML above verbatim to:
   `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml`

3. **Invoke CLI** (D1 must be built first):
   ```
   furrow row repair-deliverables pi-step-ceremony-and-artifact-enforcement \
     --manifest .furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml
   ```
   Expect exit 0 and a confirmation line naming 3 deliverables registered.

4. **Verify state.json updated**:
   ```
   go run ./cmd/furrow row status pi-step-ceremony-and-artifact-enforcement --json \
     | jq '.deliverables | length'
   ```
   Must return `3`.

5. **Verify rws status output**:
   ```
   rws status pi-step-ceremony-and-artifact-enforcement
   ```
   Output must display the deliverable count > 0 (not empty/missing).

## Acceptance Criteria (Refined)

1. `git cat-file -e e4adef5` exits 0 before any manifest write; deliverable aborts fast otherwise.
2. `repair-manifest.yaml` exists at the target path with all three deliverable entries, correct commit (`e4adef5`), and evidence_paths as specified above.
3. After CLI run, `state.json.deliverables` contains exactly 3 entries with names matching the manifest; count confirmed via `jq '.deliverables | length'` = 3.
4. D1's CLI appends an audit trail entry with: `timestamp` (non-null ISO 8601), `commit=e4adef5`, `decided_by=manual`.
5. `rws status pi-step-ceremony-and-artifact-enforcement` reports deliverable count > 0 (not the pre-repair empty state).

## Test Scenarios

### Scenario: Manifest golden-file match
- **Verifies**: AC 2 — manifest content is exact
- **WHEN**: manifest is written to the target path
- **THEN**: file content matches the YAML specified in this spec exactly (whitespace-normalized)
- **Verification**:
  ```
  diff <(cat .furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml) \
       <(cat specs/pi-step-ceremony-backfill.md | awk '/^```yaml$/,/^```$/' | grep -v '```')
  ```
  Diff must be empty (or match a canonical expected fixture if one is created).

### Scenario: End-to-end repair
- **Verifies**: ACs 3 and 4 — state.json populated, audit trail written
- **WHEN**: precheck passes, manifest is written, CLI is invoked
- **THEN**: `state.json.deliverables` has exactly 3 entries; audit trail entry is present
- **Verification**:
  ```
  go run ./cmd/furrow row status pi-step-ceremony-and-artifact-enforcement --json \
    | jq '{count: (.deliverables | length), names: (.deliverables | keys)}'
  # expect: {"count": 3, "names": ["backend-work-loop-support","pi-work-command","validation-and-doc-drift"]}
  ```

### Scenario: Idempotency / conflict guard
- **Verifies**: AC 3 — re-running does not silently corrupt state
- **WHEN**: CLI is invoked a second time on an already-repaired row (deliverables already populated)
- **THEN**: CLI exits non-zero and names the conflicting deliverable (per D1's --replace requirement)
- **Verification**:
  ```
  furrow row repair-deliverables pi-step-ceremony-and-artifact-enforcement \
    --manifest .furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml
  # expect: non-zero exit; stderr names at least one conflicting deliverable
  # To overwrite intentionally: pass --replace (D1 behavior)
  ```

### Scenario: rws status regression
- **Verifies**: AC 5 — human-readable output reflects repair
- **WHEN**: repair is complete
- **THEN**: `rws status` shows deliverables count > 0
- **Verification**:
  ```
  rws status pi-step-ceremony-and-artifact-enforcement | grep -i deliverable
  # must not show "0 deliverables" or equivalent empty state
  ```

## Implementation Notes

- **One-shot operation.** This deliverable is a run-once procedure, not code.
  Commit message: `chore(furrow): backfill pi-step-ceremony-and-artifact-enforcement deliverables map`
- **Audit trail is D1's responsibility.** This deliverable only prepares the manifest
  and invokes D1's CLI. The audit trail entry (timestamp, commit, decided_by) is written
  by D1 internally; this spec does not add extra logging.
- **No direct state.json edits.** Per `.claude/rules/cli-mediation.md`, all mutations
  go through the D1 CLI. Direct edits are blocked by the state-guard hook.
- **Commit reachability first.** `git cat-file -e e4adef5` must succeed before writing
  the manifest. If the commit is absent (shallow clone, different repo), fail loudly.
- **Deliverable names come from definition.yaml**, not from decompose.md (none exists
  for this row). research.md Topic 1 §Canonical deliverable list confirms 3 deliverables —
  not "5+" as the source TODO prose loosely claimed.
- **Prior commits** (fcb901f, c05edaf) for `pi-work-command` are part of the same logical
  change; `e4adef5` is the consolidating archive-checkpoint commit and is the correct
  `commit` field value for all three entries.

## Dependencies

- **D1 `repair-deliverables-cli`** must be complete and the `furrow` binary must be
  built before this deliverable's run sequence can execute.
- `rws status` shim (part of D1) must be present for AC 5 verification.
- No other deliverables depend on this one directly; D3 `pi-adapter-foundation-archive`
  depends on this deliverable being complete (`depends_on: [pi-step-ceremony-backfill]`).
