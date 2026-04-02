# Spec: focus-infrastructure

## Overview
Add 4 new functions to `hooks/lib/common.sh` and introduce the `.work/.focused` file
as the focus-tracking primitive. All other deliverables depend on this.

## File: `.work/.focused`
- Plain text file containing a single line: the kebab-case work unit name (no path, no newline)
- Example content: `parallel-workflow-support`
- Git-tracked (lives inside `.work/`)
- Created by `set_focus()`, deleted by `clear_focus()`
- Not required to exist — absence is a normal state (single-unit or fresh session)

## Function: `extract_unit_from_path()`

```
# extract_unit_from_path <file_path> — extract work unit directory from a file path
# Args:
#   file_path — any file path (absolute or relative)
# Returns:
#   The work unit directory (e.g., ".work/my-unit") if path is inside .work/{name}/,
#   or empty string if not a work unit path.
# Exit code: always 0
```

Implementation:
1. Use `is_work_unit_file()` as a fast pre-check
2. Extract the unit name from the path using shell parameter expansion or sed
3. Handle both relative (`.work/name/...`) and absolute (`/full/path/.work/name/...`) paths
4. Validate that `.work/{name}/state.json` exists before returning
5. Return the relative path `.work/{name}` (not absolute)

Edge cases:
- Path is `.work/.focused` itself → return empty (not a unit directory)
- Path is `.work/_meta.yaml` → return empty (not a unit directory)
- Path is `.work/name/` with no subpath → return `.work/name`
- Path contains `.work` as a substring but not as a directory → return empty

## Function: `find_focused_work_unit()`

```
# find_focused_work_unit — find the focused work unit directory
# Returns the path to the focused work unit directory, or empty string.
# Semantics: .focused file is a cache. Validate on read, fallback on invalid.
# Exit code: always 0
```

Implementation:
1. If `.work/.focused` exists and is non-empty:
   a. Read the unit name from it
   b. Validate `.work/{name}/state.json` exists
   c. Validate `archived_at` is null (unit is active)
   d. If valid, return `.work/{name}`
   e. If invalid, log a warning and fall through to fallback
2. Fallback: call `find_active_work_unit()` (returns most-recently-updated active unit)
3. Return whatever `find_active_work_unit()` returns (may be empty)

Key behaviors:
- Never errors on stale/invalid `.focused` — always degrades gracefully
- Does NOT auto-repair `.focused` on invalid state (callers decide whether to set_focus)
- Single active unit: returns it regardless of `.focused` state (backward compatible)
- Zero active units: returns empty string

## Function: `set_focus()`

```
# set_focus <name> — set the focused work unit
# Args:
#   name — kebab-case work unit name
# Exit code: 0 on success, 1 if unit doesn't exist or is archived
```

Implementation:
1. Validate `.work/{name}/state.json` exists
2. Validate `archived_at` is null
3. Write `{name}` to `.work/.focused` (printf, no trailing newline)
4. Return 0

## Function: `clear_focus()`

```
# clear_focus — remove the focus file
# Exit code: always 0
```

Implementation:
1. Remove `.work/.focused` if it exists (`rm -f`)
2. Always return 0 (idempotent)

## Acceptance Criteria Verification

| Criterion | How to verify |
|-----------|---------------|
| set_focus/clear_focus write/delete .focused | Create unit, set_focus, cat .focused, clear_focus, test -f .focused |
| find_focused_work_unit validates and falls back | Set .focused to archived unit name, verify fallback to active |
| extract_unit_from_path parses correctly | Test with .work/name/file, .work/.focused, /abs/path/.work/name/file, non-work-path |
| POSIX sh compatible | Run with dash or sh, not bash |
| Backward compatible | Single active unit without .focused file works identically |
