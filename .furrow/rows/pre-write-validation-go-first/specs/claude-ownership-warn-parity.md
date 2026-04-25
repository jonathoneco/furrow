# Spec: claude-ownership-warn-parity (D6, wave 6)

## Interface Contract

### `bin/frw.d/hooks/ownership-warn.sh` — rewrite

The hook continues to be a PreToolUse hook for Write and Edit (no signature change). The body changes:

```sh
hook_ownership_warn() {
  input="$(cat)"
  target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""
  [ -z "$target_path" ] && return 0

  # Resolve the row context from the path or focused row
  work_dir="$(extract_row_from_path "$target_path")"
  [ -z "$work_dir" ] && work_dir="$(find_focused_row)"
  [ -z "$work_dir" ] && return 0

  # NEW: read deliverables[].file_ownership from definition.yaml (was: plan.json.waves[].assignments[].file_ownership)
  def_file="$work_dir/definition.yaml"
  [ ! -f "$def_file" ] && return 0

  ownership_globs="$(yq -r '
    [.deliverables[]?.file_ownership[]?] | unique | .[]
  ' "$def_file" 2>/dev/null)" || ownership_globs=""

  # Graceful no-op for mid-init rows with zero deliverables
  [ -z "$ownership_globs" ] && return 0

  # NEW: step gating REMOVED (was: skip if state.step != implement)

  _matched=0
  _IFS_SAVE="$IFS"; IFS="$(printf '\n')"
  for _glob in $ownership_globs; do
    case "$target_path" in
      $_glob) _matched=1; break ;;
    esac
  done
  IFS="$_IFS_SAVE"

  if [ "$_matched" -eq 0 ]; then
    log_warning "File write outside file_ownership: $target_path (definition.yaml deliverables: $(echo "$ownership_globs" | tr '\n' ', ' | sed 's/,$//'))"
  fi

  return 0
}
```

Key changes from current shell:
1. Read globs from `.deliverables[].file_ownership` (definition.yaml) instead of `.waves[].assignments[].file_ownership` (plan.json).
2. No `current_step != implement` early-return — fires in any step.
3. Warn-not-block preserved: always returns 0.
4. Graceful no-op when definition.yaml lacks deliverables (mid-init rows).

### parity-verification.md — D6 appends Claude rows

D6 fills the "Claude hook outcome" column for the 3 paired scenarios D5 set up in wave 5:

- Row 1 (in_scope match): Claude side → silent (log_warning NOT called)
- Row 2 (out_of_scope): Claude side → `log_warning` fires with the path + glob list
- Row 3 (not_applicable): Claude side → silent (no row context resolvable, hook returns early)

D6 also fills the `## Methodology` section with the test commands run.

## Acceptance Criteria (Refined)

1. `bin/frw.d/hooks/ownership-warn.sh` reads from `definition.yaml.deliverables[].file_ownership` via `yq`, not from `plan.json.waves[].assignments[].file_ownership`.
2. Hook fires regardless of `state.json.step`. Verified manually by editing an outside-ownership file in `plan` or `spec` step and observing `log_warning` output.
3. Hook always returns 0 (warn-not-block preserved). Confirmed by `echo $?` after invocation with an outside-ownership write.
4. Graceful no-op when `definition.yaml` exists but `deliverables` array is empty/absent (e.g., mid-init rows). Verified by running on a fresh row with no deliverables — no spurious warnings.
5. Graceful no-op when no row context is resolvable (path outside any `.furrow/rows/` tree AND no focused row).
6. `shellcheck bin/frw.d/hooks/ownership-warn.sh` passes with no warnings.
7. `.furrow/rows/pre-write-validation-go-first/parity-verification.md` Claude columns filled with concrete observations for the 3 paired scenarios D5 scaffolded; Methodology section documents the test commands run.
8. Manual verification recorded in commit body: outside-ownership in plan step triggers warning; inside-ownership silent; mid-init no-op confirmed.
9. Malformed-YAML behavior is silent no-op (accepted UX): when `yq` parse fails on a corrupt definition.yaml, `2>/dev/null || ownership_globs=""` masks the error; this is intentional because the hook is advisory-only and cannot block writes regardless. The schema-validation D1 hook (separately) is the canonical surface for malformed-YAML signal; D6 stays out of that responsibility.
10. Modify-region discipline for parity-verification.md: D6 modifies ONLY the "Claude hook outcome" column (rightmost-but-one in the paired-scenarios table) and the "## Methodology" section (appending Claude-side test commands). D6 MUST NOT edit the table header, separator row, "Scenario"/"Input"/"Verdict"/"Pi outcome"/"Notes" columns, or any other part of the file authored by D5.

## Test Scenarios

### Scenario: outside-ownership-during-plan-step
- **Verifies**: AC #1, #2, #3, #6
- **WHEN**: hook stdin contains `{"tool_name": "Edit", "tool_input": {"file_path": "/some/random/file.go"}}` for a row whose state.step=plan and definition.yaml's deliverables don't cover that path
- **THEN**: stdout/stderr contains "File write outside file_ownership"; exit code 0
- **Verification**: `bash -c 'echo "$INPUT" | bash bin/frw.d/hooks/ownership-warn.sh'` with crafted INPUT and a fixture row; assert exit 0 and warning string present

### Scenario: inside-ownership-silent
- **Verifies**: AC #1, #2, #3
- **WHEN**: hook stdin contains a path that matches one of the row's deliverables[].file_ownership globs
- **THEN**: no warning logged; exit code 0
- **Verification**: same as above but with a path that matches; assert no warning string

### Scenario: mid-init-row-no-op
- **Verifies**: AC #4
- **WHEN**: hook stdin path is inside `.furrow/rows/foo/` but `foo`'s definition.yaml has empty `deliverables: []`
- **THEN**: silent; exit 0
- **Verification**: fixture row with empty deliverables; assert no warning

### Scenario: no-row-context-no-op
- **Verifies**: AC #5
- **WHEN**: path is `/tmp/file.txt` and `.furrow/.focused` is empty
- **THEN**: silent; exit 0
- **Verification**: invoke hook with empty .furrow/.focused; assert no warning

### Scenario: shellcheck-clean
- **Verifies**: AC #6
- **WHEN**: `shellcheck bin/frw.d/hooks/ownership-warn.sh`
- **THEN**: zero warnings, zero errors
- **Verification**: `shellcheck bin/frw.d/hooks/ownership-warn.sh; echo $?` → 0

## Implementation Notes

- `yq` is already a dependency of the existing hook (used in validate-definition.sh). No new deps.
- `extract_row_from_path` and `find_focused_row` are existing helpers in `bin/frw.d/lib/common-minimal.sh`; reuse unchanged.
- The plan.json fallback from the previous implementation is intentionally NOT preserved — definition.yaml is the canonical source for file_ownership going forward.
- Manual verification: invoke the hook directly via `echo '{...}' | bash bin/frw.d/hooks/ownership-warn.sh` against fixture rows; observe log_warning output.

## Dependencies

- D2 (validate-ownership-go) — wave 3: D6 reads the same data source (`definition.yaml.deliverables[].file_ownership`) as D2; the two are functionally equivalent (D2 in Go for Pi consumption, D6 in shell for Claude). Their behaviors must match per the parity invariant.
- D5 (pi-ownership-warn-handler) — wave 5: D5 created `parity-verification.md` with the Pi-side rows; D6 appends Claude-side observations.
- `bin/frw.d/lib/common-minimal.sh` (existing): provides `extract_row_from_path`, `find_focused_row`, `log_warning`.
- `yq` (system dependency, already required by other hooks).
