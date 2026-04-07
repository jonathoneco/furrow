# Spec: gate-check-hook-fix

## Interface Contract

File: `bin/frw.d/hooks/gate-check.sh`
Function: `hook_gate_check()`
Caller: `frw hook gate-check` (via settings.json PreToolUse:Bash)
Input: JSON on stdin with `tool_input.command`
Output: return 0 (allow) or return 2 (block with stderr message)

Behavior:
- Parse command string for `rws transition` invocations only
- Extract row name from `--request/--confirm <name>` argument position
- On `--request`: allow (return 0) — request creates the gate record
- On `--confirm`: check `has_passing_gate()` for the current boundary
- If passing gate exists: allow (return 0)
- If no passing gate: block (return 2) with error to stderr
- Non-transition commands: allow (return 0)

## Acceptance Criteria (Refined)

1. Regex correctly parses `rws transition --request <name>` and `bin/rws transition --confirm <name>` — extracts `<name>` not `--request`
2. Hook sources `common.sh` and uses `has_passing_gate()` instead of `rws gate-check`
3. `--request` commands always return 0 (gate doesn't exist yet)
4. `--confirm` commands check `has_passing_gate(state_file, boundary)` and block if no passing gate
5. Commands containing "transition" in heredoc/argument content (e.g., `rws update-summary ... transition-simplification`) do NOT trigger the hook — match pattern is `"rws transition "` or `"bin/rws transition "` as command prefix, not substring
6. Fallback to `.furrow/.focused` when row name can't be parsed from command

## Implementation Notes

- Hook is already partially implemented during research — finalize and verify
- Must also be copied to installed Furrow at `/home/jonco/src/furrow/bin/frw.d/hooks/gate-check.sh` (settings.json `frw` resolves to installed version via PATH symlink)
- `has_passing_gate()` is in `bin/frw.d/lib/common.sh:87` — already sourced by `frw hook` before the hook function runs (line 69 of `bin/frw`), so the explicit `. common.sh` in the hook is redundant but harmless
- Boundary computation: `current->next` from `state.json.steps_sequence`

## Dependencies

- `bin/frw.d/lib/common.sh` (has_passing_gate function)
- `bin/frw` hook dispatch (sources common.sh before hook)
