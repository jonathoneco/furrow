# Spec: command-spec-fixes

## commands/furrow.md — 3 replacements
Replace `_rationale.yaml` with `.furrow/almanac/rationale.yaml` at lines 12, 31, 36.

## commands/triage.md — ~10 replacements
Replace `todos.yaml` with `.furrow/almanac/todos.yaml` in user-facing paths and error messages (lines 3, 17, 93, 215, 217, 221-222, 237, 238, 249).

## commands/work-todos.md — ~7 replacements
Replace `todos.yaml` with `.furrow/almanac/todos.yaml` (lines 3, 37, 112-113, 143, 172-173, 181).

## commands/next.md — ~5 replacements
Replace `todos.yaml` with `.furrow/almanac/todos.yaml` (lines 33, 55, 60, 88-90).

## commands/archive.md — ~6 replacements
Replace `todos.yaml` with `.furrow/almanac/todos.yaml` (lines 36, 38-39, 43, 46-48).

## bin/alm — remove fallback
Remove lines 55-56 (`elif [ -f "./todos.yaml" ]` fallback). The `ALM_TODOS` env var and explicit arg are sufficient.

## AC
- triage.md references .furrow/almanac/todos.yaml, not root todos.yaml
- All command specs reference .furrow/almanac/ paths
- bin/alm has no legacy ./todos.yaml fallback
