# Spec: promote-learnings-schema-fix

**Wave**: 2
**Specialist**: harness-engineer
**Depends on**: test-isolation-guard

## Interface Contract

### Canonical learning schema (new, authoritative)

Every `.furrow/rows/*/learnings.jsonl` entry MUST match this shape:

```json
{
  "ts": "ISO-8601 UTC timestamp",
  "step": "ideate|research|plan|spec|decompose|implement|review",
  "kind": "pattern|pitfall|preference|convention|dependency",
  "summary": "actionable insight (min 10 chars)",
  "detail": "situation that surfaced it (min 10 chars)",
  "tags": ["string", ...]
}
```

Codified in `schemas/learning.schema.json` as a JSON-Schema Draft 2020-12
document with `additionalProperties: false` at the root object.

### Field migration map (old → new)

Per research Section E, four rows use the OLD schema
(`harness-v2-status-eval`, `review-impl-scripts`, `ideation-and-review-ux`,
`post-ship-reexamination`). The one-time migration rewrites their
`learnings.jsonl` files:

| Old field | New field | Notes |
|---|---|---|
| `timestamp` | `ts` | Same value, renamed |
| `source_step` | `step` | Same value, renamed |
| `category` | `kind` | Same enum values |
| `content` | `summary` | Same value, renamed |
| `context` | `detail` | Same value, renamed |
| `promoted` | — | Dropped (no semantic equivalent) |
| `id` | — | Dropped (not in new schema) |
| `source_task` | — | Dropped (derivable from file path) |
| — | `tags` | New field; defaults to `[]` if not inferable |

**Unmappable records**: entries that fail the map (missing required old
fields, unparseable timestamps) are written to
`.furrow/rows/<row>/migration-report.md` rather than silently dropped. The
migration script exits non-zero if any record is unmappable, surfacing the
report path.

### migrate-learnings-schema.sh

- **Path**: `bin/frw.d/scripts/migrate-learnings-schema.sh`
- **Mode**: 100755
- **Args**: none (walks `.furrow/rows/*/learnings.jsonl` automatically)
- **Idempotency**: detects already-migrated files (first record has `ts`
  field) and skips them.
- **Exit codes**: 0 on success (including no-op); non-zero if any record is
  unmappable (report written alongside).

### append-learning.sh (new hook)

- **Path**: `bin/frw.d/hooks/append-learning.sh`
- **Registration**: via `install.sh` merge into `.claude/settings.json`
  (AD-4).
- **Invocation**: before any write to `.furrow/rows/*/learnings.jsonl`.
- **Behavior**: validates the proposed append line against
  `schemas/learning.schema.json` by calling the shared helper
  `bin/frw.d/lib/validate-json.sh::validate_json`. This helper is
  produced by the sibling `reintegration-schema-consolidation`
  deliverable (both are wave-2; decompose orders them so the helper
  lands first). **No inlining fallback** — this deliverable's hook MUST
  call the shared helper per constraint #6 ("schemas are authoritative;
  inline jq subsets are forbidden in validation paths — use the Python
  Draft2020-12Validator via the shared validate-json.sh helper").
- **Exit codes**: 0 on valid append; non-zero on schema failure (append
  refused).

### commands/lib/promote-learnings.sh (rewritten read path)

- **Reads ONLY the new schema**. Per line:
  ```sh
  kind=$(echo "$line" | jq -r '.kind')
  step=$(echo "$line" | jq -r '.step')
  summary=$(echo "$line" | jq -r '.summary')
  tags=$(echo "$line" | jq -r '.tags | join(",")')
  ```
- **Assertion**: for every iterated line, `kind`, `step`, `summary` must be
  non-null and non-empty; otherwise the script emits a diagnostic referring
  to the hook (since a valid hook should have prevented this).

## Acceptance Criteria (Refined)

Derived from definition.yaml ACs; each is testable.

1. **AC1 — Schema file exists and is authoritative**.
   `schemas/learning.schema.json` defines the new schema with required fields
   `[ts, step, kind, summary, detail, tags]`,
   `additionalProperties: false`, and the appropriate enums for `step` and
   `kind`.

2. **AC2 — Protocol doc references only the new schema**.
   `skills/shared/learnings-protocol.md` documents the canonical new schema.
   Any reference to old-schema fields (`id`, `timestamp`, `category`,
   `content`, `context`, `source_task`, `source_step`, `promoted`) is
   removed.

3. **AC3 — Migration script rewrites 4 old-format rows**.
   `bin/frw.d/scripts/migrate-learnings-schema.sh` exists, is mode 100755,
   and when run against a fixture containing the four old-format rows,
   produces output where every file validates against
   `schemas/learning.schema.json`.

4. **AC4 — Unmappable records logged, not dropped**. If a record cannot be
   migrated (e.g., missing `timestamp`), the script writes an entry to
   `.furrow/rows/<row>/migration-report.md` with the raw record and the
   reason; the script exits non-zero.

5. **AC5 — promote-learnings.sh reads only new schema**.
   `commands/lib/promote-learnings.sh` no longer references fields
   `category`, `content`, `context`, `source_step`, `promoted`. Output for
   every iterated learning shows non-null values for `summary`, `kind`,
   `step`, `tags`.

6. **AC6 — append-learning hook validates every write**.
   `bin/frw.d/hooks/append-learning.sh` exists, is mode 100755, is
   registered via install.sh's settings.json merge, and refuses invalid
   appends with a non-zero exit code whose message includes a schema path to
   the offending field.

7. **AC7 — Regression: promote reads 3 new-schema entries**.
   `tests/integration/test-promote-learnings.sh` seeds a fixture row with
   exactly 3 known new-schema learnings and asserts that
   `promote-learnings.sh` prints all three with populated `summary`, `kind`,
   `step`, `tags` fields.

8. **AC8 — Regression: migration on old-schema fixture produces schema-valid
   output with zero silent drops**.
   `tests/integration/test-migrate-learnings.sh` seeds a fixture row with
   old-schema entries including at least one unmappable record; asserts (a)
   migrated file validates against the schema, (b) migration-report.md
   exists and lists the unmappable record, (c) no old-schema field leaks into
   the output.

9. **AC9 — Regression: invalid append is refused**.
   Feeding a malformed learning through `append-learning.sh` exits non-zero
   with the validator's path-to-error message in stderr.

## Test Scenarios

### Scenario: promote-learnings reads new-schema entries correctly
- **Verifies**: AC5, AC7
- **WHEN**: fixture row has 3 learnings.jsonl lines each with
  `{ts, step, kind, summary, detail, tags}` populated
- **THEN**: `commands/lib/promote-learnings.sh` prints 3 entries whose
  `summary`, `kind`, `step`, `tags` fields are each non-empty
- **Verification**:
  ```sh
  cmd=commands/lib/promote-learnings.sh
  out=$("$cmd" .furrow/rows/fixture-row/learnings.jsonl)
  test "$(echo "$out" | grep -c 'kind=')" = "3"
  test "$(echo "$out" | grep -c 'summary=')" = "3"
  ! echo "$out" | grep -q 'summary=$'   # no empty summary
  ```

### Scenario: migration of old-schema row produces schema-valid output
- **Verifies**: AC3, AC8
- **WHEN**: fixture row has `learnings.jsonl` with 3 old-schema lines
  (fields `id, timestamp, category, content, context, source_task,
  source_step, promoted`)
- **THEN**: after running the migration script, each line of the file
  validates against `schemas/learning.schema.json`
- **Verification**:
  ```sh
  bin/frw.d/scripts/migrate-learnings-schema.sh
  while IFS= read -r line; do
    echo "$line" | python3 -c "
  import json, sys
  from jsonschema import Draft202012Validator
  schema = json.load(open('schemas/learning.schema.json'))
  Draft202012Validator(schema).validate(json.loads(sys.stdin.read()))
  "
  done < .furrow/rows/fixture-row/learnings.jsonl
  ```

### Scenario: unmappable record triggers migration-report.md
- **Verifies**: AC4, AC8
- **WHEN**: fixture has one old-schema record missing the `timestamp` field
- **THEN**: after running migration, `.furrow/rows/<row>/migration-report.md`
  exists, contains the offending record's raw JSON, and migration script
  exited non-zero
- **Verification**:
  ```sh
  if bin/frw.d/scripts/migrate-learnings-schema.sh; then
    echo "expected non-zero exit" >&2; exit 1
  fi
  test -f .furrow/rows/fixture-row/migration-report.md
  grep -q 'missing.*timestamp' .furrow/rows/fixture-row/migration-report.md
  ```

### Scenario: invalid append refused by hook
- **Verifies**: AC6, AC9
- **WHEN**: a process attempts to append a JSON line missing the required
  `kind` field to `.furrow/rows/<row>/learnings.jsonl`
- **THEN**: `append-learning.sh` exits non-zero and stderr contains
  `kind` in a schema-error path format
- **Verification**:
  ```sh
  bad='{"ts":"2026-04-23T00:00:00Z","step":"ideate","summary":"x","detail":"y","tags":[]}'
  if echo "$bad" | bin/frw.d/hooks/append-learning.sh demo-row 2> "$TMP/err"; then
    echo "expected non-zero exit" >&2; exit 1
  fi
  grep -q "kind" "$TMP/err"
  ```

### Scenario: valid append accepted by hook
- **Verifies**: AC6
- **WHEN**: append payload is a fully valid new-schema record
- **THEN**: exit code 0; the line is appended to the target file
- **Verification**:
  ```sh
  good='{"ts":"2026-04-23T00:00:00Z","step":"ideate","kind":"pattern","summary":"valid one","detail":"surfaced in test","tags":["test"]}'
  echo "$good" | bin/frw.d/hooks/append-learning.sh demo-row
  tail -n1 .furrow/rows/demo-row/learnings.jsonl | grep -q '"valid one"'
  ```

### Scenario: protocol doc has no old-schema references
- **Verifies**: AC2
- **WHEN**: `skills/shared/learnings-protocol.md` is grepped after this
  deliverable
- **THEN**: zero occurrences of old-schema field names
- **Verification**:
  ```sh
  for f in timestamp category content context source_task source_step promoted; do
    ! grep -qw "$f" skills/shared/learnings-protocol.md
  done
  ```

### Scenario: migration is idempotent
- **Verifies**: AC3
- **WHEN**: migration script runs against an already-migrated file
- **THEN**: file contents unchanged; exit 0; stderr indicates a skip
- **Verification**:
  ```sh
  sha1=$(sha256sum .furrow/rows/fixture-row/learnings.jsonl | awk '{print $1}')
  bin/frw.d/scripts/migrate-learnings-schema.sh
  sha2=$(sha256sum .furrow/rows/fixture-row/learnings.jsonl | awk '{print $1}')
  test "$sha1" = "$sha2"
  ```

## Implementation Notes

- **Forward commit, not history rewrite (team-plan.md risk register)**. This
  deliverable rewrites `learnings.jsonl` in 4 archived rows with normal
  commits. It does NOT use `git filter-repo`, `git rebase -i`, or any
  history-rewriting tool. Downstream consumers that hash the raw files must
  re-check; no audit-trail fields (`ts`, `step`) are modified — only fields
  renamed or dropped. Each migrated row also gets a committed
  `migration-report.md` documenting what changed.
- **One-time migration (AD-3)**. Rather than a permanent dual-schema reader,
  we collapse the drift to a single canonical shape. Research Section E
  confirmed the old schema was documented but silently abandoned; row count
  is small (4).
- **Hook registration model (AD-4)**. The new hook registers via `install.sh`
  merging an entry into `.claude/settings.json`, matching the existing
  hook-registration pattern. This is consistent with `pre-commit-bakfiles.sh`,
  `state-guard.sh`, etc.
- **Validator pattern (research Section A)**. Use the exact
  Draft2020-12Validator invocation already in
  `validate-definition.sh:36-55` — positional args, `Schema error at <path>:
  <message>` output, in-band error collection. If the shared
  `bin/frw.d/lib/validate-json.sh` helper from
  `reintegration-schema-consolidation` has landed before this, use it;
  otherwise inline the same pattern and refactor to the helper later.
- **Unmappable record policy**. Never silently drop data. Every record that
  fails the migration map must appear in `migration-report.md` with (a) raw
  original JSON, (b) the specific mapping failure (e.g., "missing
  timestamp"). The report file is committed alongside the migrated data.
- **Schema enum alignment**. `step` enum values align with
  `.claude/rules/step-sequence.md`: `ideate, research, plan, spec, decompose,
  implement, review`. `kind` enum aligns with the existing documented
  values: `pattern, pitfall, preference, convention, dependency`.
- **Sandbox**. Both regression tests use `setup_sandbox` from
  `tests/integration/lib/sandbox.sh` (wave-1). Neither test mutates the live
  worktree — the fixture rows are created under `$TMP`.
- **POSIX sh**. All shell scripts are POSIX sh; bash features require an
  explicit `#!/usr/bin/env bash` shebang.
- **Archived-row edit policy**. Per risk register row 7: this modifies
  archived rows' `learnings.jsonl`. This is a deliberate, reviewed forward
  commit — not a re-opening of the row. No other archived-row files are
  touched.

## Dependencies

- **Upstream deliverables**:
  - `test-isolation-guard` (wave-1): `setup_sandbox` helper used by both
    regression tests; `git status --porcelain` pre/post assertions in
    `run-all.sh` guard against live-tree mutation.
- **Sibling deliverable (hard dep for the hook)**:
  - `reintegration-schema-consolidation` (wave-2): produces
    `bin/frw.d/lib/validate-json.sh` shared helper. This deliverable's
    hook calls the helper; decompose MUST order so the helper-producing
    deliverable implements first within wave-2. The definition.yaml
    file_ownership graphs both deliverables onto disjoint files; only
    the runtime call-site ordering is enforced at decompose. No
    inlining fallback — constraint #6 forbids ad-hoc validator copies.
- **Scripts/libs consumed**:
  - `jq` — line-by-line JSON reading in `promote-learnings.sh`.
  - `python3` + `jsonschema>=4.0` — Draft2020-12 validator subprocess.
- **Schemas**: `schemas/learning.schema.json` is authored here; no other
  schema file is modified.

## File Ownership

Per plan.json:
- `commands/lib/promote-learnings.sh`
- `bin/frw.d/hooks/append-learning.sh`
- `bin/frw.d/scripts/migrate-learnings-schema.sh`
- `schemas/learning.schema.json`
- `skills/shared/learnings-protocol.md`
- `tests/integration/test-promote-learnings.sh`
- `tests/integration/test-migrate-learnings.sh`
- `.furrow/rows/*/learnings.jsonl` (4 archived rows: `harness-v2-status-eval`,
  `review-impl-scripts`, `ideation-and-review-ux`, `post-ship-reexamination`)
