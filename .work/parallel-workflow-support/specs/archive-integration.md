# Spec: Archive Integration with Focus

Update `scripts/archive-work.sh` to clear `.work/.focused` when archiving the focused unit.

## Current Archive Flow

`archive-work.sh <name>` validates four pre-conditions (step=review, status=completed, all
deliverables completed, passing final gate), then sets `archived_at` via `update-state.sh`
and regenerates `summary.md`. The work directory stays on disk.

## Change

After the archive succeeds (post `update-state.sh`), check whether the archived unit is
the currently focused unit and clear focus if so.

### Insertion Point

Between the `update-state.sh` call (line 91-92) and the `regenerate-summary.sh` call
(line 96). This ensures focus is cleared only after the archive write succeeds but before
the final summary regeneration.

### Logic

```sh
# --- clear focus if this was the focused unit ---

focused_file=".work/.focused"
if [ -f "${focused_file}" ]; then
  focused_name="$(cat "${focused_file}")"
  if [ "${focused_name}" = "${name}" ]; then
    rm -f "${focused_file}"
  fi
fi
```

Alternatively, source `hooks/lib/common.sh` and use `clear_focus`:

```sh
. "$(cd "$(dirname "$0")/../hooks/lib" && pwd)/common.sh"

focused_file=".work/.focused"
if [ -f "${focused_file}" ]; then
  focused_name="$(cat "${focused_file}")"
  if [ "${focused_name}" = "${name}" ]; then
    clear_focus
  fi
fi
```

**Preferred approach**: Inline the logic (first variant). `archive-work.sh` currently does
not source `common.sh`, and adding a dependency for a 5-line block is unnecessary coupling.

### Design Decision

- No auto-rotate to next active unit. After clearing focus, the next `/work` invocation
  will either find a single active unit (auto-focus) or prompt the user to choose.
- Archiving a non-focused unit leaves `.work/.focused` untouched.

## Edge Cases

| Scenario | `.focused` state | Behavior |
|----------|-----------------|----------|
| No `.focused` file exists | absent | Skip the block entirely; archive proceeds normally |
| `.focused` names a different unit | present, mismatched | `focused_name != name`, no action taken |
| `.focused` names the unit being archived | present, matches | `rm -f` removes the file |
| `.focused` is empty | present, empty string | `"" != name`, no action taken (correct) |

## Testing

| Case | Setup | Verify |
|------|-------|--------|
| Archive focused unit clears `.focused` | Create unit, focus it, complete through review, archive | `.work/.focused` does not exist |
| Archive non-focused unit preserves `.focused` | Create two units, focus unit A, archive unit B | `.work/.focused` still contains "unit-a" |
| Archive without `.focused` file | Ensure no `.focused` exists, archive a unit | No error, archive succeeds |
