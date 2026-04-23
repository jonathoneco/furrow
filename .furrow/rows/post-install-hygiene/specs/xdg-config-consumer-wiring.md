# Spec: xdg-config-consumer-wiring

**Wave**: 2
**Specialist**: harness-engineer
**Depends on**: test-isolation-guard

## Interface Contract

### Canonical resolver (adopted, not created)

The existing `resolve_config_value()` at `bin/frw.d/lib/common.sh:121-144` is the
sole helper for every XDG-config read. Its contract is unchanged by this
deliverable:

```
resolve_config_value <dotted.key>
```

- **Tier 1**: `${PROJECT_ROOT}/.furrow/furrow.yaml`
- **Tier 2**: `${XDG_CONFIG_HOME:-${HOME}/.config}/furrow/config.yaml`
- **Tier 3**: `${FURROW_ROOT}/.furrow/furrow.yaml`
- **Stdout**: resolved value, or empty
- **Exit**: 0 on found non-null non-empty value; 1 otherwise
- **Caller convention (AD-1)**: `value=$(resolve_config_value key) || value="default"`

No new helper is introduced. The existing function is neither renamed nor
wrapped with a default-accepting variant.

### Consumer call sites (wired in this deliverable)

| File | Field | Line reference (today) | Change |
|---|---|---|---|
| `bin/rws` | `gate_policy` | `read_gate_policy()` at 117-124 | Replace hardcoded `"supervised"` fallback with resolver call |
| `bin/frw.d/hooks/stop-ideation.sh` | `gate_policy` | ~41 (definition.yaml-only read) | Same resolver pattern; same fallback default `"supervised"` |
| `skills/shared/specialist-delegation.md` | `preferred_specialists.<role>` | NEW consumer | Decompose-time specialist selection gains a resolver lookup step, with fallback to existing logic when the field is unset |

Note: the four `cross_model.provider` call sites in `cross-model-review.sh`
(lines 79, 280, 446, 631) are adopted by the wave-3
`cross-model-per-deliverable-diff` deliverable, not here — that deliverable
already owns that script and declares `depends_on: [xdg-config-consumer-wiring]`.

### Audit script interface

`bin/frw.d/scripts/doctor-config-audit.sh`:

- **Args**: none
- **Reads**: set of known config fields (hardcoded list matching
  `docs/architecture/config-resolution.md`); resolver call sites via
  `grep -n 'resolve_config_value' bin/ bin/frw.d/ skills/ commands/`
- **Stdout**: human-readable table `field\tconsumer_count\tstatus`
- **Exit**: 0 always (warnings are non-fatal; advisory only)
- **Callers**: invoked by the existing doctor subcommand via single shell-out;
  `bin/frw` itself is NOT modified

## Acceptance Criteria (Refined)

Derived from definition.yaml ACs; each is testable.

1. **AC1 — Audit table complete**. `docs/architecture/config-resolution.md`
   contains a table with one row per config field (`cross_model.provider`,
   `gate_policy`, `preferred_specialists`); each row lists runtime consumer
   path, resolver call-site line number, and the test file that exercises the
   project→XDG→compiled-in chain for that field.

2. **AC2 — gate_policy wired in bin/rws**. `read_gate_policy()` at
   `bin/rws:117-124` invokes `resolve_config_value "gate_policy"` and only
   falls back to `"supervised"` when the resolver returns exit 1. Verified by
   grepping for the call site and running the resolution-order test.

3. **AC3 — gate_policy wired in stop-ideation.sh**.
   `bin/frw.d/hooks/stop-ideation.sh` reads `gate_policy` via the resolver
   rather than a direct `yq` on `definition.yaml`. Ad-hoc yaml read removed.

4. **AC4 — preferred_specialists first consumer created**.
   `skills/shared/specialist-delegation.md` documents a lookup step at
   decompose-time specialist selection that calls
   `resolve_config_value "preferred_specialists.<role>"` and falls back to
   the existing selection logic when the result is empty. This is explicitly
   a net-new consumer (research confirmed zero consumers today).

5. **AC5 — No duplicate helper introduced**. `bin/frw.d/lib/common.sh` still
   contains exactly one definition of `resolve_config_value`; no new function
   named `get_config_field`, `resolve_with_default`, or similar is added.

6. **AC6 — Doctor audit enumerates fields vs consumers**.
   `bin/frw.d/scripts/doctor-config-audit.sh` exists, is mode 100755, and
   emits a non-gating warning line for any config field that has zero
   resolver call sites. Exit code is 0 regardless of warnings.

7. **AC7 — Integration test covers all three layers**.
   `tests/integration/test-config-resolution.sh` exists and asserts, for each
   of the three fields, that (a) a project-local override wins, (b) an XDG
   value wins when no project file, (c) the compiled-in
   `${FURROW_ROOT}/.furrow/furrow.yaml` default is returned when neither
   project nor XDG set the field.

## Test Scenarios

### Scenario: project override beats XDG for gate_policy
- **Verifies**: AC2, AC7
- **WHEN**: fixture project has `.furrow/furrow.yaml` with `gate_policy: strict`,
  AND `${XDG_CONFIG_HOME}/furrow/config.yaml` has `gate_policy: supervised`,
  AND `bin/rws gate-policy <row>` is invoked
- **THEN**: stdout equals `strict`
- **Verification**:
  ```sh
  XDG_CONFIG_HOME="$TMP/config" FURROW_ROOT="$TMP/furrow" \
    bin/rws gate-policy demo-row | grep -q '^strict$'
  ```

### Scenario: XDG fallback honored when no project file
- **Verifies**: AC2, AC3, AC7
- **WHEN**: project has no `.furrow/furrow.yaml`, XDG config sets
  `gate_policy: strict`, `bin/rws gate-policy <row>` invoked
- **THEN**: stdout equals `strict`
- **Verification**:
  ```sh
  rm -f "$TMP/project/.furrow/furrow.yaml"
  XDG_CONFIG_HOME="$TMP/config" bin/rws gate-policy demo-row | grep -q '^strict$'
  ```

### Scenario: compiled-in default returned for unset field
- **Verifies**: AC2, AC5, AC7
- **WHEN**: neither project nor XDG sets `gate_policy`; FURROW_ROOT's
  compiled-in `.furrow/furrow.yaml` has no such key either
- **THEN**: `bin/rws gate-policy` emits `supervised` (caller-side default via
  `|| value="supervised"` idiom)
- **Verification**:
  ```sh
  bin/rws gate-policy demo-row | grep -q '^supervised$'
  ```

### Scenario: preferred_specialists lookup returns project override
- **Verifies**: AC4, AC7
- **WHEN**: project `.furrow/furrow.yaml` contains
  `preferred_specialists: { harness: harness-engineer-beta }`, AND
  decompose-time lookup invokes `resolve_config_value
  "preferred_specialists.harness"`
- **THEN**: stdout equals `harness-engineer-beta`
- **Verification**:
  ```sh
  bash -c '. bin/frw.d/lib/common.sh; resolve_config_value preferred_specialists.harness' \
    | grep -q '^harness-engineer-beta$'
  ```

### Scenario: preferred_specialists lookup empty → fallback logic runs
- **Verifies**: AC4
- **WHEN**: no project/XDG/compiled-in override for `preferred_specialists.foo`
- **THEN**: `resolve_config_value` exits 1 and the caller in
  `specialist-delegation.md` documents fallback to the pre-existing selection
- **Verification**:
  ```sh
  if resolve_config_value preferred_specialists.foo >/dev/null; then
    echo "expected non-zero exit" >&2; exit 1
  fi
  ```

### Scenario: doctor audit warns on unreferenced field
- **Verifies**: AC6
- **WHEN**: a synthetic new field `test.unused` is added to the audit script's
  known-field list but no resolver call site references it
- **THEN**: `bin/frw.d/scripts/doctor-config-audit.sh` prints a warning line
  containing `test.unused` and exits 0
- **Verification**:
  ```sh
  bin/frw.d/scripts/doctor-config-audit.sh | grep -q 'test.unused'
  echo "exit=$?"   # must be 0
  ```

### Scenario: no duplicate resolver helper added
- **Verifies**: AC5
- **WHEN**: codebase is grepped for likely duplicates after this deliverable
  lands
- **THEN**: grep returns exactly one definition of `resolve_config_value` and
  zero matches for the forbidden names
- **Verification**:
  ```sh
  test "$(grep -rn '^resolve_config_value()' bin/ | wc -l)" = "1"
  ! grep -rn 'get_config_field()\|resolve_with_default()' bin/
  ```

## Implementation Notes

- **Resolver reuse only (AD-1, constraint)**. Do NOT introduce a
  default-accepting wrapper. Callers use the `|| value="default"` idiom.
- **Diff discipline**. Each consumer rewire is a small, surgical replacement
  of an ad-hoc `yq` read with a resolver call. No refactor of surrounding
  logic.
- **Reference pattern for resolver caller** (AD-1 quote):
  ```sh
  gate_policy=$(resolve_config_value gate_policy) || gate_policy="supervised"
  ```
- **preferred_specialists is additive (AD-7, R3)**. Document the new lookup
  step in `skills/shared/specialist-delegation.md`; the field's schema in
  `docs/architecture/config-resolution.md` already describes it as a map of
  `role-name → specialist-name`. Fallback when unset is the existing
  decompose-time selection heuristic — do not redesign that heuristic here.
- **Doctor integration**. The audit script is added as a script file and
  shelled out from the existing doctor subcommand (single-line addition).
  `bin/frw` itself is not in the file_ownership list and must not be modified.
- **Sandbox**. All tests adopt `tests/integration/lib/sandbox.sh::setup_sandbox`
  (from wave-1 `test-isolation-guard`). No test touches the live worktree.
- **POSIX sh**. All shell scripts use POSIX sh unless they already declare
  `#!/usr/bin/env bash`.
- **Out of scope**: `cross_model.provider` call-site rewire (lines 79, 280,
  446, 631 in `cross-model-review.sh`) — belongs to the wave-3
  `cross-model-per-deliverable-diff` deliverable, which depends on this one.

## Dependencies

- **Upstream deliverables**:
  - `test-isolation-guard` (wave-1): provides `setup_sandbox` helper used by
    `tests/integration/test-config-resolution.sh`.
- **Scripts/libs consumed**:
  - `bin/frw.d/lib/common.sh` — `resolve_config_value()` function (read-only
    dependency; no API change).
- **Downstream consumers**:
  - `cross-model-per-deliverable-diff` (wave-3) depends on this deliverable
    for the resolver adoption in `cross-model-review.sh`.
- **Docs**: `docs/architecture/config-resolution.md` is the authoritative
  field→consumer→test table; updated in this deliverable.

## File Ownership

Per plan.json:
- `bin/frw.d/lib/common.sh`
- `bin/frw.d/scripts/doctor-config-audit.sh`
- `bin/rws`
- `bin/frw.d/hooks/stop-ideation.sh`
- `skills/shared/specialist-delegation.md`
- `docs/architecture/config-resolution.md`
- `tests/integration/test-config-resolution.sh`
