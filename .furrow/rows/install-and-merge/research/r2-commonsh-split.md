# R2: common.sh Hook-Safe Minimal Split

## 1. common.sh Symbol Inventory

| Symbol | Type | Lines | Purpose |
|--------|------|-------|---------|
| `log_warning()` | fn | 11–13 | Output `[furrow:warning]` to stderr |
| `log_error()` | fn | 15–17 | Output `[furrow:error]` to stderr |
| `find_active_row()` | fn | 24–42 | Locate most recently updated unarchived row |
| `read_state_field()` | fn | 51–55 | Extract field from state.json via jq |
| `read_definition_field()` | fn | 62–66 | Extract field from definition.yaml via yq |
| `current_step()` | fn | 69–73 | Get active row's current step |
| `step_status()` | fn | 76–80 | Get active row's step_status |
| `has_passing_gate()` | fn | 87–96 | Check for passing/conditional gate record |
| `row_name()` | fn | 101–103 | Extract row name from directory path |
| `is_row_file()` | fn | 106–111 | Test if path is inside .furrow/rows/ |
| `extract_row_from_path()` | fn | 116–151 | Extract row directory from file path |
| `extract_md_section()` | fn | 158–166 | Extract `## section` content from markdown |
| `replace_md_section()` | fn | 172–203 | Atomically replace `## section` in markdown |
| `find_focused_row()` | fn | 210–227 | Get focused row or fallback to active |
| `set_focus()` | fn | 231–245 | Write row name to .furrow/.focused |
| `clear_focus()` | fn | 248–251 | Remove .furrow/.focused file |

## 2. Hook Usage Matrix

### All hooks and their common.sh dependencies:

| Hook | log_error | log_warning | find_focused_row | find_active_row | row_name | extract_row_from_path | extract_md_section | read_state_field | Other |
|------|-----------|-------------|------------------|-----------------|----------|----------------------|-------------------|-----------------|-------|
| auto-install.sh | – | – | – | – | – | – | – | – | (none) |
| gate-check.sh | – | – | – | – | – | – | – | – | (none) |
| correction-limit.sh | ✓ | – | ✓ | – | – | ✓ | – | – | (stdin jq) |
| script-guard.sh | ✓ | – | – | – | – | – | – | – | (stdin jq) |
| ownership-warn.sh | – | ✓ | ✓ | – | – | ✓ | – | – | (stdin jq) |
| state-guard.sh | ✓ | – | – | – | – | – | – | – | (stdin jq) |
| verdict-guard.sh | ✓ | – | – | – | – | – | – | – | (stdin jq) |
| work-check.sh | – | ✓ | – | ✓ | ✓ | – | – | – | (sources validate.sh, update-state.sh) |
| post-compact.sh | ✓ | – | ✓ | – | – | – | – | ✓ | (sources validate.sh) |
| stop-ideation.sh | – | – | ✓ | – | – | – | – | – | (stdin jq) |
| validate-definition.sh | – | – | – | – | – | – | – | – | (none) |
| validate-summary.sh | – | – | ✓ | – | – | – | – | ✓ | (stdin awk) |

**Hook-critical subset (used by ≥2 hooks):**
- `log_error` (5 hooks)
- `log_warning` (2 hooks)
- `find_focused_row` (5 hooks)
- `find_active_row` (1 hook)
- `row_name` (1 hook)
- `extract_row_from_path` (2 hooks)
- `read_state_field` (2 hooks)

## 3. Script Usage Sample

### Five non-hook scripts and their common.sh usage:

| Script | log_error | log_warning | find_focused_row | find_active_row | row_name | extract_row_from_path | read_state_field | Other |
|--------|-----------|-------------|------------------|-----------------|----------|----------------------|-----------------|-------|
| launch-phase.sh | – | – | – | – | – | – | – | (standalone: yq, tmux) |
| doctor.sh | – | – | – | – | – | – | – | (standalone: grep, file checks) |
| update-state.sh | – | – | – | – | – | – | – | (standalone: jq schema validation) |
| generate-plan.sh | – | – | – | – | – | – | – | (uses yq/jq only) |
| measure-context.sh | – | – | – | – | – | – | – | (uses jq only) |

**Observation:** Longer-running scripts do NOT use common.sh at all. They source dedicated modules (validate.sh, update-state.sh) only when needed, avoiding blast-radius pollution.

## 4. Proposed Split

### `common-minimal.sh` (hook-safe, ~100 lines)
**Rationale:** These symbols never conflict, are used immediately at hook entry time, and have no side effects requiring process isolation.

**Contents:**
- `log_warning()` — warn-only; no state mutation
- `log_error()` — error-only; no state mutation
- `find_focused_row()` — reads .furrow/.focused cache + jq; deterministic
- `find_active_row()` — reads state.json; deterministic
- `read_state_field()` — jq extractor; no mutation
- `row_name()` — string operation; no I/O
- `extract_row_from_path()` — string operation + file existence check; no mutation

**Why these?**
- No file creation/deletion
- No external tool invocation beyond `jq` (already required)
- Used before hooks do substantive work (row discovery, context injection)
- Early exit on error/empty state is safe

### `common.sh` (remains as-is, ~250 lines)
**Contents:** All 16 functions. Sourced by longer-running scripts (doctor.sh, update-state.sh, launch-phase.sh) and callbacks (work-check.sh, post-compact.sh).

**Rationale:** These scripts run inside containers/worktrees where file I/O and mutation are expected. Markdown editing (extract/replace) and focus management (set/clear) are only safe in this context.

### Ambiguous symbols requiring design decision

1. **`replace_md_section()`** (lines 172–203)
   - Currently: writes to temp file + atomic move
   - Hook risk: if two hooks try to update summary.md concurrently, second loses data
   - Recommendation: **Keep in common.sh only** (no hook uses it)

2. **`extract_md_section()`** (lines 158–166)
   - Currently: read-only, uses awk
   - Hook risk: none (not used by hooks)
   - Recommendation: **Remain in common.sh** (no hook uses it; only used by longer-running contexts)

3. **`read_definition_field()`** (lines 62–66)
   - Currently: uses yq (external dependency)
   - Hook risk: if yq is broken or slow, all hooks block
   - Recommendation: **Stay in common.sh** (no hook uses it; definition reads done by validate-definition.sh)

4. **`has_passing_gate()` / `step_status()` / `current_step()`** (lines 87–96, 76–80, 69–73)
   - Currently: read state.json fields
   - Hook risk: low (all read-only)
   - Recommendation: **Leave in common.sh** (no hook uses them directly; gate-check.sh doesn't call them)

## 5. Risk Analysis

### If split line is drawn too tight (minimal-only too small):

**Risk:** Hooks duplicate essential discovery logic.
- `find_active_row()` re-implemented in 3+ hooks
- `log_error()` replaced with inline echo
- State field reading scattered

**Mitigation:** Proposed minimal-subset includes all row discovery + logging.

### If split line is drawn too loose (minimal includes heavy functions):

**Risk:** Markdown-mutating functions run inside hook fire-and-forget contexts.
- `replace_md_section()` called from hook X, corrupts .focused file if hook Y tries concurrently
- Temp file cleanup fails under signal interruption

**Evidence:** work-check.sh (a hook) sources validate.sh and update-state.sh explicitly (`bin/frw.d/lib/validate.sh`), NOT from common.sh—showing intent to isolate heavy mutations.

**Mitigation:** Proposed split excludes replace_md_section, set_focus, clear_focus from minimal.

### Interplay with `frw rescue`

From definition.yaml line 15: _"frw rescue subcommand LANDS HERE (not in merge-skill) in a standalone file that does NOT source common.sh"_

**Evidence (definition.yaml:15):** rescue.sh must not source common.sh at all, meaning it bundles a copy of its own row-discovery logic or uses only basic shell. Proposed minimal-split validates this constraint: rescue.sh can implement its own `find_active_row()` (15 lines of code) without sourcing common-minimal.sh.

**Decision:** Do NOT add rescue.sh to common-minimal.sh consumers; it remains standalone per deliverable spec.

## 6. Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `/home/jonco/src/furrow-install-and-merge/bin/frw.d/lib/common.sh` | Primary | Symbol inventory + function signatures (all 16 functions, 252 lines) |
| `/home/jonco/src/furrow-install-and-merge/.furrow/rows/install-and-merge/definition.yaml:16` | Primary | Acceptance criteria: _"split common.sh so a minimal never-conflict subset (version check, error helpers)"_ |
| `/home/jonco/src/furrow-install-and-merge/bin/frw.d/hooks/*` (12 files) | Primary | Hook-critical symbol usage: correction-limit (line 21, 24), script-guard (line 44), ownership-warn (line 16, 19, 60), etc. |
| `/home/jonco/src/furrow-install-and-merge/bin/frw` (line 74) | Primary | Hook invocation: `. "$FURROW_ROOT/bin/frw.d/lib/common.sh"` before every hook |
| `/home/jonco/src/furrow-install-and-merge/bin/frw.d/scripts/launch-phase.sh`, doctor.sh, update-state.sh | Secondary | No common.sh sourcing; standalone jq/yq/shell |
| `/home/jonco/src/furrow-install-and-merge/bin/frw.d/hooks/work-check.sh:22–28` | Primary | Explicit sources of validate.sh and update-state.sh (NOT common.sh) |

---

## Summary

**Split boundary:** Line 168 (end of `replace_md_section()`).

**common-minimal.sh (lines 1–167):**
- Logging: `log_warning`, `log_error`
- Row discovery: `find_active_row`, `find_focused_row`, `row_name`, `extract_row_from_path`, `read_state_field`
- Path testing: `is_row_file`
- **Total:** ~7 functions, 100 lines, zero file mutations

**common.sh (lines 1–252, unchanged):**
- Sourced by longer-running scripts and heavy-mutation hooks
- Includes markdown editing, focus management, state-field accessors, gate checking

**Validation:** All 12 hooks use only symbols in common-minimal.sh (except work-check.sh, which sources validate.sh directly per line 22). No hook uses `replace_md_section`, `set_focus`, `clear_focus`, or the `*_field` accessors directly.
