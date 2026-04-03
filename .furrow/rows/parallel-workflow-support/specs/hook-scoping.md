# Hook Scoping Spec

Refactor hooks from single-active-unit assumption to parallel-safe scoping.

## New Helpers (hooks/lib/common.sh)

Two new functions added alongside existing `find_active_work_unit()`:

```sh
# extract_unit_from_path <file_path>
# Extracts work unit directory from a .work/{name}/... path.
# Returns: ".work/{name}" or "" if path is not inside .work/.
extract_unit_from_path() {
  case "$1" in
    .work/*/*)
      echo ".work/$(echo "$1" | cut -d/ -f2)"
      ;;
    *) echo "" ;;
  esac
}

# find_focused_work_unit
# Reads .work/.focused to get the currently focused unit.
# Returns: ".work/{name}" or "" if .focused is missing/empty/invalid.
find_focused_work_unit() {
  _focused_file=".work/.focused"
  [ -f "$_focused_file" ] || { echo ""; return; }
  _name="$(cat "$_focused_file" 2>/dev/null)" || { echo ""; return; }
  _name="$(echo "$_name" | tr -d '[:space:]')"
  [ -n "$_name" ] && [ -d ".work/$_name" ] || { echo ""; return; }
  echo ".work/$_name"
}
```

The existing `find_active_work_unit()` is retained for backward compatibility but
is no longer called by any hook. It remains available for external scripts.

---

## Path-Scoped Hooks

### Common Pattern

All four path-scoped hooks share the same resolution strategy:

```
1. Extract unit from target file path via extract_unit_from_path()
2. If empty (file not inside .work/), fall back to find_focused_work_unit()
3. If still empty, exit 0 (no unit to act on)
```

---

### 1. timestamp-update.sh

**Hook type:** PostToolUse (Write|Edit)

**Current behavior:**
- Extracts `file_path` from stdin JSON (line 24)
- Early-exits if path not inside `.work/` (lines 27-29)
- Calls `find_active_work_unit()` to get the work dir (line 32)
- Updates `updated_at` via `update-state.sh` (line 42)

**Bug:** When two units are active, a write to `.work/unit-a/summary.md` could
update `unit-b`'s timestamp if `unit-b` was more recently updated.

**Changes:**

Replace lines 32-38:
```sh
work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi

unit_name="$(work_unit_name "$work_dir")"
```

With:
```sh
work_dir="$(extract_unit_from_path "$target_path")"

if [ -z "$work_dir" ]; then
  work_dir="$(find_focused_work_unit)"
fi

if [ -z "$work_dir" ]; then
  exit 0
fi

unit_name="$(work_unit_name "$work_dir")"
```

**Edge cases:**
- Path like `.work/.focused` (not inside a unit subdir) -- `extract_unit_from_path`
  returns empty, falls back to focused. Harmless: timestamp update for focused unit
  is reasonable.
- Archived unit directory still on disk -- timestamp update is a no-op since
  `update-state.sh` should validate the unit is active.

---

### 2. ownership-warn.sh

**Hook type:** PreToolUse (Write|Edit)

**Current behavior:**
- Calls `find_active_work_unit()` immediately (line 24)
- Reads step from state.json, exits if not `implement` (lines 30-35)
- Checks target path against `plan.json` file_ownership globs (lines 50-71)

**Bug:** With parallel units, ownership check could use the wrong unit's plan.json,
producing false warnings or missing real violations.

**Changes:**

Replace lines 24-28:
```sh
work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi
```

With:
```sh
target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

work_dir="$(extract_unit_from_path "$target_path")"

if [ -z "$work_dir" ]; then
  work_dir="$(find_focused_work_unit)"
fi

if [ -z "$work_dir" ]; then
  exit 0
fi
```

Note: `target_path` extraction must move **above** the work_dir resolution since
the current code extracts it later (line 37). Reorder so `target_path` is
extracted first, then used for both unit resolution and ownership checking.

**Edge cases:**
- Write to a file outside `.work/` during implement step -- falls back to focused
  unit, which is the correct unit to check ownership against.
- No focused unit set -- exits silently, which is acceptable for an advisory hook.

---

### 3. summary-regen.sh

**Hook type:** PostToolUse (Write|Edit)

**Current behavior:**
- Extracts `file_path`, early-exits if not inside `.work/` (lines 25-31)
- Calls `find_active_work_unit()` (line 33)
- Checks if step_status is `completed` (lines 39-43)
- Calls `regenerate-summary.sh` with unit name (line 50)

**Bug:** Write to `.work/unit-a/state.json` (via update-state.sh) could trigger
summary regen for `unit-b` if `unit-b` was most-recently-updated.

**Changes:**

Replace lines 33-37:
```sh
work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi
```

With:
```sh
work_dir="$(extract_unit_from_path "$target_path")"

if [ -z "$work_dir" ]; then
  work_dir="$(find_focused_work_unit)"
fi

if [ -z "$work_dir" ]; then
  exit 0
fi
```

**Edge cases:**
- `target_path` is already guaranteed to be inside `.work/` by the case guard on
  line 28, so `extract_unit_from_path` will always succeed here. The fallback
  exists only for defensive consistency with the other path-scoped hooks.

---

### 4. correction-limit.sh

**Hook type:** PreToolUse (Write|Edit)

**Current behavior:**
- Inline work unit discovery loop (lines 27-35) -- finds the first active unit,
  not the most recent. Does not source `common.sh`.
- Checks step is `implement`, reads correction counts from state.json and
  file_ownership from plan.json.

**Bug:** With multiple active units, the inline loop picks whichever unit sorts
first alphabetically. A write to a file owned by `unit-b` could be checked
against `unit-a`'s correction limits (or not at all).

**Changes:**

1. Source `common.sh` (add library loading preamble like other hooks).

2. Replace the inline discovery loop (lines 26-35):
```sh
work_dir=""
for state_file in .work/*/state.json; do
  [ -f "${state_file}" ] || continue
  archived="$(jq -r '.archived_at // "null"' "${state_file}" 2>/dev/null)" || continue
  if [ "${archived}" = "null" ]; then
    work_dir="$(dirname "${state_file}")"
    break
  fi
done
```

With:
```sh
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$HOOK_DIR/.." && pwd)"
COMMON_LIB="$HARNESS_ROOT/hooks/lib/common.sh"

if [ ! -f "$COMMON_LIB" ]; then
  exit 0
fi

# shellcheck source=lib/common.sh
. "$COMMON_LIB"

work_dir="$(extract_unit_from_path "$file_path")"

if [ -z "$work_dir" ]; then
  work_dir="$(find_focused_work_unit)"
fi
```

3. Add archived-unit check: after resolving `work_dir`, verify the unit is
   actually active (not archived):
```sh
if [ -z "$work_dir" ] || [ ! -f "$work_dir/state.json" ]; then
  exit 0
fi

archived="$(jq -r '.archived_at // "null"' "$work_dir/state.json" 2>/dev/null)" || archived="null"
if [ "$archived" != "null" ]; then
  exit 0
fi
```

**Edge cases:**
- `file_path` matches file_ownership globs in multiple units -- only the unit
  extracted from the path (or focused unit) is checked. This is correct because
  file_ownership is per-unit, not global.
- `file_path` outside `.work/` -- falls back to focused unit, checks its
  correction limits. Correct: the focused unit is the one being implemented.

---

## Command-Scoped Hook

### 5. gate-check.sh

**Hook type:** PreToolUse (Bash)

**Current behavior:**
- Checks if the bash command contains `advance-step` (lines 30-33)
- Calls `find_active_work_unit()` (line 35)
- Validates gate records in the resolved unit's state.json (line 47)

**Bug:** With parallel units, advancing `unit-a` could be validated against
`unit-b`'s gates if `unit-b` was more recently updated.

**Changes:**

The `advance-step.sh` script takes the unit name as its first argument:
```
scripts/advance-step.sh <unit-name>
```

Replace lines 35-39:
```sh
work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi
```

With:
```sh
# Extract unit name from command: advance-step.sh <unit-name> [...]
unit_name="$(echo "$command_str" | sed -n 's/.*advance-step[^ ]* \+\([^ ]*\).*/\1/p')"

if [ -n "$unit_name" ]; then
  work_dir=".work/$unit_name"
else
  # Fallback: try focused unit
  work_dir="$(find_focused_work_unit)"
fi

if [ -z "$work_dir" ] || [ ! -f "$work_dir/state.json" ]; then
  exit 0
fi
```

**Edge cases:**
- `advance-step.sh` called without arguments -- `unit_name` is empty, falls back
  to focused unit. The advance-step script itself should validate args, so
  gate-check just needs to not crash.
- Command string contains `advance-step` as substring in another word (unlikely
  but possible) -- the sed pattern requires whitespace after the script name,
  reducing false matches.
- Unit name in command doesn't match an existing directory -- the
  `[ ! -f "$work_dir/state.json" ]` guard catches this.

---

## Focus-Scoped Hooks

### Common Pattern

All three focus-scoped hooks share the same resolution strategy:

```
1. Call find_focused_work_unit()
2. If empty, exit 0 (graceful degradation -- no focused unit means nothing to check)
```

---

### 6. stop-ideation.sh

**Hook type:** Stop

**Current behavior:**
- Inline work unit discovery loop (lines 22-30) -- same first-active-unit pattern
  as correction-limit.sh.
- Checks if step is `ideate`, checks gate_policy, validates section markers.

**Changes:**

1. Source `common.sh` (add library loading preamble).

2. Replace inline discovery loop (lines 22-30):
```sh
work_dir=""
for state_file in .work/*/state.json; do
  [ -f "${state_file}" ] || continue
  archived="$(jq -r '.archived_at // "null"' "${state_file}" 2>/dev/null)" || continue
  if [ "${archived}" = "null" ]; then
    work_dir="$(dirname "${state_file}")"
    break
  fi
done
```

With:
```sh
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$HOOK_DIR/.." && pwd)"
COMMON_LIB="$HARNESS_ROOT/hooks/lib/common.sh"

if [ ! -f "$COMMON_LIB" ]; then
  exit 0
fi

# shellcheck source=lib/common.sh
. "$COMMON_LIB"

work_dir="$(find_focused_work_unit)"
```

**Edge cases:**
- `.work/.focused` missing at session end -- exits 0, which is safe. If no unit
  is focused, there's nothing to validate.
- `.work/.focused` points to an archived unit -- `find_focused_work_unit` checks
  `[ -d ".work/$_name" ]` but does not check archived status. Add an archived
  check after resolution:
  ```sh
  if [ -n "$work_dir" ]; then
    archived="$(jq -r '.archived_at // "null"' "$work_dir/state.json" 2>/dev/null)" || archived="null"
    if [ "$archived" != "null" ]; then
      exit 0
    fi
  fi
  ```

---

### 7. validate-summary.sh

**Hook type:** Stop

**Current behavior:**
- Inline work unit discovery loop (lines 19-27) -- same first-active-unit pattern.
- Validates summary.md sections and content depth.

**Changes:**

1. Source `common.sh` (add library loading preamble).

2. Replace inline discovery loop (lines 19-27):
```sh
work_dir=""
for state_file in .work/*/state.json; do
  [ -f "${state_file}" ] || continue
  archived="$(jq -r '.archived_at // "null"' "${state_file}" 2>/dev/null)" || continue
  if [ "${archived}" = "null" ]; then
    work_dir="$(dirname "${state_file}")"
    break
  fi
done
```

With:
```sh
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$HOOK_DIR/.." && pwd)"
COMMON_LIB="$HARNESS_ROOT/hooks/lib/common.sh"

if [ ! -f "$COMMON_LIB" ]; then
  exit 0
fi

# shellcheck source=lib/common.sh
. "$COMMON_LIB"

work_dir="$(find_focused_work_unit)"
```

3. Update `state_file` assignment (line 32) to use the new work_dir variable
   (no change needed since the variable name is the same, but the inline
   `state_file` from the loop is no longer in scope -- must reassign):
```sh
state_file="${work_dir}/state.json"
```

**Edge cases:**
- Same as stop-ideation.sh: `.focused` missing means exit 0 (no validation needed
  if no unit is focused).
- Summary validation for a non-focused unit is intentionally skipped. Each unit's
  summary is validated only when it is focused (i.e., being actively worked on).

---

### 8. post-compact.sh

**Hook type:** PostCompact

**Current behavior:**
- Calls `find_active_work_unit()` (line 24)
- Validates state integrity
- Outputs step context, deliverable progress, and summary.md to stdout for
  re-injection

**Bug:** With parallel units, compaction recovery shows whichever unit was
most-recently-updated, not necessarily the one the agent was working on.

**Changes:**

Replace lines 24-29:
```sh
work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  echo "No active work unit. Start with /work."
  exit 0
fi
```

With:
```sh
work_dir="$(find_focused_work_unit)"

if [ -z "$work_dir" ]; then
  echo "No focused work unit. Run /work to focus a unit."
  exit 0
fi
```

Additionally, do NOT add any "other active units" listing. Post-compact recovery
is strictly for the focused unit. Dormant units are irrelevant to context recovery
and would waste the re-injection budget.

**Edge cases:**
- `.focused` missing after compaction -- outputs the "no focused" message. The
  `/reground` command (invoked by the PostCompact rule) will handle broader
  recovery.
- `.focused` points to a unit whose state.json is corrupt -- the existing
  `validate_state_json` check (line 39) catches this and exits 1, which is
  correct behavior.

---

## All-Units Hook

### 9. work-check.sh

**Hook type:** Stop

**Current behavior:**
- Calls `find_active_work_unit()` (line 22) -- checks exactly one unit
- Validates state.json integrity and summary.md sections
- Updates timestamp

**Bug:** Only the most-recently-updated unit gets validated at session end.
Other active units are silently skipped.

**Changes:**

Replace lines 22-30:
```sh
work_dir="$(find_active_work_unit)"

if [ -z "$work_dir" ]; then
  exit 0
fi

state_file="$work_dir/state.json"
summary_file="$work_dir/summary.md"
unit_name="$(work_unit_name "$work_dir")"
```

With an all-units iteration:
```sh
# Collect all active work units
active_units=""
for _state_file in .work/*/state.json; do
  [ -f "$_state_file" ] || continue
  _archived="$(jq -r '.archived_at // "null"' "$_state_file" 2>/dev/null)" || continue
  if [ "$_archived" = "null" ]; then
    active_units="${active_units} $(dirname "$_state_file")"
  fi
done

if [ -z "$active_units" ]; then
  exit 0
fi
```

Then wrap the existing validation + timestamp logic in a loop:
```sh
for work_dir in $active_units; do
  state_file="$work_dir/state.json"
  summary_file="$work_dir/summary.md"
  unit_name="$(work_unit_name "$work_dir")"

  # Validate state.json integrity
  if [ -f "$VALIDATE_LIB" ]; then
    . "$VALIDATE_LIB"
    if ! validate_state_json "$state_file" 2>/dev/null; then
      log_warning "state.json validation failed for $unit_name"
    fi
  fi

  # Validate summary.md sections (existing logic, unchanged)
  ...

  # Update timestamp
  if [ -x "$update_script" ] && [ -n "$unit_name" ]; then
    "$update_script" "$unit_name" ".updated_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" 2>/dev/null || true
  fi
done
```

Move `update_script` assignment before the loop:
```sh
update_script="$HARNESS_ROOT/scripts/update-state.sh"
```

**Edge cases:**
- Many active units (10+) -- the hook is non-blocking and runs at session end,
  so minor latency is acceptable. No pagination needed.
- One unit's validation fails -- `log_warning` is emitted but the loop continues
  to check remaining units. Each unit is independent.
- No active units (all archived) -- `active_units` is empty, exits 0.

---

## Unchanged Hooks (confirmation)

### validate-definition.sh -- No Change

Already path-based. Uses `file_path` from stdin JSON to find the definition.yaml
being written. Does not call `find_active_work_unit()`. No scoping change needed.

### state-guard.sh -- No Change

Blocks all `state.json` writes regardless of which unit. The guard pattern-matches
`*/state.json` in the target path. No scoping change needed.

---

## Implementation Checklist

1. [ ] Add `extract_unit_from_path()` to `hooks/lib/common.sh`
2. [ ] Add `find_focused_work_unit()` to `hooks/lib/common.sh`
3. [ ] Refactor `timestamp-update.sh` -- path-scoped
4. [ ] Refactor `ownership-warn.sh` -- path-scoped, reorder target_path extraction
5. [ ] Refactor `summary-regen.sh` -- path-scoped
6. [ ] Refactor `correction-limit.sh` -- path-scoped, add common.sh sourcing
7. [ ] Refactor `gate-check.sh` -- command-scoped, extract unit from command args
8. [ ] Refactor `stop-ideation.sh` -- focus-scoped, add common.sh sourcing
9. [ ] Refactor `validate-summary.sh` -- focus-scoped, add common.sh sourcing
10. [ ] Refactor `post-compact.sh` -- focus-scoped, remove dormant unit listing
11. [ ] Refactor `work-check.sh` -- all-units iteration loop
12. [ ] Add archived-unit guard to focus-scoped hooks (stop-ideation, validate-summary)

## Testing Strategy

- **Unit tests for new helpers:** Verify `extract_unit_from_path` with paths inside
  `.work/`, outside `.work/`, and edge cases (`.work/.focused`, `.work/` root).
- **Integration tests per hook:** Create two active units, verify each hook scopes
  to the correct one based on its strategy.
- **Fallback tests:** Verify path-scoped hooks fall back to focused unit when path
  is outside `.work/`. Verify focus-scoped hooks degrade gracefully when
  `.work/.focused` is missing.
- **work-check.sh iteration test:** Create 3 active units, verify all 3 are
  validated at session end.
