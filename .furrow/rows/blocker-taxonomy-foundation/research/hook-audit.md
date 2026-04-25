# Hook Migration Audit — Blocker Emission

**Row**: `blocker-taxonomy-foundation`
**Deliverable**: `hook-migration-and-quality-audit`
**Date**: 2026-04-25
**Scope**: Audit all hooks in `bin/frw.d/hooks/` to identify which emit blockers, classify migration complexity, propose canonical taxonomy codes, and identify shared helpers needed in `bin/frw.d/lib/`.

---

## 1. Inventory and emit-bearing classification

The ideation step flagged 11 emit-bearing candidates and 3 non-emit + 2 already-canonical hooks. After reading every script, **the candidate list is confirmed with two adjustments**:

| Hook | Ideation classification | Audit verdict | Reason |
|---|---|---|---|
| `correction-limit.sh` | emit-bearing | confirmed | exits 2 + stderr text |
| `gate-check.sh` | emit-bearing | **NOT emit-bearing** (no-op stub) | body is `return 0`; explicit comment notes validation now runs inside `rws_transition`. Drop from migration target — but recommend deletion or repurposing per Section 8. |
| `pre-commit-bakfiles.sh` | emit-bearing | confirmed | exits 1 + `log_warning` |
| `pre-commit-script-modes.sh` | emit-bearing | confirmed | exits 1 + `log_warning` |
| `pre-commit-typechange.sh` | emit-bearing | confirmed | exits 1 + `log_warning` |
| `script-guard.sh` | emit-bearing | confirmed | exit 2 + `log_error` |
| `state-guard.sh` | emit-bearing | confirmed | exit 2 + `log_error` |
| `stop-ideation.sh` | emit-bearing | confirmed | exit 2 + multi-line stderr |
| `validate-summary.sh` | emit-bearing | confirmed | exit 2 + multi-line stderr |
| `verdict-guard.sh` | emit-bearing | confirmed | exit 2 + `log_error` |
| `work-check.sh` | emit-bearing | **soft-emit only** (`log_warning`, always returns 0) | Non-blocking warnings. Still produces user-visible blocker-shaped messages and should route through canonical envelope at `severity: warn`. Keep in scope. |
| `append-learning.sh` | not emit-bearing | **IS emit-bearing** when invoked as PreToolUse hook | exit 3 on schema validation failure. Out-of-row scope per ideation instruction (already validated by reintegration-schema-consolidation). Recommend deferral — see Section 8. |
| `auto-install.sh` | not emit-bearing | confirmed | echoes status, never exits non-zero |
| `post-compact.sh` | not emit-bearing | confirmed (mostly) | exits 1 only on state corruption with `log_error`; this is a single edge case that *could* be a canonical `state_corruption` blocker but is far outside row scope. Defer. |
| `validate-definition.sh` | already canonical | confirmed | uses canonical `definition_*` codes (out of scope) |
| `ownership-warn.sh` | already canonical | confirmed | delegates to `furrow validate ownership` Go binary |

**Final migration target set: 10 emit-bearing hooks** (one fewer than the 11 flagged in ideation, because `gate-check.sh` is a no-op stub).

---

## 2. Per-hook audit

### 2.1 `correction-limit.sh` — 57 exec lines

- **Trigger**: `PreToolUse(Write|Edit)` — fires on every write attempt.
- **Current emission**: exit 2 + stderr line `"Correction limit (${limit}) reached for deliverable '${deliverable}'. Escalate to human for guidance."` when an active row's deliverable has corrections >= limit AND the target file matches one of its `file_ownership` globs (read from `plan.json`).
- **Suggested canonical code**: new — `correction_limit_reached` (category: `state-mutation`, severity: `block`).
  - Message template: `"Correction limit ({limit}) reached for deliverable '{deliverable}'. Escalate to human for guidance."`
  - Placeholders: `{limit}`, `{deliverable}`, `{path}`.
  - Maps loosely to baseline "incomplete pending user actions" and "supervised boundary without explicit human approval" but neither fits cleanly — propose new code.
- **Trigger condition**: `step == implement` AND `state.deliverables[d].corrections >= limit` AND `path` matches glob in `plan.json -> waves[].assignments[d].file_ownership`.
- **Complexity**: **non-trivial**. The hook reads four files (state.json, plan.json, furrow.yaml, definition.yaml indirectly), iterates deliverables, and performs glob matching. The Go side already has the input data shape for path → row → deliverable resolution; the migration is feasible but requires the Go entry point to accept `event_type=pre_write` with `target_path` and look up plan.json + state.json itself. ~2-3 hours.
- **Shared patterns**: stdin tool-input parsing (jq `.tool_input.file_path`), row resolution via `extract_row_from_path` + `find_focused_row`, archived-row short-circuit. All shared with `state-guard.sh`, `verdict-guard.sh`, `ownership-warn.sh`, `append-learning.sh`.
- **Quality findings**:
  - Lines 84-86: The `case` statement uses `${glob}` unquoted with shellcheck disable SC2254 — correct per shell glob semantics, but fragile if `plan.json` ever contains globs with `[` or `?` characters. Document or move into Go.
  - Lines 49-58: Two-step furrow.yaml lookup (project + .claude/) is duplicated in `auto-install.sh` — candidate for `find_furrow_yaml()` helper, or eliminate by putting config resolution in Go.
  - The hook silently no-ops in many cases (no plan.json, no row, not implement step). Migration to Go preserves this behavior but should explicitly log via `slog.Debug` for observability.

### 2.2 `gate-check.sh` — 4 exec lines

- **Trigger**: `PreToolUse(Bash)`.
- **Current emission**: **NONE**. Body is `return 0`. The comment block (lines 13-19) explicitly says validation now happens inside `rws_transition`.
- **Verdict**: dead code. Recommend **delete in migration step** or convert to a no-op that immediately exits. Since the file is already 4 executable lines and emits nothing, no migration work — but flag for cleanup as a quality finding. Not counted in mechanical/non-trivial totals.

### 2.3 `pre-commit-bakfiles.sh` — 19 exec lines

- **Trigger**: git pre-commit dispatcher, not Claude PreToolUse. Stdin is unused; iterates `git diff --cached --name-only`.
- **Current emission**: exit 1 + `log_warning "pre-commit: refusing to stage install-artifact ${_path}; move to \$XDG_STATE_HOME/furrow/"` for any staged file matching `bin/*.bak` or `.claude/rules/*.bak`.
- **Suggested canonical code**: new — `precommit_install_artifact_staged` (category: `scaffold`, severity: `block`).
  - Message template: `"refusing to stage install-artifact {path}; move to $XDG_STATE_HOME/furrow/"`.
- **Trigger condition**: any staged path matches `bin/*.bak` or `.claude/rules/*.bak`.
- **Complexity**: **mechanical**. Single stdin-less check; trivially translates to `furrow guard pre_commit_paths --json` taking the staged file list and emitting one envelope per offender.
- **Shared patterns**: pre-commit context lacks `FURROW_ROOT` so it derives from `git rev-parse --show-toplevel` — duplicated in `pre-commit-script-modes.sh` and `pre-commit-typechange.sh`. Candidate helper: `precommit_init_furrow_root()`.
- **Quality findings**:
  - The fallback `log_warning` shim (lines 19-21) is duplicated verbatim in the other two pre-commit hooks. Eliminate via shared loader.
  - Heredoc trick on lines 32-34 to feed `git diff` output is needed because the loop modifies `_failed`. Cleaner: read into a temp file or use a process substitution-free pipeline. Minor.

### 2.4 `pre-commit-script-modes.sh` — 25 exec lines

- **Trigger**: git pre-commit dispatcher.
- **Current emission**: exit 1 + `log_warning "pre-commit-script-modes: $_path must be 100755"` for any staged `bin/frw.d/scripts/*.sh` at index mode 100644.
- **Suggested canonical code**: new — `precommit_script_mode_invalid` (category: `scaffold`, severity: `block`).
  - Message template: `"{path} must be 100755 (got {mode})"`.
- **Trigger condition**: staged file under `bin/frw.d/scripts/*.sh` has `git ls-files -s` mode `100644`.
- **Complexity**: **mechanical**. Single condition, single emit shape.
- **Shared patterns**: same `_git_root` boilerplate + fallback `log_warning` as 2.3 and 2.5. Same heredoc loop pattern.
- **Quality findings**:
  - `awk '{print $1}' | head -n1` (line 47) — `head -n1` is unnecessary because `git ls-files -s -- <path>` returns at most one line for a single non-conflicted path. Tightening opportunity.
  - Comment on line 41 (`bin/frw.d/scripts/*.sh) ;;`) uses `;;` to fall through to next loop iteration — relies on `case` semantics. Works but slightly opaque; a positive-match `*) continue` is the explicit form already on the next line.

### 2.5 `pre-commit-typechange.sh` — 30 exec lines

- **Trigger**: git pre-commit dispatcher.
- **Current emission**: exit 1 + `log_warning "pre-commit: refusing type-change -> symlink on ${_path} (see docs/architecture/self-hosting.md)"` for typechange (status `T`) to symlink (mode `120000`) on protected paths (`bin/alm`, `bin/rws`, `bin/sds`, `.claude/rules/*`).
- **Suggested canonical code**: new — `precommit_typechange_to_symlink` (category: `scaffold`, severity: `block`).
  - Message template: `"refusing type-change to symlink on {path} (see docs/architecture/self-hosting.md)"`.
- **Trigger condition**: `git diff --cached --raw` row has `status=T` AND `new_mode=120000` AND path matches protected glob.
- **Complexity**: **mechanical**. Trivial check; the only nuance is parsing `git diff --raw` output.
- **Shared patterns**: same `_git_root` + `log_warning` fallback as 2.3, 2.4.
- **Quality findings**:
  - Lines 41-43 use three separate `awk` invocations on the same line — combine into one awk. Tightening opportunity.
  - `_is_protected` function lives inline; could move to `bin/frw.d/lib/precommit-paths.sh`.

### 2.6 `script-guard.sh` — 141 exec lines

- **Trigger**: `PreToolUse(Bash)`.
- **Current emission**: exit 2 + `log_error "bin/frw.d/ scripts are internal — use frw, rws, alm, or sds"` when the bash command tokenizes to a direct execution of a `bin/frw.d/` path.
- **Suggested canonical code**: new — `script_guard_internal_invocation` (category: `scaffold`, severity: `block`).
  - Message template: `"bin/frw.d/ scripts are internal — use frw, rws, alm, or sds"` (no placeholders required, but optional `{command}` for context).
- **Trigger condition**: shell-stripped command-string tokenization detects a `bin/frw.d/` token at command-execution position (direct call, or after `sh|bash|zsh|dash|ksh|source|.|exec` modulo `-n` syntax-check).
- **Complexity**: **non-trivial — heavy**. The bulk of the file (~100 lines) is the `shell_strip_data_regions` awk parser that strips quoted strings, heredocs, and comments before tokenizing. This logic *should* live in Go (cleaner with a real lexer or even just a regexp-driven scanner) but porting it is its own project. The shim itself once the parser is moved is mechanical.
- **Shared patterns**: stdin parsing of `.tool_input.command` is unique to bash-tool guards — only `script-guard.sh` uses it. The shell-strip logic is single-use; not a candidate helper unless we anticipate a second bash-tool guard.
- **Quality findings**:
  - `script-guard.sh` is by far the largest hook (141 lines, 5x the 30-line target). The awk parser is correct but POSIX-awk is the wrong tool for shell-tokenization — Go's `mvdan.cc/sh` (already in module set? — verify) or even a hand-rolled scanner would be far more maintainable.
  - The block at lines 162-200 (in-shell awk that returns exit code) is a creative but error-prone idiom. In Go this collapses to ~20 lines of testable code with table-driven cases.
  - **Migration recommendation**: this hook is the strongest candidate for *full* port to Go, not just shim-ification. The shell shim becomes 10 lines.

### 2.7 `state-guard.sh` — 12 exec lines

- **Trigger**: `PreToolUse(Write|Edit)`.
- **Current emission**: exit 2 + `log_error "state.json is Furrow-exclusive — use frw update-state"` when target path matches `*/state.json` or `state.json`.
- **Suggested canonical code**: new — `state_json_direct_write` (category: `state-mutation`, severity: `block`).
  - Maps directly to baseline item "direct mutation of canonical workflow state outside CLI/backend" (line 273 of pi-step-ceremony doc).
  - Message template: `"state.json is Furrow-exclusive — use frw update-state"` (optional `{path}` placeholder).
- **Trigger condition**: `tool_input.file_path` ends in `state.json`.
- **Complexity**: **mechanical**. Pure path match; ideal first migration.
- **Shared patterns**: stdin parse + path-pattern match — the same pattern used by `verdict-guard.sh`, `correction-limit.sh`, `append-learning.sh`, `ownership-warn.sh`, `validate-definition.sh`. Strong helper candidate: `parse_tool_input_path()`.
- **Quality findings**: clean. Two suggestions:
  - Pattern `state.json` (no leading `*/`) on line 16 matches `state.json` at the cwd; Claude almost never sends a bare relative path that way, but harmless.
  - `echo "$input"` (line 13) should be `printf '%s' "$input"` for consistency with other hooks (e.g., `correction-limit.sh:18`).

### 2.8 `stop-ideation.sh` — 45 exec lines

- **Trigger**: `Stop` (no matcher).
- **Current emission**: exit 2 + multi-line stderr starting with `"Ideation incomplete — definition.yaml missing required fields:\n"` followed by a bullet list of missing fields. Skips when not in `ideate` step or when `gate_policy=autonomous`.
- **Suggested canonical code**: new — `ideation_incomplete_definition_fields` (category: `ideation`, severity: `block`).
  - Maps to baseline "ideation completeness failure" (line 279 of pi-step-ceremony doc).
  - Message template: `"Ideation incomplete — definition.yaml missing required fields: {missing}"` where `{missing}` is a comma-or-newline-joined list.
- **Trigger condition**: `step == ideate` AND `gate_policy != autonomous` AND definition.yaml exists AND any of `{objective, gate_policy, deliverables(>=1), context_pointers(>=1), constraints}` is missing.
- **Complexity**: **non-trivial**. The hook reads multiple files, calls `resolve_config_value` (three-tier config chain in `common.sh`), and validates 5 distinct fields. The logic mostly duplicates `validate-definition.sh` but with different field-completeness semantics and different return codes (3 vs 2). The Go entry point already has all this data — `furrow validate definition` exists. The migration is "make the Stop hook call `furrow guard stop_ideation` which internally invokes the existing definition validator". ~1.5 hours.
- **Shared patterns**: definition-field reading via `yq` is duplicated with `validate-definition.sh` (already canonical). `resolve_config_value` is already in `common.sh`. The Go validator can subsume both.
- **Quality findings**:
  - Lines 86-88: `constraints` is checked for either empty or `"null"` — but `yq -r '.constraints // ""'` already converts null to empty. The `"null"` check is dead. Tightening.
  - Line 47: `gate_policy="$(resolve_config_value gate_policy)" || gate_policy="supervised"` — `set -eu` + the `||` makes this fail-open to "supervised". Good.
  - The hook sources `common.sh` (line 23) which is heavyweight (jq+yq+awk helpers) for what is conceptually a "Stop boundary needs blocker check". Migration to Go drops the dependency.

### 2.9 `validate-summary.sh` — 42 exec lines

- **Trigger**: `Stop` (no matcher).
- **Current emission**: exit 2 + multi-line stderr starting with `"summary.md validation failed:\n"` followed by bullets like `"Missing section: Task\n"` or `"Section 'Open Questions' needs at least 1 non-empty line (has 0).\n"`. Skips when no summary.md, when last gate was `prechecked`, or when no active row.
- **Suggested canonical code**: split into two new codes:
  - `summary_section_missing` (category: `summary`, severity: `block`) — placeholders: `{section}`, `{path}`.
  - `summary_section_empty` (category: `summary`, severity: `block`) — placeholders: `{section}`, `{actual_count}`, `{required_count}`, `{path}`.
  - Both map to baseline "summary validation failure" (line 278).
  - Alternatively a single `summary_validation_failure` code with a structured `{detail}` field — but per existing convention (`definition_*` is split into many codes), prefer the split.
- **Trigger condition**: `summary.md` exists AND last gate `decided_by != prechecked` AND any of {`Task`, `Current State`, `Artifact Paths`, `Settled Decisions`, `Key Findings`, `Open Questions`, `Recommendations`} is missing OR (for `Key Findings`/`Open Questions`/`Recommendations`) section has zero non-empty content lines (with step-aware exemption: `ideate` only requires `Open Questions`).
- **Complexity**: **non-trivial**. The hook does awk-based markdown section parsing with step-aware filtering. Migration to Go gives us a real markdown parser and table-driven required-sections list. ~1.5-2 hours.
- **Shared patterns**: `awk`-based section extraction is duplicated in `work-check.sh` and `common.sh` (`extract_md_section`). The Go side should expose a single `summary.RequiredSections(step)` function and a `summary.SectionContentLines(file, name)` helper.
- **Quality findings**:
  - Line 56-58: step-aware filtering is correct but encoded inline rather than as a data table — Go migration is the right place to make this declarative.
  - Lines 60-65: nested awk for section content counting is correct but slow (forks once per section). Go reads the file once.
  - The validator runs on every Stop, including stops within a step, which means partial summaries trigger blocks mid-step. Behavior may be intentional (forces immediate fixup) but worth confirming during migration. **Migration must preserve current behavior unless explicitly approved otherwise.**

### 2.10 `verdict-guard.sh` — 12 exec lines

- **Trigger**: `PreToolUse(Write|Edit)`.
- **Current emission**: exit 2 + `log_error "gate-verdicts/ is write-protected — verdicts written by evaluator subagent only"` when target path matches `*/gate-verdicts/*` or `gate-verdicts/*`.
- **Suggested canonical code**: new — `verdict_direct_write` (category: `gate`, severity: `block`).
  - Maps loosely to baseline "missing verdict/prompt linkage where evaluated gates are used" but the trigger is direct-write-prevention, not linkage-failure. New code is appropriate.
  - Message template: `"gate-verdicts/ is write-protected — verdicts written by evaluator subagent only"` (optional `{path}` placeholder).
- **Trigger condition**: `tool_input.file_path` contains `gate-verdicts/`.
- **Complexity**: **mechanical**. Identical shape to `state-guard.sh`.
- **Shared patterns**: same as state-guard — `parse_tool_input_path` + path glob match + canonical envelope emit.
- **Quality findings**: clean. Same `echo` vs `printf` nit as state-guard:7.

### 2.11 `work-check.sh` — 50 exec lines

- **Trigger**: `Stop` (no matcher).
- **Current emission**: **always returns 0**, but emits multiple `log_warning` lines:
  - `"state.json validation failed for $unit_name"` (when `validate_state_json` fails).
  - `"summary.md missing required sections for ${unit_name}: ${_missing}"` (when sections absent).
  - `"summary.md section '${_agent_section}' has fewer than 2 lines of content for ${unit_name}"` (when content sparse).
- **Suggested canonical codes**:
  - `state_validation_failed_warn` (category: `state-mutation`, severity: `warn`, confirmation_path: `silent`) — for state.json failures detected at session boundaries.
  - Reuse `summary_section_missing` and `summary_section_empty` from §2.9 with severity overridden to `warn` — but the canonical taxonomy gives one severity per code. So either:
    - **Option A**: introduce parallel `_warn`-suffixed codes for the same conditions when found at Stop boundary (`summary_section_missing_warn`, `summary_section_empty_warn`).
    - **Option B**: Make `work-check.sh`'s Stop-time check share the *same* codes as `validate-summary.sh` and let severity be a property of the call site, not the code. This violates the current registry shape (severity is per-code).
    - **Recommend Option A** — keeps the registry's invariant clean, makes parity tests trivial.
- **Trigger condition**: every active row at Stop time, with each section/state-validation check performed independently.
- **Complexity**: **non-trivial**. Loops every active row, sources `validate.sh` and `update-state.sh`, calls `frw_update_state` (a state-mutating side effect on `updated_at`!). The state-mutation responsibility is unrelated to blocker emission and should split out before/during migration.
- **Shared patterns**: section-presence check duplicated with `validate-summary.sh` and `common.sh::extract_md_section`. State-validation duplicated with `post-compact.sh:26`. Both go to Go.
- **Quality findings**:
  - **Single biggest finding**: this hook does *both* warning emission AND a side-effect timestamp update (line 71). The timestamp update is an unrelated concern that has nothing to do with blocker emission and should be moved to its own hook or to a `furrow checkpoint` invocation. Flag for follow-up TODO.
  - Line 60: extracts content via awk into a string then counts lines — combine into a single awk that returns the count directly (matches the cleaner pattern in `validate-summary.sh:60-65`).
  - Line 61: `grep -c '.'` counts non-empty lines via dot-match; but `grep` counts lines that *contain* any char, equivalent to `grep -cv '^$'`. Same result; consider switching for clarity.

---

## 3. Summary table

| Hook | Lines (exec) | Suggested code(s) | Category | Severity | Complexity |
|---|--:|---|---|---|---|
| `correction-limit.sh` | 57 | `correction_limit_reached` | state-mutation | block | non-trivial |
| `gate-check.sh` | 4 | (none — dead code) | — | — | delete |
| `pre-commit-bakfiles.sh` | 19 | `precommit_install_artifact_staged` | scaffold | block | mechanical |
| `pre-commit-script-modes.sh` | 25 | `precommit_script_mode_invalid` | scaffold | block | mechanical |
| `pre-commit-typechange.sh` | 30 | `precommit_typechange_to_symlink` | scaffold | block | mechanical |
| `script-guard.sh` | 141 | `script_guard_internal_invocation` | scaffold | block | non-trivial (heavy parser) |
| `state-guard.sh` | 12 | `state_json_direct_write` | state-mutation | block | mechanical |
| `stop-ideation.sh` | 45 | `ideation_incomplete_definition_fields` | ideation | block | non-trivial |
| `validate-summary.sh` | 42 | `summary_section_missing`, `summary_section_empty` | summary | block | non-trivial |
| `verdict-guard.sh` | 12 | `verdict_direct_write` | gate | block | mechanical |
| `work-check.sh` | 50 | `state_validation_failed_warn`, `summary_section_missing_warn`, `summary_section_empty_warn` | state-mutation, summary | warn | non-trivial |

**Mechanical**: 5 (pre-commit-bakfiles, pre-commit-script-modes, pre-commit-typechange, state-guard, verdict-guard).
**Non-trivial**: 5 (correction-limit, script-guard, stop-ideation, validate-summary, work-check).
**Dead**: 1 (gate-check).

---

## 4. Proposed shared helpers in `bin/frw.d/lib/`

The migrated hooks all collapse to the same three-step shape (parse stdin → invoke Go → translate envelope to exit code). The following helpers should live in `bin/frw.d/lib/` so each hook shim stays at ≤30 lines.

| Helper | Purpose | Used by |
|---|---|---|
| `emit_canonical_blocker(event_type)` | Reads stdin tool-input JSON, normalizes into `BlockerEvent` shape, invokes `furrow guard <event_type> --json`, prints any envelope to stderr, returns Claude exit code (0/2). The single canonical translator. | All 10 migrated hooks |
| `parse_tool_input_path()` | Extracts `tool_input.file_path` (with `filePath`/`path` aliases) from stdin JSON. POSIX-safe wrapper around the four `jq -r '.tool_input.file_path // .tool_input.path // ""'` invocations duplicated across hooks. | state-guard, verdict-guard, correction-limit, append-learning, ownership-warn, validate-definition |
| `parse_tool_input_command()` | Extracts `tool_input.command` for Bash-tool guards. | script-guard |
| `precommit_init()` | Resolves `_git_root` via `git rev-parse --show-toplevel`, sources `common-minimal.sh` (or stubs `log_warning` fallback). Eliminates the 8-line boilerplate at the top of all three pre-commit hooks. | pre-commit-bakfiles, pre-commit-script-modes, pre-commit-typechange |
| `find_furrow_yaml()` | Locates the first existing `.furrow/furrow.yaml` / `.claude/furrow.yaml` / `furrow.yaml`. Currently inlined in correction-limit.sh and auto-install.sh. (Optional — may be obviated by moving config resolution into Go.) | correction-limit, auto-install |

The Go binary's `furrow guard <event-type>` entry point (per deliverable D2 acceptance criteria) is the single emission target; the shell helpers above purely *translate* host events into the normalized `BlockerEvent` payload.

---

## 5. Cross-reference: blocker baseline coverage

The pi-step-ceremony "Blocker baseline" list (lines 271-286) enumerates 13 hard-blocker categories. Mapping current emit-sites:

| Baseline item | Covered by hook (post-migration) | Gap |
|---|---|---|
| direct mutation of canonical workflow state outside CLI/backend | `state-guard.sh` → `state_json_direct_write` | covered |
| invalid step order | `rws transition` (Go-side, not a hook) | covered (out-of-row scope, already in Go) |
| unsupported advancement past final review | `rws transition` (Go) | covered (Go-side) |
| incomplete pending user actions | `rws transition` (Go) | covered (Go-side) |
| required artifact validation failure | none | **GAP** — no hook emits this; Go-side enforcement only. Document as covered by validators in cmd/furrow, no new emit-site needed. |
| summary validation failure | `validate-summary.sh` → `summary_section_missing/empty` | covered |
| ideation completeness failure | `stop-ideation.sh` → `ideation_incomplete_definition_fields` | covered |
| invalid `decided_by` for gate policy | `rws transition` (Go) | covered (Go-side) |
| missing verdict/prompt linkage where evaluated gates are used | `rws transition` (Go); `verdict-guard.sh` blocks direct verdict writes (different concern) | **GAP** — no emit-site for *missing* linkage. Go validator should emit `verdict_linkage_missing`. Out of row scope but flag as new code in registry. |
| nonce mismatch / stale evaluator result | `rws transition` (Go) | covered (Go-side) |
| missing/closed/invalid seed state where required | none | **GAP** — seed-state codes (e.g., `seed_missing`, `seed_closed`, `seed_invalid`) need to land in registry per deliverable D1 acceptance criterion ("≥15 codes spanning ... seed-state categories"). No hook emits these; Go-side `sds` validator path. |
| archive before review passes | `rws transition` (Go) | covered (Go-side) |
| unsupported mutation of archived rows | `rws transition` (Go); also `correction-limit.sh` short-circuits on archived rows | covered (Go-side) |
| supervised boundary without explicit human approval | `rws transition` (Go) | covered (Go-side) |

**Codes the registry needs (D1 work) that have no current hook emit-site**:
- `verdict_linkage_missing` (gate)
- `seed_missing`, `seed_closed`, `seed_invalid` (seed-state) — at least three codes
- `archive_before_review_pass` (archive) — currently enforced in Go, registry entry needed
- `archived_row_mutation` (archive) — same
- `supervised_boundary_unconfirmed` (gate) — same
- `pending_user_action_unresolved` (state-mutation) — same
- `step_order_invalid` (state-mutation) — same
- `decided_by_invalid_for_policy` (gate) — same
- `nonce_stale` (gate) — same
- `artifact_validation_failed` (artifact) — same

These are taxonomy-only additions (no new shell emitters needed); the existing Go enforcement paths inside `rws_transition` and `sds` adopt the canonical envelope. Total: ~10 codes added to registry from baseline, plus the 8-9 hook-migration codes from §2 = ~18-19 new codes, comfortably exceeding the ≥15 D1 target.

---

## 6. Mechanical-vs-non-trivial recommendation

5 mechanical + 5 non-trivial = 10 hooks. Per the row's no-hybrid-state constraint, **all 10 should migrate in the implement step**, with one explicit deferral candidate:

- **`script-guard.sh`** is the single hook where the heavy work is the `shell_strip_data_regions` POSIX-awk parser (~100 LOC). The shim itself, once the parser is in Go, is mechanical. Recommend treating the parser port as a sub-task within the migration (4-6 hours). If implementer-step time pressure forces a deferral, this is the one to defer — but the rest of the row's parity-test infrastructure makes deferral expensive (would need a special-case fixture for an unmigrated emit-site). Default position: **migrate all 10**.

If deferral is forced (e.g., implementer hits time wall on script-guard), the follow-up TODO entry is:

```yaml
- id: script-guard-go-parser-port
  title: "Port script-guard.sh shell_strip_data_regions awk parser to Go"
  category: harness-quality
  rationale: |
    The 100-line POSIX-awk parser correctly strips quoted strings/heredocs/comments
    before tokenizing, but is the wrong tool — Go's mvdan.cc/sh or a hand-rolled
    scanner is more maintainable and testable. Deferred from blocker-taxonomy-foundation
    row because the parser port is its own ~4-6h work item.
  acceptance:
    - shell_strip_data_regions logic ported to internal/cli/shellparse/
    - bin/frw.d/hooks/script-guard.sh shim is ≤30 lines
    - parity test fixture exercises sh -n syntax-check exception
```

A second deferral candidate is `work-check.sh`'s `frw_update_state` side-effect on `updated_at` — that should be pulled out of the blocker hook entirely and become its own checkpoint hook or `furrow checkpoint` call. Follow-up TODO:

```yaml
- id: work-check-side-effect-split
  title: "Split work-check.sh updated_at timestamp update from blocker emission"
  category: harness-quality
  rationale: |
    work-check.sh currently does both (a) Stop-time blocker warnings and
    (b) updated_at timestamp mutation via frw_update_state. The blocker
    hook should not have unrelated state mutations. Split into two hooks
    or move timestamp update into rws_transition.
```

---

## 7. Migration order recommendation

For the implement step, recommended sequence (each phase ends in a green parity test run):

1. **Phase A — registry + shim plumbing** (no behavior change):
   - Add the ~18-19 new codes to `schemas/blocker-taxonomy.yaml` (D1 deliverable scope).
   - Add `emit_canonical_blocker` and `parse_tool_input_path` helpers to `bin/frw.d/lib/`.
   - Land normalized event schema (D2 deliverable scope).

2. **Phase B — mechanical migrations** (~30 min each):
   - `state-guard.sh` (smallest; build confidence)
   - `verdict-guard.sh`
   - `pre-commit-bakfiles.sh`
   - `pre-commit-typechange.sh`
   - `pre-commit-script-modes.sh`

3. **Phase C — non-trivial migrations** (~1.5-3h each):
   - `stop-ideation.sh` (subsumed by existing definition validator — easiest non-trivial)
   - `validate-summary.sh`
   - `correction-limit.sh`
   - `work-check.sh` (after splitting out timestamp side-effect)
   - `script-guard.sh` (last; depends on shellparse Go port)

4. **Phase D — cleanup**:
   - Delete `gate-check.sh` (dead code).
   - Verify all hooks are ≤30 exec lines.

---

## 8. Quality findings summary (all hooks)

Cross-cutting quality items collected from §2 audits, in priority order:

| Severity | Hook | Finding | Disposition |
|---|---|---|---|
| medium | `gate-check.sh` | Dead code — body is `return 0`, comment says it's a no-op | Delete in implement step |
| medium | `work-check.sh` | Mixes blocker emission with `updated_at` timestamp side-effect | Split out via follow-up TODO; remove from migrated hook |
| medium | `script-guard.sh` | 100-line POSIX-awk shell parser is wrong tool for the job | Port to Go (in scope or follow-up TODO) |
| low | `correction-limit.sh` | Glob matching uses unquoted `${glob}` with SC2254 disable — fragile if globs contain `[` or `?` | Move to Go where doublestar handles cleanly |
| low | `pre-commit-script-modes.sh` | Unnecessary `head -n1` after `awk '{print $1}'` (only one line possible) | Tighten in migration |
| low | `pre-commit-typechange.sh` | Three separate `awk` invocations on the same line — combine | Tighten in migration |
| low | `state-guard.sh`, `verdict-guard.sh` | `echo "$input"` should be `printf '%s' "$input"` for consistency | Trivial fix |
| low | `stop-ideation.sh` | Dead `"null"` check on `constraints` — `yq -r // ""` already converts | Drop in migration |
| low | `pre-commit-bakfiles.sh` `pre-commit-script-modes.sh` `pre-commit-typechange.sh` | Three identical fallback `log_warning` shims — dedupe via `precommit_init` helper | Helper extraction |
| low | `pre-commit-script-modes.sh` `pre-commit-bakfiles.sh` `pre-commit-typechange.sh` | Heredoc trick to feed `git diff` output to a loop without subshell scope loss is duplicated | Helper or document pattern |
| low | `validate-summary.sh` | Forks one awk per section — could run a single pass | Go migration handles cleanly |

No critical findings (no security holes, no broken error handling).

---

## Sources Consulted

**Primary sources** (hook source files — line counts via `grep -cvE '^\s*(#|$)'`):
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/correction-limit.sh` (57 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/gate-check.sh` (4 lines — dead body)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/pre-commit-bakfiles.sh` (19 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/pre-commit-script-modes.sh` (25 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/pre-commit-typechange.sh` (30 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/script-guard.sh` (141 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/state-guard.sh` (12 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/stop-ideation.sh` (45 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/validate-summary.sh` (42 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/verdict-guard.sh` (12 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/work-check.sh` (50 lines)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/append-learning.sh` (72 lines — out of scope)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/auto-install.sh` (20 lines — out of scope)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/post-compact.sh` (42 lines — out of scope)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/validate-definition.sh` (87 lines — already canonical)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/hooks/ownership-warn.sh` (36 lines — already canonical, calls `furrow validate ownership`)

**Library sources**:
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/lib/common-minimal.sh` — hook-safe helper subset (8 functions)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/lib/common.sh` — full helper set including `resolve_config_value`, `extract_md_section`

**Go canonical types**:
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/internal/cli/blocker_envelope.go` lines 35-42 (`BlockerEnvelope` struct), 136-159 (`EmitBlocker`)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/schemas/blocker-taxonomy.yaml` — current 11-code registry

**Architecture / contract docs**:
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` lines 267-300 ("Blocker baseline")
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/.furrow/rows/blocker-taxonomy-foundation/definition.yaml` — deliverable contracts and constraints
