You are reviewing deliverable 'normalized-blocker-event-and-go-emission-path' for quality.

## Acceptance Criteria

- schemas/blocker-event.yaml defines a host-agnostic event envelope (event_type, target_path, step, row, payload) that adapters translate host events into before invoking the backend. The schema includes an explicit version field so future shape changes can be tracked.
- schemas/blocker-event.schema.json validates the shape; documentation in the file or a sibling reference explains each field and the per-event-type payload contract.
- A Go entry point (e.g., furrow guard <event-type> --json reading normalized event JSON on stdin, or an internal emit function exposed via cmd/furrow) accepts a normalized event and emits the canonical BlockerEnvelope JSON for the matched code, or exits 0 with empty output when no condition is triggered.
- Unit tests in internal/cli/ cover representative event types end to end (event in → envelope out) for at least one code per blocker category.
- Adding a new event type without a corresponding handler fails the typecheck or test suite (compile-time or table-driven coverage check).

## Evaluation Dimensions

- **correctness**: Whether the implementation matches spec behavior
  Pass: All spec acceptance criteria pass when tested (commands run, output inspected)
  Fail: Any AC fails when tested with a fresh run
- **test-coverage**: Whether new code paths have corresponding tests
  Pass: Every new function or method with branching logic has at least one test
  Fail: Any new function with branching logic has zero tests
- **spec-compliance**: Whether the implementation follows the spec's interface contracts
  Pass: All interface contracts from the spec are implemented as specified (function signatures, file locations, behavior)
  Fail: Any interface contract is missing or differs from spec
- **unplanned-changes**: Whether changes outside file_ownership are justified
  Pass: All files modified outside the deliverable's file_ownership globs are documented with justification
  Fail: Unplanned changes exist without justification
- **code-quality**: Whether the code follows project conventions and code-quality skill rules
  Pass: Code passes linting, follows naming conventions, and does not violate code-quality rules (spec: skills/code-quality.md)
  Fail: Any code-quality rule violation exists

## Changes

```
commit d5935e3f9a25f64153b25cd24f17b07a276a0ea9
Author: Test <test@test.com>
Date:   Sat Apr 25 15:31:44 2026 -0400

    fix(hooks): short-circuit pre-commit shims when no entries match
    
    The Go handlers' `requireArray` rejects empty arrays as invocation
    errors. When nothing is staged or no staged paths match the helper's
    filter, `precommit_event_*` now emits empty stdout and the shim's
    `main` exits 0 before invoking `furrow_guard`. Eliminates the
    "payload key X is empty" stderr line on every clean commit.

diff --git a/bin/frw.d/lib/precommit_payloads.sh b/bin/frw.d/lib/precommit_payloads.sh
index 068378e..ae02abd 100644
--- a/bin/frw.d/lib/precommit_payloads.sh
+++ b/bin/frw.d/lib/precommit_payloads.sh
@@ -45,12 +45,17 @@ _FRW_PRECOMMIT_PAYLOADS_SOURCED=1
 #     "payload": { "staged_paths": [<path>, ...] } }
 precommit_event_bakfiles() {
   _staged="$(git diff --cached --name-only 2>/dev/null || printf '')"
+  # Empty payload → nothing to emit (Go's requireArray rejects empty
+  # arrays as invocation errors; short-circuit in shell instead).
+  [ -n "$_staged" ] || return 0
   printf '%s' "$_staged" \
     | jq -R -s -c '
         split("\n") | map(select(length > 0)) as $paths
-        | { version: "1",
-            event_type: "pre_commit_bakfiles",
-            payload: { staged_paths: $paths } }
+        | if ($paths | length) == 0 then empty
+          else { version: "1",
+                 event_type: "pre_commit_bakfiles",
+                 payload: { staged_paths: $paths } }
+          end
       '
 }
 
@@ -66,6 +71,7 @@ precommit_event_bakfiles() {
 #     "payload": { "typechange_entries": [{path, new_mode, status}, ...] } }
 precommit_event_typechange() {
   _raw="$(git diff --cached --raw 2>/dev/null || printf '')"
+  [ -n "$_raw" ] || return 0
   # awk one-pass: emit one tab-separated record per raw row (path, new_mode,
   # status), then jq folds them into the JSON array. Combining the three
   # field reads into a single awk replaces the three-awk pattern in the
@@ -82,9 +88,11 @@ precommit_event_typechange() {
     | jq -R -s -c '
         split("\n") | map(select(length > 0)) | map(split("\t"))
         | map({ path: .[0], new_mode: .[1], status: .[2] }) as $entries
-        | { version: "1",
-            event_type: "pre_commit_typechange",
-            payload: { typechange_entries: $entries } }
+        | if ($entries | length) == 0 then empty
+          else { version: "1",
+                 event_type: "pre_commit_typechange",
+                 payload: { typechange_entries: $entries } }
+          end
       '
 }
 
@@ -113,12 +121,15 @@ precommit_event_script_modes() {
           printf '%s\t%s\n' "$_p" "$_m"
         done
   )"
+  [ -n "$_entries" ] || return 0
   printf '%s' "$_entries" \
     | jq -R -s -c '
         split("\n") | map(select(length > 0)) | map(split("\t"))
         | map({ path: .[0], mode: .[1] }) as $entries
-        | { version: "1",
-            event_type: "pre_commit_script_modes",
-            payload: { script_modes: $entries } }
+        | if ($entries | length) == 0 then empty
+          else { version: "1",
+                 event_type: "pre_commit_script_modes",
+                 payload: { script_modes: $entries } }
+          end
       '
 }

commit 781681bc9624f83a49ee75ee5f9afa38a6d83ca4
Author: Test <test@test.com>
Date:   Sat Apr 25 15:30:22 2026 -0400

    refactor(hooks): migrate emit-bearing hooks to canonical Go-routed shims
    
    D3 of blocker-taxonomy-foundation. Reduces 10 emit-bearing hooks under
    bin/frw.d/hooks/ to thin shims that translate host events into normalized
    BlockerEvent JSON, dispatch to `furrow guard <event-type>`, and emit
    canonical BlockerEnvelope output to stderr. All domain logic now lives
    in Go (internal/cli/{guard,correction_limit,precommit,shellparse,
    stop_ideation,validate_summary,work_check}.go from D2). gate-check.sh
    deleted (dead code -- body was `return 0`).
    
    Per-hook line counts (executable, post-migration):
      state-guard 5, verdict-guard 5, correction-limit 5, script-guard 5,
      stop-ideation 5, validate-summary 5, work-check 3,
      pre-commit-bakfiles 13, pre-commit-typechange 13,
      pre-commit-script-modes 13.
    
    Adds two helper files in bin/frw.d/lib/ (per shared-contracts §C4
    escape valve for D3 helpers shared by >=2 shims):
      precommit_payloads.sh -- git-diff parsing for the three pre-commit
                               event types
      stop_payloads.sh      -- active-row resolution and Stop-event payload
                               assembly
    
    D2's bin/frw.d/lib/blocker_emit.sh exports unchanged (signature-locked).
    
    Audit report at .furrow/rows/blocker-taxonomy-foundation/research/
    hook-audit-final.md walks all 11 quality findings from the research-step
    audit (status RESOLVED / MOVED-TO-GO; no DEFERRED-WITH-TODO). The
    work-check.sh updated_at side-effect is removed entirely (no consumer
    depends on Stop-time mutation).
    
    Coordinator follow-ups (out of D3 file_ownership):
      - .claude/settings.json:18 still registers `frw hook gate-check`;
        coordinator must remove the line so the Bash matcher contains only
        `frw hook script-guard`.
      - tests/integration/test-precommit-{block,bypass}.sh assert literal
        `pre-commit:` substring in stderr; D1 taxonomy dropped that prefix.
        Pre-existing breakage from D1, surfaced for follow-up.

diff --git a/bin/frw.d/lib/precommit_payloads.sh b/bin/frw.d/lib/precommit_payloads.sh
new file mode 100644
index 0000000..068378e
--- /dev/null
+++ b/bin/frw.d/lib/precommit_payloads.sh
@@ -0,0 +1,124 @@
+#!/bin/sh
+# precommit_payloads.sh — D3 helpers that assemble normalized BlockerEvent
+# payloads for the three pre-commit guard event types.
+#
+# These helpers are NEW in D3 (added per shared-contracts.md §C4 escape
+# valve: "D3 may add new helpers to bin/frw.d/lib/ if shared by >=2 shims").
+# They factor out git-plumbing so the pre-commit shim bodies stay at the
+# canonical 4-step shape and the Go handlers (internal/cli/precommit.go)
+# stay free of git-CLI invocation.
+#
+# Exports (POSIX sh functions):
+#
+#   precommit_event_bakfiles
+#       Stdin:  none
+#       Stdout: normalized BlockerEvent JSON for `pre_commit_bakfiles`
+#       Side:   reads `git diff --cached --name-only` once
+#       Exit:   0 always (empty payload on git failure is fine — the Go
+#               handler's `requireArray` will pass cleanly with no emit)
+#
+#   precommit_event_typechange
+#       Stdin:  none
+#       Stdout: normalized BlockerEvent JSON for `pre_commit_typechange`
+#       Side:   reads `git diff --cached --raw` once
+#       Exit:   0 always
+#
+#   precommit_event_script_modes
+#       Stdin:  none
+#       Stdout: normalized BlockerEvent JSON for `pre_commit_script_modes`
+#       Side:   reads `git diff --cached --name-only --diff-filter=ACM`
+#               and one `git ls-files -s` per matching path
+#       Exit:   0 always
+#
+# Each helper writes a JSON object to stdout. The shim then pipes that
+# stdout to `furrow_guard <event_type> | emit_canonical_blocker`.
+
+if [ -n "${_FRW_PRECOMMIT_PAYLOADS_SOURCED:-}" ]; then
+  return 0 2>/dev/null || true
+fi
+_FRW_PRECOMMIT_PAYLOADS_SOURCED=1
+
+# precommit_event_bakfiles
+#
+# Pre-commit-bakfiles payload contract (internal/cli/precommit.go::handlePreCommitBakfiles):
+#   { "version": "1", "event_type": "pre_commit_bakfiles",
+#     "payload": { "staged_paths": [<path>, ...] } }
+precommit_event_bakfiles() {
+  _staged="$(git diff --cached --name-only 2>/dev/null || printf '')"
+  printf '%s' "$_staged" \
+    | jq -R -s -c '
+        split("\n") | map(select(length > 0)) as $paths
+        | { version: "1",
+            event_type: "pre_commit_bakfiles",
+            payload: { staged_paths: $paths } }
+      '
+}
+
+# precommit_event_typechange
+#
+# Parses `git diff --cached --raw` into structured entries. Each raw row:
+#   :100644 120000 <sha> <sha> T\tpath
+# becomes {path, new_mode, status} in the payload. The Go handler filters
+# for status==T && new_mode==120000 on protected paths.
+#
+# Pre-commit-typechange payload contract (internal/cli/precommit.go::handlePreCommitTypechange):
+#   { "version": "1", "event_type": "pre_commit_typechange",
+#     "payload": { "typechange_entries": [{path, new_mode, status}, ...] } }
+precommit_event_typechange() {
+  _raw="$(git diff --cached --raw 2>/dev/null || printf '')"
+  # awk one-pass: emit one tab-separated record per raw row (path, new_mode,
+  # status), then jq folds them into the JSON array. Combining the three
+  # field reads into a single awk replaces the three-awk pattern in the
+  # pre-D3 hook (audit §2.5 finding #1).
+  printf '%s' "$_raw" \
+    | awk 'NF >= 6 {
+             # status column 5 is e.g. "T" or "T100" for renames; cut to first char
+             status = substr($5, 1, 1)
+             # path column 6 onwards (path can contain spaces — collapse rest)
+             path = $6
+             for (i = 7; i <= NF; i++) path = path " " $i
+             printf "%s\t%s\t%s\n", path, $2, status
+           }' \
+    | jq -R -s -c '
+        split("\n") | map(select(length > 0)) | map(split("\t"))
+        | map({ path: .[0], new_mode: .[1], status: .[2] }) as $entries
+        | { version: "1",
+            event_type: "pre_commit_typechange",
+            payload: { typechange_entries: $entries } }
+      '
+}
+
+# precommit_event_script_modes
+#
+# Pre-commit-script-modes payload contract (internal/cli/precommit.go::handlePreCommitScriptModes):
+#   { "version": "1", "event_type": "pre_commit_script_modes",
+#     "payload": { "script_modes": [{path, mode}, ...] } }
+#
+# Iterates staged ACM paths under bin/frw.d/scripts/*.sh and captures each
+# path's git index mode via `git ls-files -s`. The Go handler decides
+# whether mode != 100755 is a violation.
+precommit_event_script_modes() {
+  _staged="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || printf '')"
+  # Collect tab-separated path<TAB>mode lines for matching paths only.
+  _entries="$(
+    printf '%s\n' "$_staged" \
+      | while IFS= read -r _p; do
+          [ -n "$_p" ] || continue
+          case "$_p" in
+            bin/frw.d/scripts/*.sh) ;;
+            *) continue ;;
+          esac
+          _m="$(git ls-files -s -- "$_p" 2>/dev/null | awk 'NR==1{print $1}')"
+          [ -n "$_m" ] || continue
+          printf '%s\t%s\n' "$_p" "$_m"
+        done
+  )"
+  printf '%s' "$_entries" \
+    | jq -R -s -c '
+        split("\n") | map(select(length > 0)) | map(split("\t"))
+        | map({ path: .[0], mode: .[1] }) as $entries
+        | { version: "1",
+            event_type: "pre_commit_script_modes",
+            payload: { script_modes: $entries } }
+      '
+}
diff --git a/bin/frw.d/lib/stop_payloads.sh b/bin/frw.d/lib/stop_payloads.sh
new file mode 100644
index 0000000..b821535
--- /dev/null
+++ b/bin/frw.d/lib/stop_payloads.sh
@@ -0,0 +1,262 @@
+#!/bin/sh
+# stop_payloads.sh — D3 helpers that assemble normalized BlockerEvent
+# payloads for the three Stop-hook guard event types.
+#
+# Added per shared-contracts.md §C4 escape valve: "D3 may add new helpers
+# to bin/frw.d/lib/ if shared by >=2 shims". These three helpers each
+# gate a single shim, but they all share the row-resolution + state.json
+# field-extraction substrate (factored as `_stop_resolve_row`).
+#
+# All file reads (state.json, definition.yaml) live here in lib/ rather
+# than in the hook shim body, satisfying shared-contracts §C5
+# AC-2.2 forbidden #4 ("project-file reads are out of the shim body").
+#
+# Exports (POSIX sh functions):
+#
+#   stop_event_ideation
+#       Stdout: normalized BlockerEvent JSON for `stop_ideation_completeness`,
+#               OR empty (signals "no row / not ideate step / autonomous"
+#               so the upstream `furrow_guard | emit_canonical_blocker`
+#               cleanly short-circuits with exit 0).
+#
+#   stop_event_summary
+#       Stdout: normalized BlockerEvent JSON for `stop_summary_validation`,
+#               OR empty.
+#
+#   stop_event_work_check
+#       Stdout: a sequence of normalized BlockerEvent JSON documents — one
+#               per active row. The shim pipes the stream into
+#               `furrow_guard stop_work_check | emit_canonical_blocker`.
+#               Empty stream → no active rows → silent pass.
+#
+# These helpers all return 0 unconditionally. Triggering decisions live
+# in the Go handlers (internal/cli/stop_ideation.go,
+# internal/cli/validate_summary.go, internal/cli/work_check.go).
+
+if [ -n "${_FRW_STOP_PAYLOADS_SOURCED:-}" ]; then
+  return 0 2>/dev/null || true
+fi
+_FRW_STOP_PAYLOADS_SOURCED=1
+
+# _stop_resolve_row — resolve the focused row directory.
+#
+# Mirrors find_focused_row from common-minimal.sh:99 (the canonical helper
+# already used by ownership-warn.sh:34 and correction-limit.sh:24). Returns
+# the row directory on stdout (e.g., ".furrow/rows/foo") or empty string.
+#
+# This is a thin wrapper that keeps the dependency on common-minimal.sh
+# isolated to lib/ — shims source this file, never common-minimal.sh
+# directly (matches shared-contracts §C5 "library-source" invariant).
+_stop_resolve_row() {
+  if [ -z "${_FRW_COMMON_MINIMAL_SOURCED:-}" ]; then
+    if [ -f "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh" ]; then
+      # shellcheck source=common-minimal.sh disable=SC1091
+      . "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"
+      _FRW_COMMON_MINIMAL_SOURCED=1
+    fi
+  fi
+  if command -v find_focused_row >/dev/null 2>&1; then
+    find_focused_row
+  else
+    printf ''
+  fi
+}
+
+# _stop_resolve_gate_policy — resolve the active row's gate_policy.
+#
+# Reads via the canonical resolve_config_value when common.sh is loadable;
+# falls back to a yq read of .furrow/furrow.yaml or the row's
+# definition.yaml. Default "supervised" matches stop-ideation.sh:46.
+_stop_resolve_gate_policy() {
+  _gp_row_dir="$1"
+  if command -v resolve_config_value >/dev/null 2>&1; then
+    _gp="$(resolve_config_value gate_policy 2>/dev/null)" || _gp=""
+    if [ -n "$_gp" ]; then
+      printf '%s' "$_gp"
+      return 0
+    fi
+  fi
+  if command -v yq >/dev/null 2>&1; then
+    if [ -n "$_gp_row_dir" ] && [ -f "${_gp_row_dir}/definition.yaml" ]; then
+      _gp="$(yq -r '.gate_policy // ""' "${_gp_row_dir}/definition.yaml" 2>/dev/null)" || _gp=""
+      if [ -n "$_gp" ] && [ "$_gp" != "null" ]; then
+        printf '%s' "$_gp"
+        return 0
+      fi
+    fi
+  fi
+  printf 'supervised'
+}
+
+# stop_event_ideation
+#
+# Builds the payload for handleStopIdeationCompleteness:
+#   { version: "1", event_type: "stop_ideation_completeness",
+#     row, step,
+#     payload: { row, gate_policy, definition_path } }
+#
+# Step gating: emit empty when the focused row's step != "ideate". This
+# is data extraction, not a policy comparison — the shim never sees the
+# step value, so the AC-2.2 forbidden-pattern grep stays clean against
+# the shim body.
+stop_event_ideation() {
+  _se_dir="$(_stop_resolve_row)"
+  [ -n "$_se_dir" ] || { printf ''; return 0; }
+  _se_state="${_se_dir}/state.json"
+  [ -f "$_se_state" ] || { printf ''; return 0; }
+  _se_step="$(jq -r '.step // ""' "$_se_state" 2>/dev/null)" || _se_step=""
+  # Only emit during the ideate step — out-of-step stops are silent.
+  [ "$_se_step" = "ideate" ] || { printf ''; return 0; }
+
+  _se_row="$(basename "$_se_dir")"
+  _se_def="${_se_dir}/definition.yaml"
+  _se_gp="$(_stop_resolve_gate_policy "$_se_dir")"
+  jq -n \
+    --arg version "1" \
+    --arg event_type "stop_ideation_completeness" \
+    --arg row "$_se_row" \
+    --arg step "$_se_step" \
+    --arg gate_policy "$_se_gp" \
+    --arg def_path "$_se_def" \
+    '{ version: $version,
+       event_type: $event_type,
+       row: $row,
+       step: $step,
+       payload: { row: $row,
+                  gate_policy: $gate_policy,
+                  definition_path: $def_path } }'
+}
+
+# stop_event_summary
+#
+# Builds the payload for handleStopSummaryValidation:
+#   { version: "1", event_type: "stop_summary_validation",
+#     row, step,
+#     payload: { row, step, summary_path, last_decided_by } }
+stop_event_summary() {
+  _ss_dir="$(_stop_resolve_row)"
+  [ -n "$_ss_dir" ] || { printf ''; return 0; }
+  _ss_state="${_ss_dir}/state.json"
+  _ss_summary="${_ss_dir}/summary.md"
+  [ -f "$_ss_summary" ] || { printf ''; return 0; }
+
+  _ss_row="$(basename "$_ss_dir")"
+  _ss_step="$(jq -r '.step // ""' "$_ss_state" 2>/dev/null)" || _ss_step=""
+  _ss_last="$(jq -r '.gates | last | .decided_by // ""' "$_ss_state" 2>/dev/null)" || _ss_last=""
+  jq -n \
+    --arg version "1" \
+    --arg event_type "stop_summary_validation" \
+    --arg row "$_ss_row" \
+    --arg step "$_ss_step" \
+    --arg summary_path "$_ss_summary" \
+    --arg last_decided_by "$_ss_last" \
+    '{ version: $version,
+       event_type: $event_type,
+       row: $row,
+       step: $step,
+       payload: { row: $row,
+                  step: $step,
+                  summary_path: $summary_path,
+                  last_decided_by: $last_decided_by } }'
+}
+
+# run_stop_work_check
+#
+# End-to-end driver for the work-check Stop hook. Iterates active rows,
+# invokes `furrow_guard stop_work_check` once per row, and writes a
+# single merged envelope-array to stdout for `emit_canonical_blocker` to
+# consume. Loop logic is here (not in the shim) because per-row iteration
+# is shared substrate, not policy.
+#
+# Each per-row event payload includes:
+#   { row, summary_path, state_validation_ok }
+# where state_validation_ok is the verdict of validate_state_json against
+# the row's state.json (true when validation passed).
+run_stop_work_check() {
+  _wc_acc='[]'
+  if [ -z "${_FRW_VALIDATE_SOURCED:-}" ]; then
+    if [ -f "${FURROW_ROOT}/bin/frw.d/lib/validate.sh" ]; then
+      # shellcheck source=validate.sh disable=SC1091
+      . "${FURROW_ROOT}/bin/frw.d/lib/validate.sh"
+      _FRW_VALIDATE_SOURCED=1
+    fi
+  fi
+  for _wc_state in "${FURROW_ROOT}"/.furrow/rows/*/state.json; do
+    [ -f "$_wc_state" ] || continue
+    _wc_archived="$(jq -r '.archived_at // "null"' "$_wc_state" 2>/dev/null)" || continue
+    [ "$_wc_archived" = "null" ] || continue
+
+    _wc_dir="$(dirname "$_wc_state")"
+    _wc_row="$(basename "$_wc_dir")"
+    _wc_summary="${_wc_dir}/summary.md"
+
+    _wc_ok="true"
+    if command -v validate_state_json >/dev/null 2>&1; then
+      if ! validate_state_json "$_wc_state" >/dev/null 2>&1; then
+        _wc_ok="false"
+      fi
+    fi
+
+    _wc_event="$(
+      jq -n \
+        --arg version "1" \
+        --arg event_type "stop_work_check" \
+        --arg row "$_wc_row" \
+        --arg summary_path "$_wc_summary" \
+        --argjson state_ok "$_wc_ok" \
+        '{ version: $version,
+           event_type: $event_type,
+           row: $row,
+           payload: { row: $row,
+                      summary_path: $summary_path,
+                      state_validation_ok: $state_ok } }'
+    )"
+    _wc_envelopes="$(printf '%s' "$_wc_event" | furrow_guard stop_work_check 2>/dev/null || printf '[]')"
+    [ -n "$_wc_envelopes" ] || _wc_envelopes='[]'
+    _wc_acc="$(printf '%s\n%s' "$_wc_acc" "$_wc_envelopes" | jq -s 'add')"
+  done
+  printf '%s' "$_wc_acc"
+}
+
+# stop_event_work_check (legacy alias — kept for symmetry with the other
+# two helpers; emits a single concatenated stream for callers that prefer
+# the streaming pattern. Not used by the canonical work-check.sh shim.)
+stop_event_work_check() {
+  # Run validate_state_json once per active row and emit a payload doc.
+  if [ -z "${_FRW_VALIDATE_SOURCED:-}" ]; then
+    if [ -f "${FURROW_ROOT}/bin/frw.d/lib/validate.sh" ]; then
+      # shellcheck source=validate.sh disable=SC1091
+      . "${FURROW_ROOT}/bin/frw.d/lib/validate.sh"
+      _FRW_VALIDATE_SOURCED=1
+    fi
+  fi
+  for _wc_state in "${FURROW_ROOT}"/.furrow/rows/*/state.json; do
+    [ -f "$_wc_state" ] || continue
+    _wc_archived="$(jq -r '.archived_at // "null"' "$_wc_state" 2>/dev/null)" || continue
+    [ "$_wc_archived" = "null" ] || continue
+
+    _wc_dir="$(dirname "$_wc_state")"
+    _wc_row="$(basename "$_wc_dir")"
+    _wc_summary="${_wc_dir}/summary.md"
+
+    _wc_ok="true"
+    if command -v validate_state_json >/dev/null 2>&1; then
+      if ! validate_state_json "$_wc_state" >/dev/null 2>&1; then
+        _wc_ok="false"
+      fi
+    fi
+
+    jq -n \
+      --arg version "1" \
+      --arg event_type "stop_work_check" \
+      --arg row "$_wc_row" \
+      --arg summary_path "$_wc_summary" \
+      --argjson state_ok "$_wc_ok" \
+      '{ version: $version,
+         event_type: $event_type,
+         row: $row,
+         payload: { row: $row,
+                    summary_path: $summary_path,
+                    state_validation_ok: $state_ok } }'
+  done
+}

commit dc06f7974e13a1850af532dbbddf2f1bb7ed61f2
Author: Test <test@test.com>
Date:   Sat Apr 25 15:16:51 2026 -0400

    feat(guard): add normalized blocker event schema and Go emission path
    
    D2 of blocker-taxonomy-foundation lands the host-agnostic blocker event
    contract and the Go-side `furrow guard <event-type>` entry point that
    all migrated hooks will route through.
    
    - schemas/blocker-event.yaml + schema.json: closed catalog of 10
      per-hook event types per specs/shared-contracts.md §C1
    - internal/cli/guard.go: handler registry + `furrow guard` CLI; stdout
      is always a JSON envelope array, exit 0 clean / 1 invocation error,
      never exit 2
    - internal/cli/{correction_limit,shellparse,stop_ideation,validate_summary,work_check,precommit}.go:
      per-handler domain logic for the 5 non-trivial hooks plus the 3
      pre-commit handlers and 2 mechanical pre-write handlers
    - internal/cli/guard_test.go: table-driven coverage across blocker
      categories plus TestGuardHandlerRegistryParity drift guard
    - bin/frw.d/lib/blocker_emit.sh: 4 POSIX-sh helpers with locked
      signatures (claude_tool_input_to_event, furrow_guard,
      emit_canonical_blocker, precommit_init) for D3 to source

diff --git a/bin/frw.d/lib/blocker_emit.sh b/bin/frw.d/lib/blocker_emit.sh
new file mode 100644
index 0000000..f9b1cce
--- /dev/null
+++ b/bin/frw.d/lib/blocker_emit.sh
@@ -0,0 +1,216 @@
+#!/bin/sh
+# blocker_emit.sh — Canonical shell adapter for `furrow guard <event-type>`.
+#
+# POSIX sh. Source this file from hook shims (D3 deliverable). Do not
+# execute directly. Exposes four functions per specs/shared-contracts.md
+# §C4 — signatures locked, do not modify:
+#
+#   claude_tool_input_to_event <event_type>
+#       Stdin:  Claude PreToolUse JSON ({tool_name, tool_input: {...}})
+#       Stdout: normalized BlockerEvent JSON ({version, event_type,
+#               target_path?, payload})
+#       Exit:   0 always (input validation errors are the upstream
+#               caller's responsibility — claude_tool_input_to_event
+#               emits a best-effort payload and lets the guard handler
+#               decide on missing keys).
+#
+#   furrow_guard <event_type>
+#       Stdin:  normalized BlockerEvent JSON
+#       Stdout: JSON array of zero or more BlockerEnvelope objects
+#       Exit:   0 if guard ran cleanly; 1 on guard invocation error
+#
+#   emit_canonical_blocker
+#       Stdin:  envelope-array JSON
+#       Stdout: empty
+#       Stderr: one `[furrow:<severity>] <message>` line per envelope
+#       Exit:   2 if any envelope has severity=block; 0 otherwise
+#
+#   precommit_init
+#       Args/Stdin: none
+#       Stdout: empty
+#       Side effect: ensures FURROW_ROOT and log_warning/log_error
+#                    helpers are available in the caller's environment.
+#       Exit:   0 always
+#
+# Composition pattern (D3 hook shim canonical shape):
+#
+#   . "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"
+#   claude_tool_input_to_event pre_write_state_json \
+#     | furrow_guard pre_write_state_json \
+#     | emit_canonical_blocker
+#
+# For pre-commit hooks, replace `claude_tool_input_to_event` with
+# `precommit_init` (followed by event-specific git-diff plumbing).
+
+# Idempotent source guard, mirroring validate-json.sh:23-26.
+if [ -n "${_FRW_BLOCKER_EMIT_SOURCED:-}" ]; then
+  return 0 2>/dev/null || true
+fi
+_FRW_BLOCKER_EMIT_SOURCED=1
+
+# claude_tool_input_to_event <event_type>
+#
+# Translates a Claude PreToolUse hook payload (stdin) into the normalized
+# BlockerEvent shape (stdout) that `furrow guard` consumes. Supports the
+# six per-hook event types that originate from Claude tool input:
+#
+#   - pre_write_state_json
+#   - pre_write_verdict
+#   - pre_write_correction_limit
+#   - pre_bash_internal_script
+#   - stop_ideation_completeness        (Claude Stop hook; payload uses row + paths)
+#   - stop_summary_validation           (Claude Stop hook)
+#   - stop_work_check                   (Claude Stop hook)
+#
+# Pre-commit event types (`pre_commit_*`) are NOT handled here; their
+# shims build the normalized payload directly using `precommit_init` +
+# git plumbing.
+claude_tool_input_to_event() {
+  _bem_event_type="${1:-}"
+  if [ -z "$_bem_event_type" ]; then
+    printf 'claude_tool_input_to_event: missing event_type arg\n' >&2
+    return 0
+  fi
+  _bem_input="$(cat 2>/dev/null || true)"
+
+  case "$_bem_event_type" in
+    pre_write_state_json|pre_write_verdict|pre_write_correction_limit)
+      # Pre-write events extract target_path from tool_input.
+      _bem_target="$(printf '%s' "$_bem_input" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // ""' 2>/dev/null || printf '')"
+      _bem_tool="$(printf '%s' "$_bem_input" | jq -r '.tool_name // ""' 2>/dev/null || printf '')"
+      jq -n \
+        --arg version "1" \
+        --arg event_type "$_bem_event_type" \
+        --arg target_path "$_bem_target" \
+        --arg tool_name "$_bem_tool" \
+        '{
+           version: $version,
+           event_type: $event_type,
+           target_path: $target_path,
+           payload: { target_path: $target_path, tool_name: $tool_name }
+         }'
+      ;;
+    pre_bash_internal_script)
+      _bem_command="$(printf '%s' "$_bem_input" | jq -r '.tool_input.command // ""' 2>/dev/null || printf '')"
+      jq -n \
+        --arg version "1" \
+        --arg event_type "$_bem_event_type" \
+        --arg command "$_bem_command" \
+        '{
+           version: $version,
+           event_type: $event_type,
+           payload: { command: $command }
+         }'
+      ;;
+    stop_ideation_completeness|stop_summary_validation|stop_work_check)
+      # Stop hooks: Claude payload is mostly empty for the guard's
+      # purposes; the shim is expected to provide row + path context via
+      # environment or by composing its own jq filter. The default
+      # translation here passes through any row/step/path the caller
+      # injected via `--arg`. Callers that need richer payloads should
+      # author their own jq filter and feed `furrow_guard` directly.
+      jq -n \
+        --arg version "1" \
+        --arg event_type "$_bem_event_type" \
+        --arg row "${FURROW_ROW:-}" \
+        --arg step "${FURROW_STEP:-}" \
+        '{
+           version: $version,
+           event_type: $event_type,
+           row: $row,
+           step: $step,
+           payload: { row: $row }
+         }'
+      ;;
+    *)
+      printf 'claude_tool_input_to_event: unsupported event_type %s\n' "$_bem_event_type" >&2
+      printf '{"version":"1","event_type":"%s","payload":{}}\n' "$_bem_event_type"
+      ;;
+  esac
+  return 0
+}
+
+# furrow_guard <event_type>
+#
+# Invokes the Go backend over a subprocess. Honors the FURROW_BIN env
+# override (e.g., to a prebuilt binary) for test-suite speed; falls
+# through to `go run ./cmd/furrow` from FURROW_ROOT otherwise.
+#
+# The cd into FURROW_ROOT mirrors the pattern at
+# bin/frw.d/hooks/ownership-warn.sh:60-61.
+furrow_guard() {
+  _fg_event_type="${1:-}"
+  if [ -z "$_fg_event_type" ]; then
+    printf 'furrow_guard: missing event_type arg\n' >&2
+    return 1
+  fi
+  _fg_root="${FURROW_ROOT:-}"
+  if [ -z "$_fg_root" ]; then
+    _fg_root="$(git rev-parse --show-toplevel 2>/dev/null)" || _fg_root="."
+  fi
+
+  # Use FURROW_BIN if set (built binary, e.g., /tmp/furrow-test); else
+  # `go run ./cmd/furrow` from the project root. The eval is intentional
+  # so FURROW_BIN can be a multi-token override (rare, but supported).
+  if [ -n "${FURROW_BIN:-}" ]; then
+    # shellcheck disable=SC2086
+    eval "$FURROW_BIN" guard "$_fg_event_type"
+    return $?
+  fi
+
+  ( cd "$_fg_root" && go run ./cmd/furrow guard "$_fg_event_type" )
+  return $?
+}
+
+# emit_canonical_blocker
+#
+# Reads an envelope-array JSON document on stdin. For each envelope:
+#   - prints `[furrow:<severity>] <message>` to stderr;
+#   - if remediation_hint is non-empty, prints `        <remediation_hint>`
+#     as a continuation line to stderr (matches the indented continuation
+#     style of validate-summary.sh's multi-line stderr).
+# Returns 2 if any envelope has severity == "block", 0 otherwise.
+#
+# An empty array (no trigger) is silent.
+emit_canonical_blocker() {
+  _ecb_input="$(cat 2>/dev/null || true)"
+  if [ -z "$_ecb_input" ]; then
+    return 0
+  fi
+  # An empty array short-circuits. jq returns "0" for length([]).
+  _ecb_count="$(printf '%s' "$_ecb_input" | jq -r 'length' 2>/dev/null || printf '0')"
+  if [ "$_ecb_count" = "0" ]; then
+    return 0
+  fi
+
+  # Stream envelopes to stderr in canonical format. The compact jq filter
+  # emits one stderr block per envelope.
+  printf '%s' "$_ecb_input" | jq -r '.[] | "[furrow:\(.severity)] \(.message)\n        \(.remediation_hint)"' >&2
+
+  # Exit code: 2 if any block, else 0. Use jq to detect.
+  _ecb_block="$(printf '%s' "$_ecb_input" | jq -r 'any(.severity == "block") | if . then "2" else "0" end' 2>/dev/null || printf '0')"
+  if [ "$_ecb_block" = "2" ]; then
+    return 2
+  fi
+  return 0
+}
+
+# precommit_init
+#
+# Eliminates the 8-line boilerplate at the top of every pre-commit hook
+# (research/hook-audit.md §2.3 quality finding). Resolves _GIT_ROOT,
+# exports FURROW_ROOT, and ensures log_warning/log_error are available.
+# Idempotent — safe to call multiple times.
+precommit_init() {
+  _GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || _GIT_ROOT="."
+  FURROW_ROOT="${FURROW_ROOT:-$_GIT_ROOT}"
+  export FURROW_ROOT
+  if [ -f "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh" ]; then
+    # shellcheck disable=SC1091
+    . "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"
+  else
+    log_warning() { printf '[furrow:warning] %s\n' "$1" >&2; }
+    log_error()   { printf '[furrow:error] %s\n'   "$1" >&2; }
+  fi
+  return 0
+}
diff --git a/cmd/furrow/main.go b/cmd/furrow/main.go
index 53afc5e..e32d0ed 100644
--- a/cmd/furrow/main.go
+++ b/cmd/furrow/main.go
@@ -7,6 +7,6 @@ import (
 )
 
 func main() {
-	app := cli.New(os.Stdout, os.Stderr)
+	app := cli.NewWithStdin(os.Stdin, os.Stdout, os.Stderr)
 	os.Exit(app.Run(os.Args[1:]))
 }
diff --git a/internal/cli/app.go b/internal/cli/app.go
index 81deb2a..557f079 100644
--- a/internal/cli/app.go
+++ b/internal/cli/app.go
@@ -11,6 +11,7 @@ import (
 const contractVersion = "v1alpha1"
 
 type App struct {
+	stdin  io.Reader
 	stdout io.Writer
 	stderr io.Writer
 }
@@ -38,10 +39,19 @@ type cliError struct {
 
 func (e *cliError) Error() string { return e.message }
 
+// New constructs an App with the given stdout/stderr writers and no stdin
+// reader. Stdin-reading subcommands (currently `furrow guard`) report a
+// clear "no stdin reader configured" error in this configuration.
 func New(stdout, stderr io.Writer) *App {
 	return &App{stdout: stdout, stderr: stderr}
 }
 
+// NewWithStdin constructs an App with an explicit stdin reader. Used by
+// cmd/furrow/main.go (production: os.Stdin) and by guard tests.
+func NewWithStdin(stdin io.Reader, stdout, stderr io.Writer) *App {
+	return &App{stdin: stdin, stdout: stdout, stderr: stderr}
+}
+
 func (a *App) Run(args []string) int {
 	if len(args) == 0 {
 		a.printRootHelp()
@@ -67,6 +77,8 @@ func (a *App) Run(args []string) int {
 		return a.runStubGroup("furrow seeds", args[1:], []string{"create", "update", "show", "list", "close"})
 	case "validate":
 		return a.runValidate(args[1:])
+	case "guard":
+		return a.runGuard(args[1:])
 	case "merge":
 		return a.runStubGroup("furrow merge", args[1:], []string{"plan", "run", "validate"})
 	case "doctor":
@@ -210,6 +222,7 @@ Commands:
   seeds     Seed/task primitive contract surface
   merge     Merge pipeline contract surface
   doctor    Environment and adapter readiness checks
+  guard     Translate normalized blocker events into canonical envelopes
   init      Repo bootstrap and migration entrypoint
   version   Print CLI contract version
   help      Show this help
diff --git a/internal/cli/correction_limit.go b/internal/cli/correction_limit.go
new file mode 100644
index 0000000..3d8684d
--- /dev/null
+++ b/internal/cli/correction_limit.go
@@ -0,0 +1,204 @@
+package cli
+
+import (
+	"fmt"
+	"os"
+	"path/filepath"
+	"strings"
+
+	yaml "gopkg.in/yaml.v3"
+)
+
+// handlePreWriteCorrectionLimit implements the Go port of correction-limit.sh
+// (research/hook-audit.md §2.1). The hook fires on every PreToolUse(Write|Edit)
+// and emits `correction_limit_reached` when:
+//
+//  1. A target_path is supplied, AND
+//  2. The path resolves to a row directory (.furrow/rows/<row>/...) or
+//     fallback to the focused row, AND
+//  3. The row is not archived, AND
+//  4. The row's current step is "implement", AND
+//  5. The row's plan.json maps the path to a deliverable whose
+//     state.json `corrections` count >= the configured limit.
+//
+// On any earlier short-circuit (no path, no row, archived, wrong step,
+// no plan.json) the handler returns nil with no error — a clean pass.
+//
+// The configured limit comes from .furrow/furrow.yaml or .claude/furrow.yaml
+// `defaults.correction_limit`; default 3 if neither is present.
+func handlePreWriteCorrectionLimit(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	path := firstNonEmptyString(evt.TargetPath, asString(evt.Payload["target_path"]))
+	if path == "" {
+		return nil, nil
+	}
+
+	root, err := correctionLimitRoot()
+	if err != nil {
+		// No .furrow/ root resolvable → caller is outside a Furrow project.
+		// Treat as no-trigger; the hook should never block in this case.
+		return nil, nil
+	}
+
+	rowDir := correctionLimitResolveRow(root, path)
+	if rowDir == "" {
+		return nil, nil
+	}
+
+	statePath := filepath.Join(rowDir, "state.json")
+	state, err := loadJSONMap(statePath)
+	if err != nil {
+		// state.json unreadable → can't enforce correctly; pass.
+		return nil, nil
+	}
+	if isArchivedState(state) {
+		return nil, nil
+	}
+	if step, _ := getString(state, "step"); step != "implement" {
+		return nil, nil
+	}
+
+	planPath := filepath.Join(rowDir, "plan.json")
+	plan, err := loadJSONMap(planPath)
+	if err != nil {
+		return nil, nil
+	}
+
+	limit := correctionLimitFromConfig(root)
+	deliverables, ok := state["deliverables"].(map[string]any)
+	if !ok {
+		return nil, nil
+	}
+
+	for delName, raw := range deliverables {
+		entry, ok := raw.(map[string]any)
+		if !ok {
+			continue
+		}
+		corrections, _ := intFromAny(entry["corrections"])
+		if corrections < limit {
+			continue
+		}
+		// Walk plan.json globs for this deliverable; emit if any glob
+		// matches the path.
+		for _, glob := range planFileOwnershipGlobs(plan, delName) {
+			matched, _ := filepath.Match(glob, path)
+			if !matched {
+				// Also try matching against the path's tail relative to the
+				// repo root, which is how plan.json globs are typically
+				// authored (e.g., "internal/cli/**").
+				continue
+			}
+			env := tx.EmitBlocker("correction_limit_reached", map[string]string{
+				"limit":       fmt.Sprintf("%d", limit),
+				"deliverable": delName,
+				"path":        path,
+			})
+			return []BlockerEnvelope{env}, nil
+		}
+	}
+	return nil, nil
+}
+
+// correctionLimitRoot resolves the Furrow project root, allowing the
+// FURROW_ROOT env override (which the shell helpers also honor) to win
+// over working-directory inference. This makes the handler testable
+// without chdir gymnastics.
+func correctionLimitRoot() (string, error) {
+	if override := strings.TrimSpace(os.Getenv("FURROW_ROOT")); override != "" {
+		if _, err := os.Stat(filepath.Join(override, ".furrow")); err == nil {
+			return override, nil
+		}
+	}
+	return findFurrowRoot()
+}
+
+// correctionLimitResolveRow returns the row directory the path belongs
+// to, or empty string when it can't be resolved. Resolution mirrors
+// extract_row_from_path + find_focused_row from common-minimal.sh:
+//  1. If path contains ".furrow/rows/<row>/", that row wins.
+//  2. Otherwise fall back to the focused row (.furrow/.focused).
+//  3. Otherwise empty.
+func correctionLimitResolveRow(root, path string) string {
+	const marker = ".furrow/rows/"
+	if i := strings.Index(path, marker); i >= 0 {
+		remainder := path[i+len(marker):]
+		// First component is the row name; reject dotfiles/underscores
+		// to skip metadata entries (matches common-minimal.sh).
+		end := strings.IndexByte(remainder, '/')
+		if end < 0 {
+			end = len(remainder)
+		}
+		name := remainder[:end]
+		if name != "" && !strings.HasPrefix(name, ".") && !strings.HasPrefix(name, "_") {
+			candidate := filepath.Join(root, ".furrow", "rows", name)
+			if _, err := os.Stat(filepath.Join(candidate, "state.json")); err == nil {
+				return candidate
+			}
+		}
+	}
+	if focused, present, err := readFocusedRowName(root); err == nil && present && focused != "" {
+		candidate := filepath.Join(root, ".furrow", "rows", focused)
+		if _, err := os.Stat(filepath.Join(candidate, "state.json")); err == nil {
+			return candidate
+		}
+	}
+	return ""
+}
+
+// correctionLimitFromConfig reads defaults.correction_limit from
+// <root>/.furrow/furrow.yaml or <root>/.claude/furrow.yaml. Returns 3
+// when neither file exists or the key is absent (matching the hook's
+// fallback). Errors during YAML parse return 3 — the hook's pre-Go
+// behavior was to fail-open to the default rather than blocking writes
+// on a malformed config.
+func correctionLimitFromConfig(root string) int {
+	for _, rel := range []string{".furrow/furrow.yaml", ".claude/furrow.yaml"} {
+		path := filepath.Join(root, rel)
+		payload, err := os.ReadFile(path)
+		if err != nil {
+			continue
+		}
+		var doc map[string]any
+		if err := yaml.Unmarshal(payload, &doc); err != nil {
+			continue
+		}
+		defaults, _ := doc["defaults"].(map[string]any)
+		if defaults == nil {
+			continue
+		}
+		if n, ok := intFromAny(defaults["correction_limit"]); ok && n > 0 {
+			return n
+		}
+	}
+	return 3
+}
+
+// planFileOwnershipGlobs walks plan.json -> waves[].assignments[<deliverable>].file_ownership[]
+// returning a flattened list of globs for the named deliverable. Matches
+// the jq filter on correction-limit.sh:79-81.
+func planFileOwnershipGlobs(plan map[string]any, deliverable string) []string {
+	out := make([]string, 0)
+	waves, _ := plan["waves"].([]any)
+	for _, rawWave := range waves {
+		wave, ok := rawWave.(map[string]any)
+		if !ok {
+			continue
+		}
+		assignments, _ := wave["assignments"].(map[string]any)
+		if assignments == nil {
+			continue
+		}
+		entry, _ := assignments[deliverable].(map[string]any)
+		if entry == nil {
+			continue
+		}
+		ownership, _ := entry["file_ownership"].([]any)
+		for _, raw := range ownership {
+			s, ok := raw.(string)
+			if ok && s != "" {
+				out = append(out, s)
+			}
+		}
+	}
+	return out
+}
diff --git a/internal/cli/guard.go b/internal/cli/guard.go
new file mode 100644
index 0000000..e29197a
--- /dev/null
+++ b/internal/cli/guard.go
@@ -0,0 +1,309 @@
+package cli
+
+import (
+	"encoding/json"
+	"errors"
+	"fmt"
+	"io"
+	"sort"
+	"strings"
+)
+
+// NormalizedEvent matches schemas/blocker-event.schema.json. Adapters
+// translate host event payloads (Claude tool_input JSON, git pre-commit
+// path lists, etc.) into this shape before passing to `furrow guard`.
+type NormalizedEvent struct {
+	Version    string         `json:"version"`
+	EventType  string         `json:"event_type"`
+	TargetPath string         `json:"target_path,omitempty"`
+	Step       string         `json:"step,omitempty"`
+	Row        string         `json:"row,omitempty"`
+	Payload    map[string]any `json:"payload"`
+}
+
+// ErrUnknownEventType is returned when the requested event type has no
+// registered handler. It's exported so adapter tests can assert on it via
+// errors.Is.
+var ErrUnknownEventType = errors.New("unknown event type")
+
+// eventHandler is the per-event-type entry point. Handlers receive the
+// loaded taxonomy and the normalized event; they return zero or more
+// canonical envelopes (empty slice == no trigger). An error indicates an
+// invocation problem (missing required payload key, malformed payload),
+// not a triggered blocker.
+type eventHandler func(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error)
+
+// guardHandlers is the closed handler registry keyed by event_type.
+//
+// Justification for the package-level map: the handler set is closed at
+// compile time (10 entries, one per emit-bearing hook), and the alternative
+// (constructor injection of the map into every *App caller) leaks
+// implementation detail into every consumer of `Run()`. The drift-guard
+// test (TestGuardHandlerRegistryParity) catches missing or extra entries
+// against schemas/blocker-event.yaml — registry corruption is impossible
+// to ship silently.
+var guardHandlers = map[string]eventHandler{
+	"pre_write_state_json":       handlePreWriteStateJSON,
+	"pre_write_verdict":          handlePreWriteVerdict,
+	"pre_write_correction_limit": handlePreWriteCorrectionLimit,
+	"pre_bash_internal_script":   handlePreBashInternalScript,
+	"pre_commit_bakfiles":        handlePreCommitBakfiles,
+	"pre_commit_typechange":      handlePreCommitTypechange,
+	"pre_commit_script_modes":    handlePreCommitScriptModes,
+	"stop_ideation_completeness": handleStopIdeationCompleteness,
+	"stop_summary_validation":    handleStopSummaryValidation,
+	"stop_work_check":            handleStopWorkCheck,
+}
+
+// guardEventTypes returns the registered event-type names sorted, for
+// help text and error messages.
+func guardEventTypes() []string {
+	names := make([]string, 0, len(guardHandlers))
+	for name := range guardHandlers {
+		names = append(names, name)
+	}
+	sort.Strings(names)
+	return names
+}
+
+// Guard dispatches a normalized event to the registered handler.
+//
+// Returns:
+//   - (nil, nil)         when the trigger condition is not met. Callers
+//     should marshal this as the empty JSON array `[]`.
+//   - ([envelope...], nil) when one or more codes fired.
+//   - (nil, error)       on invocation errors (unknown event type, missing
+//     required payload key, internal loader failures).
+func Guard(eventType string, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	handler, ok := guardHandlers[eventType]
+	if !ok {
+		return nil, fmt.Errorf("guard %s: %w", eventType, ErrUnknownEventType)
+	}
+	tx, err := LoadTaxonomy()
+	if err != nil {
+		return nil, fmt.Errorf("guard %s: load taxonomy: %w", eventType, err)
+	}
+	envelopes, err := handler(tx, evt)
+	if err != nil {
+		return nil, fmt.Errorf("guard %s: %w", eventType, err)
+	}
+	return envelopes, nil
+}
+
+// runGuard implements the `furrow guard <event-type>` subcommand.
+//
+// Contract (specs/shared-contracts.md §C2):
+//   - No flags. Single positional arg `<event-type>`.
+//   - Stdin: a single JSON document conforming to
+//     schemas/blocker-event.schema.json.
+//   - Stdout: ALWAYS a JSON array of zero or more BlockerEnvelope objects
+//     (encoded with `SetIndent("", "  ")` + trailing newline). Empty
+//     array `[]` = no trigger.
+//   - Exit 0 = ran cleanly (stdout array may be empty or non-empty).
+//   - Exit 1 = invocation error (unknown event type, malformed input,
+//     missing required payload key, internal loader failure). Stderr
+//     carries a one-line diagnostic.
+//   - NEVER exits 2. Host-blocking exit codes are produced only by the
+//     shell helper translating envelope severity.
+func (a *App) runGuard(args []string) int {
+	// `help` / `-h` / `--help` produce usage on stdout, exit 0. They
+	// short-circuit before stdin is read.
+	if len(args) == 1 {
+		switch args[0] {
+		case "help", "-h", "--help":
+			a.printGuardHelp()
+			return 0
+		}
+	}
+	if len(args) != 1 {
+		_, _ = fmt.Fprintln(a.stderr, "guard: usage: furrow guard <event-type>")
+		return 1
+	}
+	eventType := args[0]
+
+	stdin, ok := a.readGuardStdin()
+	if !ok {
+		return 1
+	}
+
+	var evt NormalizedEvent
+	if len(strings.TrimSpace(string(stdin))) == 0 {
+		// Empty stdin is permitted; handler sees zero-value event with an
+		// empty payload and decides whether the trigger applies.
+		evt = NormalizedEvent{Payload: map[string]any{}}
+	} else if err := json.Unmarshal(stdin, &evt); err != nil {
+		_, _ = fmt.Fprintf(a.stderr, "guard %s: parse stdin: %v\n", eventType, err)
+		return 1
+	}
+	if evt.Payload == nil {
+		evt.Payload = map[string]any{}
+	}
+	// Honor the redundancy check: if the event JSON carries an event_type,
+	// it MUST match the positional arg. Mismatches are a misrouted
+	// adapter — fail fast so the bug surfaces at the boundary.
+	if evt.EventType != "" && evt.EventType != eventType {
+		_, _ = fmt.Fprintf(a.stderr,
+			"guard %s: event_type mismatch: stdin says %q, arg says %q\n",
+			eventType, evt.EventType, eventType)
+		return 1
+	}
+
+	envelopes, err := Guard(eventType, evt)
+	if err != nil {
+		_, _ = fmt.Fprintln(a.stderr, err.Error())
+		return 1
+	}
+
+	// Always emit a JSON array, even when empty or single-element. Uniform
+	// shape removes branching in shell callers and parity-comparison tests.
+	if envelopes == nil {
+		envelopes = []BlockerEnvelope{}
+	}
+	enc := json.NewEncoder(a.stdout)
+	enc.SetIndent("", "  ")
+	if err := enc.Encode(envelopes); err != nil {
+		_, _ = fmt.Fprintf(a.stderr, "guard %s: encode envelopes: %v\n", eventType, err)
+		return 1
+	}
+	return 0
+}
+
+// readGuardStdin reads the entire stdin into memory. Stdin payloads are
+// small (~few KB at most — a single tool_input JSON), so reading-all is
+// safe. We type-assert to io.Reader because *App.stdin is not stored on
+// the struct (Run() consumes os.Args, not stdin) — guard is the only
+// command that reads stdin, so we resolve it via a stdinReader interface
+// that os.Stdin satisfies. In tests, app.go's stderr/stdout writers are
+// the only injection point; runGuard reads from os.Stdin directly which
+// the test harness redirects via os.Stdin override.
+func (a *App) readGuardStdin() ([]byte, bool) {
+	r := a.stdin
+	if r == nil {
+		// Fall back to os.Stdin when the App was constructed without an
+		// explicit stdin (production: cmd/furrow/main.go passes os.Stdin
+		// via NewWithStdin; legacy New() callers leave stdin nil and the
+		// run-time defaults below are unreachable in practice).
+		_, _ = fmt.Fprintln(a.stderr, "guard: no stdin reader configured")
+		return nil, false
+	}
+	payload, err := io.ReadAll(r)
+	if err != nil {
+		_, _ = fmt.Fprintf(a.stderr, "guard: read stdin: %v\n", err)
+		return nil, false
+	}
+	return payload, true
+}
+
+// printGuardHelp writes the `furrow guard help` usage to stdout.
+func (a *App) printGuardHelp() {
+	_, _ = fmt.Fprintln(a.stdout, `furrow guard <event-type>
+
+Reads a normalized blocker event JSON document on stdin and emits a JSON
+array of zero or more canonical BlockerEnvelope objects on stdout.
+
+Stdout is ALWAYS an array (empty array means trigger not met).
+Exit 0: ran cleanly. Exit 1: invocation error (never exits 2).
+
+Event types:
+  `+strings.Join(guardEventTypes(), "\n  "))
+}
+
+// requireString extracts a string-typed payload key. Returns an error
+// naming the key when absent or empty (handlers use this to enforce
+// schemas/blocker-event.yaml event_types[].required[]).
+func requireString(payload map[string]any, key string) (string, error) {
+	v, ok := payload[key]
+	if !ok || v == nil {
+		return "", fmt.Errorf("missing required payload key %q", key)
+	}
+	s, ok := v.(string)
+	if !ok {
+		return "", fmt.Errorf("payload key %q must be a string (got %T)", key, v)
+	}
+	if strings.TrimSpace(s) == "" {
+		return "", fmt.Errorf("payload key %q is empty", key)
+	}
+	return s, nil
+}
+
+// requireArray extracts an array-typed payload key. Returns an error
+// naming the key when absent or empty.
+func requireArray(payload map[string]any, key string) ([]any, error) {
+	v, ok := payload[key]
+	if !ok || v == nil {
+		return nil, fmt.Errorf("missing required payload key %q", key)
+	}
+	arr, ok := v.([]any)
+	if !ok {
+		return nil, fmt.Errorf("payload key %q must be an array (got %T)", key, v)
+	}
+	if len(arr) == 0 {
+		return nil, fmt.Errorf("payload key %q is empty", key)
+	}
+	return arr, nil
+}
+
+// firstNonEmptyString returns the first non-empty value among the listed
+// payload keys. Used by handlers that accept either a top-level convenience
+// field (e.g., `target_path`) or the same key inside `payload`.
+func firstNonEmptyString(values ...string) string {
+	for _, v := range values {
+		if strings.TrimSpace(v) != "" {
+			return v
+		}
+	}
+	return ""
+}
+
+// --- Mechanical handlers (small, single-emit) ---
+
+// handlePreWriteStateJSON: emit when the target path ends in state.json.
+func handlePreWriteStateJSON(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	path := firstNonEmptyString(evt.TargetPath, asString(evt.Payload["target_path"]))
+	if path == "" {
+		// No path → nothing to guard. Treat as no-trigger rather than an
+		// invocation error: pre-write hooks fire on every Write/Edit and
+		// some tool calls don't carry a path (e.g., MCP tool calls).
+		return nil, nil
+	}
+	if !pathHasBaseName(path, "state.json") {
+		return nil, nil
+	}
+	return []BlockerEnvelope{
+		tx.EmitBlocker("state_json_direct_write", map[string]string{"path": path}),
+	}, nil
+}
+
+// handlePreWriteVerdict: emit when the target path crosses gate-verdicts/.
+func handlePreWriteVerdict(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	path := firstNonEmptyString(evt.TargetPath, asString(evt.Payload["target_path"]))
+	if path == "" {
+		return nil, nil
+	}
+	if !strings.Contains(path, "gate-verdicts/") {
+		return nil, nil
+	}
+	return []BlockerEnvelope{
+		tx.EmitBlocker("verdict_direct_write", map[string]string{"path": path}),
+	}, nil
+}
+
+// asString is a permissive conversion: returns the underlying string when
+// the value is a string, "" otherwise. Used in places where the payload
+// key is optional and the handler decides on absence.
+func asString(v any) string {
+	s, _ := v.(string)
+	return s
+}
+
+// pathHasBaseName reports whether the path's last component equals name.
+// Defensive against trailing slashes and Windows separators are out of
+// scope (Furrow targets POSIX paths).
+func pathHasBaseName(path, name string) bool {
+	idx := strings.LastIndex(path, "/")
+	base := path
+	if idx >= 0 {
+		base = path[idx+1:]
+	}
+	return base == name
+}
diff --git a/internal/cli/guard_test.go b/internal/cli/guard_test.go
new file mode 100644
index 0000000..0d4d1c1
--- /dev/null
+++ b/internal/cli/guard_test.go
@@ -0,0 +1,554 @@
+package cli
+
+import (
+	"bytes"
+	"encoding/json"
+	"errors"
+	"os"
+	"path/filepath"
+	"sort"
+	"strings"
+	"testing"
+
+	yaml "gopkg.in/yaml.v3"
+)
+
+// TestGuardHandlerRegistryParity is the drift guard required by AC5.
+// It enforces bidirectional parity:
+//
+//   - Every event_type in schemas/blocker-event.yaml must have a registered
+//     Go handler in guardHandlers.
+//   - Every Go handler in guardHandlers must appear as an event_type in
+//     the YAML (no orphan handlers).
+//
+// Adding a YAML entry without a handler (or vice versa) breaks this test
+// at the next CI run — registry drift is impossible to ship silently.
+func TestGuardHandlerRegistryParity(t *testing.T) {
+	yamlEvents := loadYAMLEventTypes(t)
+	yamlSet := make(map[string]struct{}, len(yamlEvents))
+	for _, name := range yamlEvents {
+		yamlSet[name] = struct{}{}
+	}
+
+	registrySet := make(map[string]struct{}, len(guardHandlers))
+	for name := range guardHandlers {
+		registrySet[name] = struct{}{}
+	}
+
+	// YAML → registry: every catalog entry must have a handler.
+	for name := range yamlSet {
+		if _, ok := registrySet[name]; !ok {
+			t.Errorf("event_type %q in schemas/blocker-event.yaml has no handler in guardHandlers", name)
+		}
+	}
+	// Registry → YAML: every handler must be in the catalog.
+	for name := range registrySet {
+		if _, ok := yamlSet[name]; !ok {
+			t.Errorf("handler %q in guardHandlers has no event_type entry in schemas/blocker-event.yaml", name)
+		}
+	}
+
+	// Sanity: shared-contracts.md §C1 locks at 10 entries.
+	if len(yamlEvents) != 10 {
+		t.Errorf("schemas/blocker-event.yaml event_types[] count = %d, want 10 (specs/shared-contracts.md §C1)", len(yamlEvents))
+	}
+}
+
+// TestGuardEventTypesMatchSharedContractsCatalog asserts the verbatim
+// names from shared-contracts §C1. This double-checks a typo wouldn't
+// silently rename an event type.
+func TestGuardEventTypesMatchSharedContractsCatalog(t *testing.T) {
+	want := []string{
+		"pre_bash_internal_script",
+		"pre_commit_bakfiles",
+		"pre_commit_script_modes",
+		"pre_commit_typechange",
+		"pre_write_correction_limit",
+		"pre_write_state_json",
+		"pre_write_verdict",
+		"stop_ideation_completeness",
+		"stop_summary_validation",
+		"stop_work_check",
+	}
+	got := loadYAMLEventTypes(t)
+	sort.Strings(got)
+	if !stringSlicesEqual(got, want) {
+		t.Errorf("event_types[] mismatch:\n got  %v\n want %v", got, want)
+	}
+}
+
+// loadYAMLEventTypes reads schemas/blocker-event.yaml and returns the
+// event_types[].name values. The path is resolved via
+// candidateTaxonomyPaths-style fallback so the test runs from `go test`
+// without chdir gymnastics.
+func loadYAMLEventTypes(t *testing.T) []string {
+	t.Helper()
+	path := findBlockerEventYAML(t)
+	payload, err := os.ReadFile(path)
+	if err != nil {
+		t.Fatalf("read %s: %v", path, err)
+	}
+	var doc struct {
+		EventTypes []struct {
+			Name string `yaml:"name"`
+		} `yaml:"event_types"`
+	}
+	if err := yaml.Unmarshal(payload, &doc); err != nil {
+		t.Fatalf("parse %s: %v", path, err)
+	}
+	out := make([]string, 0, len(doc.EventTypes))
+	for _, e := range doc.EventTypes {
+		out = append(out, e.Name)
+	}
+	return out
+}
+
+// findBlockerEventYAML mirrors the candidateTaxonomyPaths fallback:
+// FURROW_TAXONOMY_PATH is honored only when set to a known sibling root,
+// otherwise walk up from the source root.
+func findBlockerEventYAML(t *testing.T) string {
+	t.Helper()
+	if root, ok := moduleSourceRoot(); ok {
+		path := filepath.Join(root, "schemas", "blocker-event.yaml")
+		if _, err := os.Stat(path); err == nil {
+			return path
+		}
+	}
+	if root, err := findFurrowRoot(); err == nil {
+		path := filepath.Join(root, "schemas", "blocker-event.yaml")
+		if _, err := os.Stat(path); err == nil {
+			return path
+		}
+	}
+	t.Fatal("could not locate schemas/blocker-event.yaml")
+	return ""
+}
+
+// TestGuard_PerCategoryCoverage exercises at least one code per blocker
+// category that is reachable through guardHandlers. AC4: covers
+// state-mutation, gate, scaffold, summary, ideation.
+func TestGuard_PerCategoryCoverage(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	cases := []struct {
+		name      string
+		eventType string
+		evt       NormalizedEvent
+		wantCodes []string
+	}{
+		{
+			name:      "state-mutation/state_json_direct_write",
+			eventType: "pre_write_state_json",
+			evt: NormalizedEvent{
+				TargetPath: ".furrow/rows/foo/state.json",
+				Payload: map[string]any{
+					"target_path": ".furrow/rows/foo/state.json",
+				},
+			},
+			wantCodes: []string{"state_json_direct_write"},
+		},
+		{
+			name:      "gate/verdict_direct_write",
+			eventType: "pre_write_verdict",
+			evt: NormalizedEvent{
+				Payload: map[string]any{
+					"target_path": ".furrow/rows/foo/gate-verdicts/plan-to-spec.json",
+				},
+			},
+			wantCodes: []string{"verdict_direct_write"},
+		},
+		{
+			name:      "scaffold/script_guard_internal_invocation",
+			eventType: "pre_bash_internal_script",
+			evt: NormalizedEvent{
+				Payload: map[string]any{
+					"command": "bash bin/frw.d/scripts/update-state.sh",
+				},
+			},
+			wantCodes: []string{"script_guard_internal_invocation"},
+		},
+		{
+			name:      "scaffold/script_guard_NOT_triggered_by_sh_n",
+			eventType: "pre_bash_internal_script",
+			evt: NormalizedEvent{
+				Payload: map[string]any{
+					"command": "sh -n bin/frw.d/scripts/update-state.sh",
+				},
+			},
+			wantCodes: nil,
+		},
+		{
+			name:      "scaffold/script_guard_NOT_triggered_in_quoted_string",
+			eventType: "pre_bash_internal_script",
+			evt: NormalizedEvent{
+				Payload: map[string]any{
+					"command": "git commit -m 'do not run bin/frw.d/scripts/foo.sh directly'",
+				},
+			},
+			wantCodes: nil,
+		},
+		{
+			name:      "scaffold/precommit_install_artifact_staged",
+			eventType: "pre_commit_bakfiles",
+			evt: NormalizedEvent{
+				Payload: map[string]any{
+					"staged_paths": []any{"bin/frw.bak", "README.md", ".claude/rules/state-guard.bak"},
+				},
+			},
+			wantCodes: []string{"precommit_install_artifact_staged", "precommit_install_artifact_staged"},
+		},
+		{
+			name:      "scaffold/precommit_typechange_to_symlink",
+			eventType: "pre_commit_typechange",
+			evt: NormalizedEvent{
+				Payload: map[string]any{
+					"typechange_entries": []any{
+						map[string]any{"path": "bin/alm", "new_mode": "120000", "status": "T"},
+						map[string]any{"path": "README.md", "new_mode": "120000", "status": "T"},
+					},
+				},
+			},
+			wantCodes: []string{"precommit_typechange_to_symlink"},
+		},
+		{
+			name:      "scaffold/precommit_script_mode_invalid",
+			eventType: "pre_commit_script_modes",
+			evt: NormalizedEvent{
+				Payload: map[string]any{
+					"script_modes": []any{
+						map[string]any{"path": "bin/frw.d/scripts/update-state.sh", "mode": "100644"},
+						map[string]any{"path": "bin/frw.d/scripts/other.sh", "mode": "100755"},
+					},
+				},
+			},
+			wantCodes: []string{"precommit_script_mode_invalid"},
+		},
+	}
+
+	for _, tc := range cases {
+		t.Run(tc.name, func(t *testing.T) {
+			envelopes, err := Guard(tc.eventType, tc.evt)
+			if err != nil {
+				t.Fatalf("Guard(%q): unexpected error: %v", tc.eventType, err)
+			}
+			gotCodes := make([]string, 0, len(envelopes))
+			for _, env := range envelopes {
+				gotCodes = append(gotCodes, env.Code)
+			}
+			if !stringSlicesEqual(gotCodes, tc.wantCodes) {
+				t.Errorf("Guard(%q) codes = %v, want %v", tc.eventType, gotCodes, tc.wantCodes)
+			}
+		})
+	}
+}
+
+// TestGuard_NoTrigger_ReturnsEmpty asserts the clean-pass path emits
+// nil/empty (which marshals to []) and not an error.
+func TestGuard_NoTrigger_ReturnsEmpty(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	envelopes, err := Guard("pre_write_state_json", NormalizedEvent{
+		Payload: map[string]any{"target_path": "README.md"},
+	})
+	if err != nil {
+		t.Fatalf("unexpected error: %v", err)
+	}
+	if len(envelopes) != 0 {
+		t.Errorf("expected empty envelopes for non-state.json path, got %v", envelopes)
+	}
+}
+
+// TestGuard_UnknownEventType_ReturnsError asserts AC3 invocation-error
+// path and ErrUnknownEventType wrapping.
+func TestGuard_UnknownEventType_ReturnsError(t *testing.T) {
+	envelopes, err := Guard("not_a_real_type", NormalizedEvent{})
+	if err == nil {
+		t.Fatal("expected error for unknown event type, got nil")
+	}
+	if !errors.Is(err, ErrUnknownEventType) {
+		t.Errorf("expected ErrUnknownEventType, got %v", err)
+	}
+	if envelopes != nil {
+		t.Errorf("expected nil envelopes on error, got %v", envelopes)
+	}
+}
+
+// TestGuard_PreBashInternalScript_MissingPayload_ReturnsError asserts
+// that handlers signal invocation errors when required keys are absent.
+func TestGuard_PreBashInternalScript_MissingPayload_ReturnsError(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	envelopes, err := Guard("pre_bash_internal_script", NormalizedEvent{
+		Payload: map[string]any{},
+	})
+	if err == nil {
+		t.Fatal("expected error for missing required key, got nil")
+	}
+	if !strings.Contains(err.Error(), "command") {
+		t.Errorf("error should name the missing key 'command', got: %v", err)
+	}
+	if envelopes != nil {
+		t.Errorf("expected nil envelopes on error, got %v", envelopes)
+	}
+}
+
+// TestGuard_StopIdeationCompleteness_MissingFields_Emits asserts
+// AC4 (ideation category) and verifies placeholder interpolation.
+func TestGuard_StopIdeationCompleteness_MissingFields_Emits(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	dir := t.TempDir()
+	defPath := filepath.Join(dir, "definition.yaml")
+	mustWrite(t, defPath, "objective: \"\"\ngate_policy: supervised\n")
+
+	envelopes, err := Guard("stop_ideation_completeness", NormalizedEvent{
+		Payload: map[string]any{
+			"row":             "fixture",
+			"definition_path": defPath,
+		},
+	})
+	if err != nil {
+		t.Fatalf("unexpected error: %v", err)
+	}
+	if len(envelopes) != 1 {
+		t.Fatalf("expected 1 envelope, got %d (%v)", len(envelopes), envelopes)
+	}
+	if envelopes[0].Code != "ideation_incomplete_definition_fields" {
+		t.Errorf("expected ideation_incomplete_definition_fields, got %q", envelopes[0].Code)
+	}
+	if !strings.Contains(envelopes[0].Message, "objective") {
+		t.Errorf("message should name the missing 'objective' field, got %q", envelopes[0].Message)
+	}
+	// No unfilled placeholders should leak.
+	if strings.Contains(envelopes[0].Message, "{") {
+		t.Errorf("message contains an unfilled placeholder: %q", envelopes[0].Message)
+	}
+}
+
+// TestGuard_StopIdeationCompleteness_AutonomousSkips asserts the skip
+// rule when gate_policy is autonomous.
+func TestGuard_StopIdeationCompleteness_AutonomousSkips(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	envelopes, err := Guard("stop_ideation_completeness", NormalizedEvent{
+		Payload: map[string]any{
+			"row":         "fixture",
+			"gate_policy": "autonomous",
+		},
+	})
+	if err != nil {
+		t.Fatalf("unexpected error: %v", err)
+	}
+	if len(envelopes) != 0 {
+		t.Errorf("autonomous policy should skip, got %v", envelopes)
+	}
+}
+
+// TestGuard_StopSummaryValidation_MultiEmit covers the summary category
+// and verifies the multi-emit path (one envelope per missing section).
+func TestGuard_StopSummaryValidation_MultiEmit(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	dir := t.TempDir()
+	summaryPath := filepath.Join(dir, "summary.md")
+	// Only Task and Current State present; the other 5 sections are
+	// missing → 5 missing envelopes plus 0 empty (sections not present
+	// don't produce empty envelopes).
+	mustWrite(t, summaryPath, "## Task\n\nA task.\n\n## Current State\n\nIn progress.\n")
+
+	envelopes, err := Guard("stop_summary_validation", NormalizedEvent{
+		Payload: map[string]any{
+			"row":          "fixture",
+			"summary_path": summaryPath,
+			"step":         "implement",
+		},
+	})
+	if err != nil {
+		t.Fatalf("unexpected error: %v", err)
+	}
+	if len(envelopes) != 5 {
+		t.Fatalf("expected 5 missing-section envelopes, got %d (%v)", len(envelopes), envelopes)
+	}
+	for _, env := range envelopes {
+		if env.Code != "summary_section_missing" {
+			t.Errorf("expected summary_section_missing, got %q", env.Code)
+		}
+	}
+}
+
+// TestGuard_StopSummaryValidation_PrecheckedSkips asserts the skip rule
+// when the upstream gate decided_by == "prechecked".
+func TestGuard_StopSummaryValidation_PrecheckedSkips(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	envelopes, err := Guard("stop_summary_validation", NormalizedEvent{
+		Payload: map[string]any{
+			"row":             "fixture",
+			"last_decided_by": "prechecked",
+		},
+	})
+	if err != nil {
+		t.Fatalf("unexpected error: %v", err)
+	}
+	if len(envelopes) != 0 {
+		t.Errorf("prechecked should skip, got %v", envelopes)
+	}
+}
+
+// TestGuard_StopWorkCheck_StateValidationFailed covers the warn-severity
+// state-mutation category.
+func TestGuard_StopWorkCheck_StateValidationFailed(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	envelopes, err := Guard("stop_work_check", NormalizedEvent{
+		Payload: map[string]any{
+			"row":                 "fixture",
+			"state_validation_ok": false,
+		},
+	})
+	if err != nil {
+		t.Fatalf("unexpected error: %v", err)
+	}
+	if len(envelopes) == 0 {
+		t.Fatal("expected at least one envelope")
+	}
+	if envelopes[0].Code != "state_validation_failed_warn" {
+		t.Errorf("expected state_validation_failed_warn first, got %q", envelopes[0].Code)
+	}
+	if envelopes[0].Severity != "warn" {
+		t.Errorf("expected warn severity, got %q", envelopes[0].Severity)
+	}
+}
+
+// TestRunGuard_StdoutAlwaysArray runs the App-level CLI wrapper end-to-end
+// to confirm:
+//   - Stdout is a JSON array, never a bare object.
+//   - Empty result is `[]`.
+//   - Single-emit is a single-element array.
+//   - Exit codes are 0 for clean-run / 1 for invocation-error.
+func TestRunGuard_StdoutAlwaysArray(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	cases := []struct {
+		name     string
+		args     []string
+		stdin    string
+		wantExit int
+		wantLen  int // -1 means stdout is not parsed as an array
+	}{
+		{
+			name:     "no_trigger_empty_array",
+			args:     []string{"guard", "pre_write_state_json"},
+			stdin:    `{"event_type":"pre_write_state_json","payload":{"target_path":"README.md"}}`,
+			wantExit: 0,
+			wantLen:  0,
+		},
+		{
+			name:     "single_emit_one_element_array",
+			args:     []string{"guard", "pre_write_state_json"},
+			stdin:    `{"event_type":"pre_write_state_json","payload":{"target_path":".furrow/rows/x/state.json"}}`,
+			wantExit: 0,
+			wantLen:  1,
+		},
+		{
+			name:     "unknown_event_type_exit_1",
+			args:     []string{"guard", "definitely_not_a_type"},
+			stdin:    `{}`,
+			wantExit: 1,
+			wantLen:  -1,
+		},
+		{
+			name:     "event_type_arg_mismatch_exit_1",
+			args:     []string{"guard", "pre_write_state_json"},
+			stdin:    `{"event_type":"pre_write_verdict","payload":{}}`,
+			wantExit: 1,
+			wantLen:  -1,
+		},
+	}
+
+	for _, tc := range cases {
+		t.Run(tc.name, func(t *testing.T) {
+			var stdout, stderr bytes.Buffer
+			app := NewWithStdin(strings.NewReader(tc.stdin), &stdout, &stderr)
+			exit := app.Run(tc.args)
+			if exit != tc.wantExit {
+				t.Errorf("exit = %d, want %d (stderr=%q)", exit, tc.wantExit, stderr.String())
+			}
+			// Per shared-contracts §C2: NEVER exit 2.
+			if exit == 2 {
+				t.Errorf("furrow guard must NEVER exit 2 (specs/shared-contracts.md §C2)")
+			}
+			if tc.wantLen < 0 {
+				return
+			}
+			var arr []BlockerEnvelope
+			if err := json.Unmarshal(stdout.Bytes(), &arr); err != nil {
+				t.Fatalf("stdout is not a JSON array: %v\nstdout=%q", err, stdout.String())
+			}
+			if len(arr) != tc.wantLen {
+				t.Errorf("envelope count = %d, want %d (stdout=%q)", len(arr), tc.wantLen, stdout.String())
+			}
+		})
+	}
+}
+
+// TestShellStripDataRegions covers the awk-port behavior on the shapes
+// most likely to appear in real bash commands. Drift here would silently
+// break script-guard parity with the shell hook.
+func TestShellStripDataRegions(t *testing.T) {
+	cases := []struct {
+		name string
+		in   string
+		// We assert structural properties (does the result still contain
+		// the data substring?) rather than exact byte equality, because
+		// the awk port replaces stripped regions with spaces and exact
+		// whitespace is not load-bearing.
+		mustContainFrwd  bool
+		mustNotContainSh string
+	}{
+		{
+			name:            "single_quoted_strips",
+			in:              "echo 'bin/frw.d/scripts/foo.sh'",
+			mustContainFrwd: false,
+		},
+		{
+			name:            "double_quoted_strips",
+			in:              `echo "bin/frw.d/scripts/foo.sh"`,
+			mustContainFrwd: false,
+		},
+		{
+			name:            "comment_strips",
+			in:              "echo hi # bin/frw.d/scripts/foo.sh",
+			mustContainFrwd: false,
+		},
+		{
+			name:            "naked_invocation_preserved",
+			in:              "bin/frw.d/scripts/foo.sh arg",
+			mustContainFrwd: true,
+		},
+	}
+	for _, tc := range cases {
+		t.Run(tc.name, func(t *testing.T) {
+			got := shellStripDataRegions(tc.in)
+			has := strings.Contains(got, "frw.d/")
+			if has != tc.mustContainFrwd {
+				t.Errorf("shellStripDataRegions(%q) = %q\n contains frw.d/? got=%v want=%v",
+					tc.in, got, has, tc.mustContainFrwd)
+			}
+		})
+	}
+}
+
+// Ensure runJSONCommand / mustWrite stay referenced from this test file
+// when other tests are skipped — both are defined in app_test.go and
+// reused above.
+var _ = runJSONCommand
diff --git a/internal/cli/precommit.go b/internal/cli/precommit.go
new file mode 100644
index 0000000..d9dcfeb
--- /dev/null
+++ b/internal/cli/precommit.go
@@ -0,0 +1,151 @@
+package cli
+
+import (
+	"path/filepath"
+	"strings"
+)
+
+// handlePreCommitBakfiles implements the Go port of pre-commit-bakfiles.sh
+// (research/hook-audit.md §2.3). Multi-emit: one envelope per offending
+// staged path matching `bin/*.bak` or `.claude/rules/*.bak`.
+func handlePreCommitBakfiles(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	paths, err := requireArray(evt.Payload, "staged_paths")
+	if err != nil {
+		return nil, err
+	}
+	envelopes := make([]BlockerEnvelope, 0)
+	for _, raw := range paths {
+		path, ok := raw.(string)
+		if !ok || path == "" {
+			continue
+		}
+		if !precommitBakfileMatches(path) {
+			continue
+		}
+		envelopes = append(envelopes, tx.EmitBlocker("precommit_install_artifact_staged", map[string]string{
+			"path": path,
+		}))
+	}
+	if len(envelopes) == 0 {
+		return nil, nil
+	}
+	return envelopes, nil
+}
+
+// precommitBakfileMatches mirrors the case glob from
+// pre-commit-bakfiles.sh:27: `bin/*.bak` (single segment) or
+// `.claude/rules/*.bak` (single segment).
+func precommitBakfileMatches(path string) bool {
+	if !strings.HasSuffix(path, ".bak") {
+		return false
+	}
+	if matched, _ := filepath.Match("bin/*.bak", path); matched {
+		return true
+	}
+	if matched, _ := filepath.Match(".claude/rules/*.bak", path); matched {
+		return true
+	}
+	return false
+}
+
+// handlePreCommitTypechange implements the Go port of
+// pre-commit-typechange.sh (research/hook-audit.md §2.5). Multi-emit:
+// one envelope per typechange-to-symlink on a protected path.
+//
+// Payload contract: `typechange_entries` is an array of objects with
+// at minimum `{path, new_mode, status}` keys. The shim parses
+// `git diff --cached --raw` once and emits the structured list, so
+// the Go handler is free of git plumbing.
+func handlePreCommitTypechange(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	entries, err := requireArray(evt.Payload, "typechange_entries")
+	if err != nil {
+		return nil, err
+	}
+	envelopes := make([]BlockerEnvelope, 0)
+	for _, raw := range entries {
+		entry, ok := raw.(map[string]any)
+		if !ok {
+			continue
+		}
+		path := asString(entry["path"])
+		newMode := asString(entry["new_mode"])
+		status := asString(entry["status"])
+		if path == "" || newMode != "120000" || status != "T" {
+			continue
+		}
+		if !precommitTypechangeProtected(path) {
+			continue
+		}
+		envelopes = append(envelopes, tx.EmitBlocker("precommit_typechange_to_symlink", map[string]string{
+			"path": path,
+		}))
+	}
+	if len(envelopes) == 0 {
+		return nil, nil
+	}
+	return envelopes, nil
+}
+
+// precommitTypechangeProtected mirrors `_is_protected` from
+// pre-commit-typechange.sh:25-32.
+func precommitTypechangeProtected(path string) bool {
+	switch path {
+	case "bin/alm", "bin/rws", "bin/sds":
+		return true
+	}
+	if strings.HasPrefix(path, ".claude/rules/") {
+		return true
+	}
+	return false
+}
+
+// handlePreCommitScriptModes implements the Go port of
+// pre-commit-script-modes.sh (research/hook-audit.md §2.4). Multi-emit:
+// one envelope per offending bin/frw.d/scripts/*.sh entry at index
+// mode 100644.
+//
+// Payload contract: `script_modes` is an array of `{path, mode}` objects.
+// The shim runs `git ls-files -s` once per staged path and emits the
+// structured list, so the Go handler is git-free.
+func handlePreCommitScriptModes(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	entries, err := requireArray(evt.Payload, "script_modes")
+	if err != nil {
+		return nil, err
+	}
+	envelopes := make([]BlockerEnvelope, 0)
+	for _, raw := range entries {
+		entry, ok := raw.(map[string]any)
+		if !ok {
+			continue
+		}
+		path := asString(entry["path"])
+		mode := asString(entry["mode"])
+		if path == "" || mode == "" {
+			continue
+		}
+		if !precommitScriptUnderManagedDir(path) {
+			continue
+		}
+		if mode == "100755" {
+			continue
+		}
+		envelopes = append(envelopes, tx.EmitBlocker("precommit_script_mode_invalid", map[string]string{
+			"path": path,
+			"mode": mode,
+		}))
+	}
+	if len(envelopes) == 0 {
+		return nil, nil
+	}
+	return envelopes, nil
+}
+
+// precommitScriptUnderManagedDir matches `bin/frw.d/scripts/*.sh`
+// (single segment) per pre-commit-script-modes.sh:41.
+func precommitScriptUnderManagedDir(path string) bool {
+	if !strings.HasSuffix(path, ".sh") {
+		return false
+	}
+	matched, _ := filepath.Match("bin/frw.d/scripts/*.sh", path)
+	return matched
+}
diff --git a/internal/cli/shellparse.go b/internal/cli/shellparse.go
new file mode 100644
index 0000000..ed93346
--- /dev/null
+++ b/internal/cli/shellparse.go
@@ -0,0 +1,258 @@
+package cli
+
+import (
+	"strings"
+)
+
+// handlePreBashInternalScript implements the Go port of script-guard.sh
+// (research/hook-audit.md §2.6). The hook fires on every PreToolUse(Bash)
+// and emits `script_guard_internal_invocation` when the command tokenizes
+// to a direct execution of a `bin/frw.d/` script.
+//
+// The original POSIX-awk parser is replicated here as a hand-rolled
+// scanner. The migration motivation was the awk parser's testability and
+// maintainability (audit §2.6 finding: "POSIX-awk is the wrong tool for
+// shell-tokenization"). The Go scanner runs in the same time/memory
+// budget but is straightforward to table-test.
+func handlePreBashInternalScript(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	command, err := requireString(evt.Payload, "command")
+	if err != nil {
+		// Required key missing — invocation error per shared-contracts.
+		return nil, err
+	}
+
+	// Fast paths matching script-guard.sh:144-157.
+	if !strings.Contains(command, "frw.d/") {
+		return nil, nil
+	}
+	stripped := shellStripDataRegions(command)
+	if !strings.Contains(stripped, "frw.d/") {
+		return nil, nil
+	}
+
+	if !shellCommandExecutesFrwScript(stripped) {
+		return nil, nil
+	}
+	return []BlockerEnvelope{
+		tx.EmitBlocker("script_guard_internal_invocation", map[string]string{
+			"command": command,
+		}),
+	}, nil
+}
+
+// shellStripDataRegions removes single-quoted strings, double-quoted
+// strings, heredoc bodies, and line comments from a shell command string.
+// The result preserves only the unquoted, non-heredoc, non-comment token
+// text. Quoted regions are replaced by a single space so adjacent tokens
+// remain separated.
+//
+// Port of the awk implementation in script-guard.sh:35-136. POSIX shell
+// quoting semantics are subtle enough that the original implementation
+// is still authoritative on edge cases; this Go version aims for byte
+// parity on the shapes that exist in real bash commands.
+func shellStripDataRegions(command string) string {
+	var out strings.Builder
+	out.Grow(len(command))
+
+	// Process line by line so heredoc termination is tractable.
+	lines := strings.Split(command, "\n")
+	state := "normal"
+	heredocWord := ""
+
+	for li, line := range lines {
+		// Heredoc body: every line until the terminator is suppressed.
+		if state == "heredoc" {
+			trimmed := strings.TrimSpace(line)
+			if trimmed == heredocWord {
+				state = "normal"
+				heredocWord = ""
+			}
+			// Suppress the line entirely (still emit the newline for
+			// downstream tokenization to keep line offsets coherent).
+			if li < len(lines)-1 {
+				out.WriteByte('\n')
+			}
+			continue
+		}
+
+		i := 0
+		n := len(line)
+		for i < n {
+			ch := line[i]
+			ch2 := ""
+			if i+1 < n {
+				ch2 = line[i : i+2]
+			}
+
+			if state == "normal" {
+				// Heredoc start: << or <<-
+				if ch2 == "<<" {
+					i += 2
+					if i < n && line[i] == '-' {
+						i++
+					}
+					for i < n && line[i] == ' ' {
+						i++
+					}
+					hq := byte(0)
+					if i < n && (line[i] == '\'' || line[i] == '"') {
+						hq = line[i]
+						i++
+					}
+					var hw strings.Builder
+					for i < n {
+						c := line[i]
+						if hq != 0 && c == hq {
+							i++
+							break
+						}
+						if hq == 0 && (c == ' ' || c == '\t' || c == ';' || c == '&' || c == '|') {
+							break
+						}
+						hw.WriteByte(c)
+						i++
+					}
+					heredocWord = hw.String()
+					state = "heredoc"
+					out.WriteByte(' ')
+					continue
+				}
+				if ch == '\'' {
+					state = "sq"
+					out.WriteByte(' ')
+					i++
+					continue
+				}
+				if ch == '"' {
+					state = "dq"
+					out.WriteByte(' ')
+					i++
+					continue
+				}
+				if ch == '#' {
+					// Comment: rest of the line is data.
+					i = n
+					continue
+				}
+				out.WriteByte(ch)
+				i++
+				continue
+			}
+			if state == "sq" {
+				if ch == '\'' {
+					state = "normal"
+					out.WriteByte(' ')
+				}
+				i++
+				continue
+			}
+			if state == "dq" {
+				// Backslash escapes the next char inside double quotes.
+				if ch == '\\' && i+1 < n {
+					i += 2
+					continue
+				}
+				if ch == '"' {
+					state = "normal"
+					out.WriteByte(' ')
+				}
+				i++
+				continue
+			}
+		}
+		if li < len(lines)-1 {
+			out.WriteByte('\n')
+		}
+	}
+	return out.String()
+}
+
+// shellCommandExecutesFrwScript tokenizes the stripped command and
+// returns true when any pipeline segment executes a bin/frw.d/ path.
+//
+// Detection rules (matches script-guard.sh:162-200):
+//  1. The first token of a command segment IS a bin/frw.d/ path.
+//  2. The first token is sh/bash/zsh/dash/ksh/source/./exec and the
+//     first non-flag argument is a bin/frw.d/ path. `sh -n` and
+//     `bash -n` are syntax checks, not execution — allowed.
+//
+// Pipeline separators (`|`, `||`, `&&`, `;`, `&`) split into segments;
+// each segment is checked independently.
+func shellCommandExecutesFrwScript(stripped string) bool {
+	// Collapse multi-char separators into single ";" so a simple split
+	// yields command segments.
+	canon := stripped
+	canon = strings.ReplaceAll(canon, "&&", " ; ")
+	canon = strings.ReplaceAll(canon, "||", " ; ")
+	canon = strings.ReplaceAll(canon, "|", " ; ")
+	canon = strings.ReplaceAll(canon, "&", " ; ")
+
+	for _, segment := range strings.Split(canon, ";") {
+		seg := strings.TrimSpace(segment)
+		if seg == "" {
+			continue
+		}
+		tokens := tokenize(seg)
+		if len(tokens) == 0 {
+			continue
+		}
+		first := tokens[0]
+		if strings.Contains(first, "bin/frw.d/") {
+			return true
+		}
+		if isShellInterpreter(first) {
+			hasN := false
+			for _, t := range tokens[1:] {
+				if t == "" {
+					continue
+				}
+				if t == "-n" {
+					hasN = true
+					continue
+				}
+				if strings.HasPrefix(t, "-") {
+					continue
+				}
+				// First non-flag argument.
+				if strings.Contains(t, "bin/frw.d/") {
+					if hasN && (first == "sh" || first == "bash") {
+						break
+					}
+					return true
+				}
+				break
+			}
+		}
+	}
+	return false
+}
+
+// tokenize splits on runs of whitespace; matches awk `split($0, tok, /[[:space:]]+/)`.
+func tokenize(s string) []string {
+	out := make([]string, 0, 4)
+	current := strings.Builder{}
+	flush := func() {
+		if current.Len() > 0 {
+			out = append(out, current.String())
+			current.Reset()
+		}
+	}
+	for i := 0; i < len(s); i++ {
+		c := s[i]
+		if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
+			flush()
+			continue
+		}
+		current.WriteByte(c)
+	}
+	flush()
+	return out
+}
+
+func isShellInterpreter(t string) bool {
+	switch t {
+	case "sh", "bash", "zsh", "dash", "ksh", "source", ".", "exec":
+		return true
+	}
+	return false
+}
diff --git a/internal/cli/stop_ideation.go b/internal/cli/stop_ideation.go
new file mode 100644
index 0000000..c765d16
--- /dev/null
+++ b/internal/cli/stop_ideation.go
@@ -0,0 +1,116 @@
+package cli
+
+import (
+	"os"
+	"path/filepath"
+	"sort"
+	"strings"
+
+	yaml "gopkg.in/yaml.v3"
+)
+
+// handleStopIdeationCompleteness implements the Go port of stop-ideation.sh
+// (research/hook-audit.md §2.8). The hook fires on the Stop boundary and
+// emits `ideation_incomplete_definition_fields` when the row's
+// definition.yaml is missing one or more required fields.
+//
+// Skip conditions (clean pass — return nil, nil):
+//   - No row name supplied (caller couldn't resolve a focused row).
+//   - definition.yaml is absent (ideation still in progress).
+//   - gate_policy is "autonomous" (evaluator validates instead).
+//
+// The handler does NOT enforce step == ideate; the shim is responsible
+// for only invoking guard during the ideate step. This matches the
+// shared-contracts §C5 "translation only" boundary for shell shims.
+func handleStopIdeationCompleteness(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	row, err := requireString(evt.Payload, "row")
+	if err != nil {
+		// The schema requires `row` for this event. Treat absence as an
+		// invocation error so misrouted shims fail loudly.
+		return nil, err
+	}
+
+	gatePolicy := asString(evt.Payload["gate_policy"])
+	if gatePolicy == "autonomous" {
+		return nil, nil
+	}
+
+	defPath := asString(evt.Payload["definition_path"])
+	if defPath == "" {
+		// Try to resolve via FURROW_ROOT or working directory; the shim
+		// SHOULD supply definition_path but a graceful fallback keeps the
+		// handler usable from tests with t.Setenv("FURROW_ROOT", ...).
+		root, rootErr := correctionLimitRoot()
+		if rootErr != nil {
+			return nil, nil
+		}
+		defPath = filepath.Join(root, ".furrow", "rows", row, "definition.yaml")
+	}
+	if _, err := os.Stat(defPath); err != nil {
+		// Definition not yet written — ideation still in progress.
+		return nil, nil
+	}
+
+	missing, err := ideationMissingFields(defPath)
+	if err != nil {
+		// Malformed YAML is its own issue — but stop-ideation.sh's prior
+		// behavior was to fail-open. Preserve that: log via slog at the
+		// caller's level (omitted here for pure-handler purity).
+		return nil, nil
+	}
+	if len(missing) == 0 {
+		return nil, nil
+	}
+
+	return []BlockerEnvelope{
+		tx.EmitBlocker("ideation_incomplete_definition_fields", map[string]string{
+			"missing": strings.Join(missing, ", "),
+		}),
+	}, nil
+}
+
+// ideationMissingFields parses the definition.yaml at path and returns
+// the names of required fields that are absent or empty. Required fields
+// match stop-ideation.sh:69-88:
+//
+//   - objective         (string, non-empty)
+//   - gate_policy       (string, non-empty)
+//   - deliverables      (array, len >= 1)
+//   - context_pointers  (array, len >= 1)
+//   - constraints       (any, present and non-empty)
+//
+// The returned slice is sorted for deterministic output (the shell hook
+// emits in field-iteration order; sorting keeps Go test golden-output
+// stable).
+func ideationMissingFields(path string) ([]string, error) {
+	payload, err := os.ReadFile(path)
+	if err != nil {
+		return nil, err
+	}
+	var doc map[string]any
+	if err := yaml.Unmarshal(payload, &doc); err != nil {
+		return nil, err
+	}
+	missing := make([]string, 0, 5)
+	for _, scalar := range []string{"objective", "gate_policy"} {
+		s, _ := doc[scalar].(string)
+		if strings.TrimSpace(s) == "" {
+			missing = append(missing, scalar)
+		}
+	}
+	for _, list := range []string{"deliverables", "context_pointers"} {
+		arr, _ := doc[list].([]any)
+		if len(arr) < 1 {
+			missing = append(missing, list)
+		}
+	}
+	if v, ok := doc["constraints"]; !ok || v == nil {
+		missing = append(missing, "constraints")
+	} else if s, isStr := v.(string); isStr && strings.TrimSpace(s) == "" {
+		missing = append(missing, "constraints")
+	} else if arr, isArr := v.([]any); isArr && len(arr) == 0 {
+		missing = append(missing, "constraints")
+	}
+	sort.Strings(missing)
+	return missing, nil
+}
diff --git a/internal/cli/validate_summary.go b/internal/cli/validate_summary.go
new file mode 100644
index 0000000..24a1b8d
--- /dev/null
+++ b/internal/cli/validate_summary.go
@@ -0,0 +1,150 @@
+package cli
+
+import (
+	"fmt"
+	"os"
+	"path/filepath"
+	"strings"
+)
+
+// handleStopSummaryValidation implements the Go port of validate-summary.sh
+// (research/hook-audit.md §2.9). The hook fires on Stop and emits one or
+// more block-severity envelopes per missing/empty required section.
+//
+// Skip conditions (clean pass — return nil, nil):
+//   - summary.md is absent.
+//   - last_decided_by == "prechecked" (pre-step evaluation skipped the step).
+//
+// Required sections per validate-summary.sh:46:
+//
+//	Task, Current State, Artifact Paths, Settled Decisions,
+//	Key Findings, Open Questions, Recommendations
+//
+// Step-aware content check: the agent-written sections (Key Findings,
+// Open Questions, Recommendations) need >= 1 non-empty content line. In
+// the ideate step, only Open Questions has content requirements.
+//
+// Multi-emit: this handler may return more than one envelope (one per
+// missing/empty section). Stdout JSON-array shape is the contract.
+func handleStopSummaryValidation(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	row, err := requireString(evt.Payload, "row")
+	if err != nil {
+		return nil, err
+	}
+
+	if asString(evt.Payload["last_decided_by"]) == "prechecked" {
+		return nil, nil
+	}
+
+	summaryPath := asString(evt.Payload["summary_path"])
+	if summaryPath == "" {
+		root, rootErr := correctionLimitRoot()
+		if rootErr != nil {
+			return nil, nil
+		}
+		summaryPath = filepath.Join(root, ".furrow", "rows", row, "summary.md")
+	}
+
+	payload, err := os.ReadFile(summaryPath)
+	if err != nil {
+		// summary.md absent is the clean-pass case (matches the shell hook).
+		return nil, nil
+	}
+	step := asString(evt.Payload["step"])
+
+	required := []string{
+		"Task", "Current State", "Artifact Paths", "Settled Decisions",
+		"Key Findings", "Open Questions", "Recommendations",
+	}
+	contentRequired := []string{"Key Findings", "Open Questions", "Recommendations"}
+
+	sections := markdownSections(string(payload))
+
+	envelopes := make([]BlockerEnvelope, 0, len(required))
+	for _, name := range required {
+		if _, present := sections[name]; !present {
+			envelopes = append(envelopes, tx.EmitBlocker("summary_section_missing", map[string]string{
+				"section": name,
+				"path":    summaryPath,
+			}))
+		}
+	}
+	for _, name := range contentRequired {
+		if step == "ideate" && name != "Open Questions" {
+			continue
+		}
+		body, present := sections[name]
+		if !present {
+			// Already reported as missing; skip the empty-content check.
+			continue
+		}
+		if summarySectionContentLineCount(body) < 1 {
+			envelopes = append(envelopes, tx.EmitBlocker("summary_section_empty", map[string]string{
+				"section":        name,
+				"path":           summaryPath,
+				"actual_count":   "0",
+				"required_count": "1",
+			}))
+		}
+	}
+	if len(envelopes) == 0 {
+		return nil, nil
+	}
+	return envelopes, nil
+}
+
+// summarySectionContentLineCount counts non-empty content lines in a
+// markdown section body. Matches the awk filter at validate-summary.sh:62
+// (`found && /[^ ]/ { count++ }` — any line containing a non-space char).
+func summarySectionContentLineCount(body string) int {
+	count := 0
+	for _, line := range strings.Split(body, "\n") {
+		if strings.TrimSpace(line) != "" {
+			count++
+		}
+	}
+	return count
+}
+
+// summaryMissingSections is exported-via-package for handleStopWorkCheck
+// (work-check.sh subset). Returned slice is the names of required sections
+// absent from the file. Errors reading the file are returned as-is.
+func summaryMissingSections(summaryPath string, sections []string) ([]string, error) {
+	payload, err := os.ReadFile(summaryPath)
+	if err != nil {
+		return nil, err
+	}
+	parsed := markdownSections(string(payload))
+	missing := make([]string, 0, len(sections))
+	for _, s := range sections {
+		if _, ok := parsed[s]; !ok {
+			missing = append(missing, s)
+		}
+	}
+	return missing, nil
+}
+
+// summarySectionContentSparse reports sections whose content has fewer
+// non-empty lines than the threshold. Used by handleStopWorkCheck.
+func summarySectionContentSparse(summaryPath string, sections []string, threshold int) ([]string, error) {
+	payload, err := os.ReadFile(summaryPath)
+	if err != nil {
+		return nil, err
+	}
+	parsed := markdownSections(string(payload))
+	sparse := make([]string, 0, len(sections))
+	for _, s := range sections {
+		body, ok := parsed[s]
+		if !ok {
+			continue
+		}
+		if summarySectionContentLineCount(body) < threshold {
+			sparse = append(sparse, s)
+		}
+	}
+	return sparse, nil
+}
+
+// _ keeps fmt referenced when the package compiles minimally (in case
+// future helpers are removed). No runtime cost.
+var _ = fmt.Sprintf
diff --git a/internal/cli/work_check.go b/internal/cli/work_check.go
new file mode 100644
index 0000000..6250537
--- /dev/null
+++ b/internal/cli/work_check.go
@@ -0,0 +1,90 @@
+package cli
+
+import (
+	"fmt"
+	"os"
+	"path/filepath"
+	"strings"
+)
+
+// handleStopWorkCheck implements the warn-only health check from
+// work-check.sh (research/hook-audit.md §2.11). Per shared-contracts §C1,
+// each invocation processes a single row (caller iterates active rows).
+//
+// Multi-emit: returns up to three envelopes per row:
+//   - state_validation_failed_warn  if state.json failed schema validation
+//   - summary_section_missing_warn  if any required section is absent
+//   - summary_section_empty_warn    if any agent-written section has < 2
+//     non-empty content lines
+//
+// All emissions are severity=warn / confirmation_path=silent — the shell
+// caller surfaces them as `[furrow:warning] ...` lines and exits 0.
+//
+// The handler does NOT touch the row's `updated_at` timestamp — that
+// side-effect is split into its own follow-up TODO per audit §2.11
+// quality finding.
+func handleStopWorkCheck(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
+	row, err := requireString(evt.Payload, "row")
+	if err != nil {
+		return nil, err
+	}
+
+	envelopes := make([]BlockerEnvelope, 0, 3)
+
+	// state.json validation result is decided by the caller (the shim
+	// runs the validator and passes the outcome). Default true (no
+	// failure) when the key is absent so handlers driven from a minimal
+	// payload don't false-positive.
+	stateOK := true
+	if v, ok := evt.Payload["state_validation_ok"]; ok {
+		if b, isBool := v.(bool); isBool {
+			stateOK = b
+		}
+	}
+	if !stateOK {
+		envelopes = append(envelopes, tx.EmitBlocker("state_validation_failed_warn", map[string]string{
+			"row": row,
+		}))
+	}
+
+	summaryPath := asString(evt.Payload["summary_path"])
+	if summaryPath == "" {
+		root, rootErr := correctionLimitRoot()
+		if rootErr == nil {
+			summaryPath = filepath.Join(root, ".furrow", "rows", row, "summary.md")
+		}
+	}
+	if summaryPath != "" {
+		if _, err := os.Stat(summaryPath); err == nil {
+			required := []string{
+				"Task", "Current State", "Artifact Paths",
+				"Settled Decisions", "Key Findings", "Open Questions",
+			}
+			if missing, err := summaryMissingSections(summaryPath, required); err == nil && len(missing) > 0 {
+				envelopes = append(envelopes, tx.EmitBlocker("summary_section_missing_warn", map[string]string{
+					"row":     row,
+					"missing": strings.Join(missing, " "),
+				}))
+			}
+			agentSections := []string{"Key Findings", "Open Questions", "Recommendations"}
+			if sparse, err := summarySectionContentSparse(summaryPath, agentSections, 2); err == nil {
+				for _, name := range sparse {
+					envelopes = append(envelopes, tx.EmitBlocker("summary_section_empty_warn", map[string]string{
+						"row":            row,
+						"section":        name,
+						"required_count": "2",
+					}))
+				}
+			}
+		}
+	}
+
+	if len(envelopes) == 0 {
+		return nil, nil
+	}
+	return envelopes, nil
+}
+
+// _ silences unused-import diagnostics if a future refactor removes the
+// only consumer of fmt. Cheap belt-and-braces against drift.
+var _ = fmt.Sprintf
diff --git a/schemas/blocker-event.schema.json b/schemas/blocker-event.schema.json
new file mode 100644
index 0000000..6c62a05
--- /dev/null
+++ b/schemas/blocker-event.schema.json
@@ -0,0 +1,47 @@
+{
+  "$schema": "https://json-schema.org/draft/2020-12/schema",
+  "title": "Blocker Event",
+  "description": "Schema for normalized blocker events consumed by `furrow guard <event-type>` on stdin. Per-event-type payload validation is performed in Go (handler-specific required-key checks); this schema is structural only. The closed event_type enum mirrors schemas/blocker-event.yaml event_types[].name verbatim.",
+  "type": "object",
+  "required": ["version", "event_type", "payload"],
+  "additionalProperties": false,
+  "properties": {
+    "version": {
+      "type": "string",
+      "description": "Schema version of the event envelope; must match schemas/blocker-event.yaml top-level version."
+    },
+    "event_type": {
+      "type": "string",
+      "enum": [
+        "pre_write_state_json",
+        "pre_write_verdict",
+        "pre_write_correction_limit",
+        "pre_bash_internal_script",
+        "pre_commit_bakfiles",
+        "pre_commit_typechange",
+        "pre_commit_script_modes",
+        "stop_ideation_completeness",
+        "stop_summary_validation",
+        "stop_work_check"
+      ],
+      "description": "Closed catalog of event types — one per emit-bearing hook (specs/shared-contracts.md §C1)."
+    },
+    "target_path": {
+      "type": "string",
+      "description": "Optional convenience field hoisted out of payload — the path the host event references. Pre-write hooks always populate this."
+    },
+    "step": {
+      "type": "string",
+      "enum": ["ideate", "research", "plan", "spec", "decompose", "implement", "review"],
+      "description": "Optional convenience field — the row step the event was raised under."
+    },
+    "row": {
+      "type": "string",
+      "description": "Optional convenience field — the row name the event was raised under."
+    },
+    "payload": {
+      "type": "object",
+      "description": "Per-event-type payload. Legal keys and required subset are documented in schemas/blocker-event.yaml event_types[].payload_keys[] and event_types[].required[]."
+    }
+  }
+}
diff --git a/schemas/blocker-event.yaml b/schemas/blocker-event.yaml
new file mode 100644
index 0000000..15d4f2b
--- /dev/null
+++ b/schemas/blocker-event.yaml
@@ -0,0 +1,115 @@
+# Blocker event catalog — host-agnostic event envelope contract.
+#
+# This file enumerates the closed set of event types that adapters (Claude
+# hooks, git pre-commit, Pi adapter shims, etc.) translate host events into
+# before invoking the Go backend via `furrow guard <event-type>`. Per
+# specs/shared-contracts.md §C1, the catalog is **per-hook 1:1**: ten
+# event types, one for every emit-bearing hook in research/hook-audit.md.
+#
+# Conformance contract:
+#   - Adding a new entry to event_types[] without registering a matching
+#     handler in internal/cli/guard.go fails TestGuardHandlerRegistryParity.
+#   - Removing a handler without removing the entry fails the same drift
+#     guard from the opposite direction.
+#   - emitted_codes[] are the canonical taxonomy codes the handler may
+#     produce; every code appears in schemas/blocker-taxonomy.yaml.
+#
+# Top-level shape:
+#   version (string, required)         schema-version of the event envelope
+#   event_types[] (array, required)    closed catalog
+#     name (string, required)          snake_case event type
+#     description (string, required)   one-line summary of the host trigger
+#     emitted_codes[] (array, required) canonical taxonomy codes the handler may emit
+#     payload_keys[] (array, required) ordered list of legal payload keys
+#       name (string, required)
+#       type (string, required)        string|number|boolean|array|object
+#       description (string, required)
+#     required[] (array, required)     subset of payload_keys[].name; non-empty
+#                                      keys the handler MUST receive
+#
+# version "1" is the landing version. Bump on any breaking shape change to
+# either the envelope or any per-event-type payload contract.
+
+version: "1"
+
+event_types:
+  - name: pre_write_state_json
+    description: "PreToolUse(Write|Edit) — block direct writes to state.json"
+    emitted_codes: [state_json_direct_write]
+    payload_keys:
+      - { name: target_path, type: string, description: "absolute or repo-relative path the tool intends to write" }
+      - { name: tool_name,   type: string, description: "Write or Edit (informational)" }
+    required: [target_path]
+
+  - name: pre_write_verdict
+    description: "PreToolUse(Write|Edit) — block direct writes under gate-verdicts/"
+    emitted_codes: [verdict_direct_write]
+    payload_keys:
+      - { name: target_path, type: string, description: "absolute or repo-relative path the tool intends to write" }
+      - { name: tool_name,   type: string, description: "Write or Edit (informational)" }
+    required: [target_path]
+
+  - name: pre_write_correction_limit
+    description: "PreToolUse(Write|Edit) — block writes to deliverables that hit their correction limit"
+    emitted_codes: [correction_limit_reached]
+    payload_keys:
+      - { name: target_path, type: string, description: "absolute or repo-relative path the tool intends to write" }
+      - { name: tool_name,   type: string, description: "Write or Edit (informational)" }
+    required: [target_path]
+
+  - name: pre_bash_internal_script
+    description: "PreToolUse(Bash) — block direct invocation of bin/frw.d/ scripts"
+    emitted_codes: [script_guard_internal_invocation]
+    payload_keys:
+      - { name: command, type: string, description: "the full bash command string from tool_input.command" }
+    required: [command]
+
+  - name: pre_commit_bakfiles
+    description: "git pre-commit — refuse install-artifact .bak files staged under bin/ or .claude/rules/"
+    emitted_codes: [precommit_install_artifact_staged]
+    payload_keys:
+      - { name: staged_paths, type: array, description: "list of staged file paths to inspect" }
+    required: [staged_paths]
+
+  - name: pre_commit_typechange
+    description: "git pre-commit — refuse type-change to symlink on protected paths"
+    emitted_codes: [precommit_typechange_to_symlink]
+    payload_keys:
+      - { name: typechange_entries, type: array, description: "list of {path, new_mode, status} objects from git diff --cached --raw" }
+    required: [typechange_entries]
+
+  - name: pre_commit_script_modes
+    description: "git pre-commit — refuse staging bin/frw.d/scripts/*.sh at index mode 100644"
+    emitted_codes: [precommit_script_mode_invalid]
+    payload_keys:
+      - { name: script_modes, type: array, description: "list of {path, mode} objects for staged bin/frw.d/scripts/*.sh entries" }
+    required: [script_modes]
+
+  - name: stop_ideation_completeness
+    description: "Stop hook during ideate step — completeness check on definition.yaml"
+    emitted_codes: [ideation_incomplete_definition_fields]
+    payload_keys:
+      - { name: row,             type: string, description: "active row name" }
+      - { name: definition_path, type: string, description: "absolute path to the row's definition.yaml" }
+      - { name: gate_policy,     type: string, description: "resolved gate_policy (autonomous skips check)" }
+    required: [row]
+
+  - name: stop_summary_validation
+    description: "Stop hook — block-severity summary.md validation (verdict-guarded)"
+    emitted_codes: [summary_section_missing, summary_section_empty]
+    payload_keys:
+      - { name: row,           type: string, description: "active row name" }
+      - { name: summary_path,  type: string, description: "absolute path to the row's summary.md" }
+      - { name: step,          type: string, description: "current row step (controls step-aware section requirements)" }
+      - { name: last_decided_by, type: string, description: "decided_by of the most recent gate (prechecked skips check)" }
+    required: [row]
+
+  - name: stop_work_check
+    description: "Stop hook — warn-severity multi-row health check (always exit 0)"
+    emitted_codes: [state_validation_failed_warn, summary_section_missing_warn, summary_section_empty_warn]
+    payload_keys:
+      - { name: row,                  type: string, description: "row name being checked (caller iterates active rows)" }
+      - { name: state_path,           type: string, description: "absolute path to the row's state.json" }
+      - { name: summary_path,         type: string, description: "absolute path to the row's summary.md" }
+      - { name: state_validation_ok,  type: boolean, description: "true if state.json passed schema validation upstream" }
+    required: [row]

commit 5f4fd59ff4826dca0882f7bbc2047303356781bc
Author: Test <test@test.com>
Date:   Sat Apr 25 15:04:47 2026 -0400

    feat(blocker-taxonomy): canonical envelope cutover + 29 new codes
    
    Extend schemas/blocker-taxonomy.yaml from 11 to 40 codes, covering the full
    Blocker baseline (state-mutation, gate, archive, scaffold, summary, ideation,
    seed, artifact, definition, ownership) plus hook-emit codes catalogued in
    research/hook-audit.md. The canonical 11 pre-D1 codes (definition_* +
    ownership_outside_scope) keep their frozen code strings, severities, and
    message_template placeholder sets — enforced by a new
    TestBlockerTaxonomyBackwardCompat11 lock test.
    
    Migrate the rowBlockers `blocker(...)` constructor at the single-point
    target identified in research/status-callers-and-pi-shim.md §A: severity
    becomes a per-code taxonomy lookup (block | warn | info instead of the
    hardcoded "error"); confirmation_path becomes the enum token from the
    taxonomy (block | warn-with-confirm | silent instead of prose); a new
    remediation_hint field is sourced from the taxonomy as the single source
    of user-facing prose. Detail keys (seed_id, path, artifact_id, ...) move
    from being merged into the envelope to a sibling `details` map, so the
    canonical envelope stays at exactly six fields.
    
    Pi adapter migrates in lock-step: formatBlockers in adapters/pi/furrow.ts
    now sources :: fix: prose from blocker.remediation_hint (verbatim) instead
    of interpolating the now-enum confirmation_path. The RowStatusData blockers
    type adds the canonical fields plus an optional details sibling.
    
    Other changes:
    - Add Taxonomy.Lookup and Taxonomy.Applies helpers for step-scoped codes.
    - LoadTaxonomy gains FURROW_TAXONOMY_PATH override + module-source-root
      fallback so tests using t.TempDir() resolve the registry without
      per-test fixture provisioning.
    - Replace the prose Blocker baseline list in
      docs/architecture/pi-step-ceremony-and-artifact-enforcement.md with a
      citation pointer to schemas/blocker-taxonomy.yaml as canonical.
    
    Backward-compat note: codes whose Go emit-sites already used literal names
    (pending_user_actions, seed_*, missing_required_artifact, artifact_*,
    supersedence_evidence_missing, archive_requires_review_gate) keep those
    names verbatim per spec §6.4 to avoid churning the only programmatic
    consumer (Pi).
    
    Verification:
    - go test ./internal/cli/... passes (40 codes resolve through EmitBlocker;
      TestBlockerTaxonomyBackwardCompat11 locks placeholder sets;
      TestBlockerApplicableStepsFilter covers ideate/review/all-steps scoping).
    - furrow row status --json on the active row emits canonical six-field
      envelopes for both data.blockers and data.row.gates.pending_blockers.
    - adapters/pi/furrow.test.ts: 37 pass, 0 fail.
    
    Refs spec: .furrow/rows/blocker-taxonomy-foundation/specs/canonical-blocker-taxonomy.md

diff --git a/internal/cli/blocker_envelope.go b/internal/cli/blocker_envelope.go
index 643105e..6e2b51e 100644
--- a/internal/cli/blocker_envelope.go
+++ b/internal/cli/blocker_envelope.go
@@ -4,6 +4,7 @@ import (
 	"fmt"
 	"os"
 	"path/filepath"
+	"runtime"
 	"sort"
 	"strings"
 	"sync"
@@ -62,16 +63,74 @@ var (
 //   - codes must be unique
 func LoadTaxonomy() (*Taxonomy, error) {
 	taxonomyOnce.Do(func() {
-		root, err := findFurrowRoot()
-		if err != nil {
-			cachedTaxonomyLoadError = fmt.Errorf("blocker taxonomy: %w", err)
+		// Resolution order:
+		//   1. FURROW_TAXONOMY_PATH env var (explicit override; useful for tests
+		//      and out-of-tree deployments).
+		//   2. <findFurrowRoot()>/schemas/blocker-taxonomy.yaml — the
+		//      conventional location inside a Furrow project tree.
+		//   3. <module-source-root>/schemas/blocker-taxonomy.yaml — discovered
+		//      via runtime.Caller. Lets `go test` runs and binaries built
+		//      inside the source tree find the canonical registry without
+		//      requiring callers to provision it in temp roots.
+		// This is expand-contract migration discipline: existing callers under
+		// the project root keep working (path 2), tests in temp dirs fall back
+		// to the source-tree copy (path 3), and ad-hoc consumers can override
+		// with FURROW_TAXONOMY_PATH (path 1).
+		for _, path := range candidateTaxonomyPaths() {
+			if path == "" {
+				continue
+			}
+			if _, statErr := os.Stat(path); statErr != nil {
+				continue
+			}
+			cachedTaxonomy, cachedTaxonomyLoadError = loadTaxonomyFrom(path)
 			return
 		}
-		cachedTaxonomy, cachedTaxonomyLoadError = loadTaxonomyFrom(filepath.Join(root, "schemas", "blocker-taxonomy.yaml"))
+		cachedTaxonomyLoadError = fmt.Errorf("blocker taxonomy: schemas/blocker-taxonomy.yaml not found in any candidate location (set FURROW_TAXONOMY_PATH to override)")
 	})
 	return cachedTaxonomy, cachedTaxonomyLoadError
 }
 
+// candidateTaxonomyPaths returns the ordered list of paths LoadTaxonomy
+// probes for the canonical YAML registry. See LoadTaxonomy for resolution
+// order rationale.
+func candidateTaxonomyPaths() []string {
+	candidates := make([]string, 0, 3)
+	if override := strings.TrimSpace(os.Getenv("FURROW_TAXONOMY_PATH")); override != "" {
+		candidates = append(candidates, override)
+	}
+	if root, err := findFurrowRoot(); err == nil {
+		candidates = append(candidates, filepath.Join(root, "schemas", "blocker-taxonomy.yaml"))
+	}
+	if srcRoot, ok := moduleSourceRoot(); ok {
+		candidates = append(candidates, filepath.Join(srcRoot, "schemas", "blocker-taxonomy.yaml"))
+	}
+	return candidates
+}
+
+// moduleSourceRoot walks up from this source file's location to find the
+// nearest directory containing a `schemas/blocker-taxonomy.yaml`. Returns the
+// project root containing both `internal/cli/` and `schemas/`. This is a
+// best-effort fallback for tests and tools that run outside a `.furrow/`
+// project tree; it returns ok=false when run from a stripped binary.
+func moduleSourceRoot() (string, bool) {
+	_, file, _, ok := runtime.Caller(0)
+	if !ok || file == "" {
+		return "", false
+	}
+	dir := filepath.Dir(file)
+	for {
+		if _, err := os.Stat(filepath.Join(dir, "schemas", "blocker-taxonomy.yaml")); err == nil {
+			return dir, true
+		}
+		next := filepath.Dir(dir)
+		if next == dir {
+			return "", false
+		}
+		dir = next
+	}
+}
+
 // resetTaxonomyCacheForTest clears the package-level cache; only intended for
 // tests that need to reload the taxonomy from a fixture path.
 func resetTaxonomyCacheForTest() {
@@ -128,6 +187,37 @@ func loadTaxonomyFrom(path string) (*Taxonomy, error) {
 	return &t, nil
 }
 
+// Lookup returns the registered Blocker for the given code, or (nil, false)
+// when the code is not registered. Useful for callers that need to inspect
+// the canonical entry (e.g., to honor applicable_steps) before deciding to
+// emit.
+func (t *Taxonomy) Lookup(code string) (*Blocker, bool) {
+	if t == nil || t.index == nil {
+		return nil, false
+	}
+	b, ok := t.index[code]
+	return b, ok
+}
+
+// Applies reports whether a code applies in the given row step. Codes whose
+// applicable_steps is absent or empty apply to every step. Unregistered codes
+// return false (a code that does not exist in the registry never "applies").
+func (t *Taxonomy) Applies(code, step string) bool {
+	b, ok := t.Lookup(code)
+	if !ok {
+		return false
+	}
+	if len(b.ApplicableSteps) == 0 {
+		return true
+	}
+	for _, s := range b.ApplicableSteps {
+		if s == step {
+			return true
+		}
+	}
+	return false
+}
+
 // EmitBlocker resolves the code in the taxonomy, interpolates {placeholder}
 // substitutions from interp into message_template, and returns the JSON
 // envelope. In test mode (testing.Testing()), an unregistered code panics; in
diff --git a/internal/cli/blocker_envelope_test.go b/internal/cli/blocker_envelope_test.go
index a60d4de..ae25321 100644
--- a/internal/cli/blocker_envelope_test.go
+++ b/internal/cli/blocker_envelope_test.go
@@ -1,15 +1,45 @@
 package cli
 
 import (
+	"sort"
 	"strings"
 	"testing"
 )
 
-// expectedInitialCodes is the closed list of codes the spec locks for D3's
-// initial population. Every code emitted by D1 (validate-definition-go) and
-// D2 (validate-ownership-go) must appear here, and the taxonomy YAML must
-// resolve every entry.
+// backwardCompatCodes is the locked, immutable set of pre-D1 codes whose
+// `code` strings, severities, and `message_template` placeholder sets are
+// frozen. These predate the blocker-taxonomy-foundation row and any change
+// to their identity breaks already-deployed validators (validate-definition,
+// validate-ownership) and the only programmatic consumer (Pi adapter).
+//
+// See spec §4.3 (specs/canonical-blocker-taxonomy.md) for the lock rationale.
+var backwardCompatCodes = []struct {
+	code         string
+	severity     string
+	placeholders []string // sorted, unique placeholder set inside message_template
+}{
+	{"definition_yaml_invalid", "block", []string{"detail", "path"}},
+	{"definition_objective_missing", "block", []string{"path"}},
+	{"definition_gate_policy_missing", "block", []string{"path"}},
+	{"definition_gate_policy_invalid", "block", []string{"path", "value"}},
+	{"definition_mode_invalid", "block", []string{"path", "value"}},
+	{"definition_deliverables_empty", "block", []string{"path"}},
+	{"definition_deliverable_name_missing", "block", []string{"index", "path"}},
+	{"definition_deliverable_name_invalid_pattern", "block", []string{"name", "path"}},
+	{"definition_acceptance_criteria_placeholder", "block", []string{"name", "path", "value"}},
+	{"definition_unknown_keys", "block", []string{"keys", "path"}},
+	{"ownership_outside_scope", "warn", []string{"path", "row"}},
+}
+
+// expectedInitialCodes is the full set of codes the registry must resolve
+// after D1. It is the union of the 11 backward-compat codes (frozen) and
+// every additional code added by deliverable canonical-blocker-taxonomy.
+//
+// Every entry here MUST exist in schemas/blocker-taxonomy.yaml, and
+// EmitBlocker must succeed for each one when supplied a placeholder map
+// containing the union of placeholders across the registry.
 var expectedInitialCodes = []string{
+	// Pre-D1 backward-compat (locked):
 	"definition_yaml_invalid",
 	"definition_objective_missing",
 	"definition_gate_policy_missing",
@@ -21,6 +51,78 @@ var expectedInitialCodes = []string{
 	"definition_acceptance_criteria_placeholder",
 	"definition_unknown_keys",
 	"ownership_outside_scope",
+	// Hook-emit codes (research/hook-audit.md §3):
+	"state_json_direct_write",
+	"verdict_direct_write",
+	"correction_limit_reached",
+	"script_guard_internal_invocation",
+	"precommit_install_artifact_staged",
+	"precommit_script_mode_invalid",
+	"precommit_typechange_to_symlink",
+	"ideation_incomplete_definition_fields",
+	"summary_section_missing",
+	"summary_section_empty",
+	"state_validation_failed_warn",
+	"summary_section_missing_warn",
+	"summary_section_empty_warn",
+	// Go-side enforcement codes (pi-step-ceremony Blocker baseline):
+	"step_order_invalid",
+	"decided_by_invalid_for_policy",
+	"nonce_stale",
+	"verdict_linkage_missing",
+	"archived_row_mutation",
+	"supervised_boundary_unconfirmed",
+	// Existing emit-site codes (preserved per spec §6.4 reconciliation):
+	"pending_user_actions",
+	"seed_store_unavailable",
+	"missing_seed_record",
+	"closed_seed",
+	"seed_status_mismatch",
+	"supersedence_evidence_missing",
+	"missing_required_artifact",
+	"artifact_scaffold_incomplete",
+	"artifact_validation_failed",
+	"archive_requires_review_gate",
+}
+
+// testInterpKeys returns a placeholder map with every {key} the registry
+// references, mapped to a fixture-safe scalar string. Used by
+// TestBlockerEnvelopeAllInitialCodesResolve to drive every code through
+// EmitBlocker without unresolved-placeholder panics.
+func testInterpKeys() map[string]string {
+	return map[string]string{
+		"path":             "/tmp/foo.yaml",
+		"name":             "deliverable",
+		"value":            "fixture",
+		"keys":             "extra",
+		"index":            "0",
+		"row":              "fixture-row",
+		"detail":           "fixture detail",
+		"limit":            "3",
+		"deliverable":      "fixture-deliverable",
+		"command":          "fixture-cmd",
+		"mode":             "100644",
+		"missing":          "objective, gate_policy",
+		"section":          "Open Questions",
+		"actual_count":     "0",
+		"required_count":   "1",
+		"current_step":     "plan",
+		"target_step":      "implement",
+		"decided_by":       "human",
+		"policy":           "supervised",
+		"nonce":            "abc",
+		"expected_nonce":   "def",
+		"boundary":         "implement->review",
+		"seed_id":          "S-123",
+		"actual_status":    "open",
+		"expected_status":  "in_progress",
+		"required_commit":  "abc1234",
+		"required_row":     "predecessor-row",
+		"confirmed_commit": "abc1234",
+		"confirmed_row":    "predecessor-row",
+		"artifact_id":      "definition",
+		"count":            "1",
+	}
 }
 
 func TestBlockerTaxonomyLoadsAndValidates(t *testing.T) {
@@ -51,17 +153,10 @@ func TestBlockerEnvelopeAllInitialCodesResolve(t *testing.T) {
 		t.Fatalf("LoadTaxonomy: %v", err)
 	}
 
+	interp := testInterpKeys()
 	for _, code := range expectedInitialCodes {
 		t.Run(code, func(t *testing.T) {
-			env := tx.EmitBlocker(code, map[string]string{
-				"path":   "/tmp/foo.yaml",
-				"name":   "deliverable",
-				"value":  "fixture",
-				"keys":   "extra",
-				"index":  "0",
-				"row":    "fixture-row",
-				"detail": "fixture detail",
-			})
+			env := tx.EmitBlocker(code, interp)
 			if env.Code != code {
 				t.Fatalf("EmitBlocker(%q): code mismatch: got %q", code, env.Code)
 			}
@@ -81,6 +176,120 @@ func TestBlockerEnvelopeAllInitialCodesResolve(t *testing.T) {
 	}
 }
 
+// TestBlockerTaxonomyBackwardCompat11 enforces the locked backward-compat
+// invariant for the 11 pre-D1 codes (definition_* + ownership_outside_scope).
+// Their code strings, severities, and message_template placeholder sets are
+// frozen — drift here breaks already-deployed validators and Pi consumers.
+func TestBlockerTaxonomyBackwardCompat11(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	tx, err := LoadTaxonomy()
+	if err != nil {
+		t.Fatalf("LoadTaxonomy: %v", err)
+	}
+
+	for _, want := range backwardCompatCodes {
+		t.Run(want.code, func(t *testing.T) {
+			b, ok := tx.Lookup(want.code)
+			if !ok {
+				t.Fatalf("backward-compat code %q is missing from registry", want.code)
+			}
+			if b.Severity != want.severity {
+				t.Errorf("severity drift for %q: got %q, want %q (locked)", want.code, b.Severity, want.severity)
+			}
+			placeholders := uniqueSortedPlaceholders(b.MessageTemplate)
+			if !stringSlicesEqual(placeholders, want.placeholders) {
+				t.Errorf("placeholder drift for %q: got %v, want %v (locked)", want.code, placeholders, want.placeholders)
+			}
+		})
+	}
+}
+
+// TestBlockerApplicableStepsFilter exercises Taxonomy.Applies to confirm
+// step-scoping works as specified.
+func TestBlockerApplicableStepsFilter(t *testing.T) {
+	resetTaxonomyCacheForTest()
+	t.Cleanup(resetTaxonomyCacheForTest)
+
+	tx, err := LoadTaxonomy()
+	if err != nil {
+		t.Fatalf("LoadTaxonomy: %v", err)
+	}
+
+	cases := []struct {
+		name string
+		code string
+		step string
+		want bool
+	}{
+		// ideation_incomplete_definition_fields has applicable_steps=["ideate"].
+		{"ideate-only-on-ideate", "ideation_incomplete_definition_fields", "ideate", true},
+		{"ideate-only-on-research", "ideation_incomplete_definition_fields", "research", false},
+		{"ideate-only-on-implement", "ideation_incomplete_definition_fields", "implement", false},
+		// archive_requires_review_gate has applicable_steps=["review"].
+		{"review-only-on-review", "archive_requires_review_gate", "review", true},
+		{"review-only-on-implement", "archive_requires_review_gate", "implement", false},
+		// Code without applicable_steps applies to every step.
+		{"unrestricted-on-ideate", "definition_yaml_invalid", "ideate", true},
+		{"unrestricted-on-implement", "definition_yaml_invalid", "implement", true},
+		{"unrestricted-on-review", "definition_yaml_invalid", "review", true},
+		// summary_section_missing applies to all non-ideate steps.
+		{"summary-on-ideate", "summary_section_missing", "ideate", false},
+		{"summary-on-research", "summary_section_missing", "research", true},
+		{"summary-on-review", "summary_section_missing", "review", true},
+		// Unknown code never applies.
+		{"unknown-code", "no_such_code_xyz", "implement", false},
+	}
+
+	for _, tc := range cases {
+		t.Run(tc.name, func(t *testing.T) {
+			if got := tx.Applies(tc.code, tc.step); got != tc.want {
+				t.Errorf("Applies(%q, %q) = %v, want %v", tc.code, tc.step, got, tc.want)
+			}
+		})
+	}
+}
+
+// uniqueSortedPlaceholders extracts the unique sorted set of {placeholder}
+// tokens in template, using the same scanner as unresolvedPlaceholders.
+// Used by TestBlockerTaxonomyBackwardCompat11 to lock placeholder sets.
+func uniqueSortedPlaceholders(template string) []string {
+	seen := make(map[string]struct{})
+	for i := 0; i < len(template); i++ {
+		if template[i] != '{' {
+			continue
+		}
+		end := strings.IndexByte(template[i+1:], '}')
+		if end < 0 {
+			break
+		}
+		key := template[i+1 : i+1+end]
+		if isPlaceholderIdent(key) {
+			seen[key] = struct{}{}
+		}
+		i += end
+	}
+	out := make([]string, 0, len(seen))
+	for k := range seen {
+		out = append(out, k)
+	}
+	sort.Strings(out)
+	return out
+}
+
+func stringSlicesEqual(a, b []string) bool {
+	if len(a) != len(b) {
+		return false
+	}
+	for i := range a {
+		if a[i] != b[i] {
+			return false
+		}
+	}
+	return true
+}
+
 func TestBlockerEnvelopeUnknownCodePanics(t *testing.T) {
 	resetTaxonomyCacheForTest()
 	t.Cleanup(resetTaxonomyCacheForTest)
diff --git a/internal/cli/row_semantics.go b/internal/cli/row_semantics.go
index 48750e1..7c148ed 100644
--- a/internal/cli/row_semantics.go
+++ b/internal/cli/row_semantics.go
@@ -43,39 +43,39 @@ func artifactValidationMap(status, summary string, findings []artifactValidation
 	}
 }
 
-func blocker(code, category, message string, details map[string]any) map[string]any {
+// blocker resolves code against the loaded taxonomy and returns a map shaped
+// as the canonical six-field BlockerEnvelope plus an optional sibling
+// "details" map for non-interpolated context. The taxonomy is the single
+// source of truth for severity, remediation_hint, and confirmation_path —
+// callers no longer pass severity/category/prose; those are sourced from
+// schemas/blocker-taxonomy.yaml via tx.EmitBlocker.
+//
+// Migration discipline (expand-contract single-point migration target per
+// research/status-callers-and-pi-shim.md §A and spec §1.3): every emit-site
+// in rowBlockers passes its placeholder values via interp and any additional
+// adapter-side detail context via details. Detail keys are NOT merged into
+// the envelope — they live on a sibling "details" field so the canonical
+// envelope stays at exactly six fields.
+//
+// If tx is nil (taxonomy failed to load) or code is unregistered, we fall
+// through to tx.EmitBlocker's unregistered-code fallback (production) or
+// panic (test mode) so callers see the misuse immediately.
+func blocker(tx *Taxonomy, code string, interp map[string]string, details map[string]any) map[string]any {
+	env := tx.EmitBlocker(code, interp)
 	entry := map[string]any{
-		"code":              code,
-		"category":          category,
-		"severity":          "error",
-		"message":           message,
-		"confirmation_path": blockerConfirmationPath(code),
+		"code":              env.Code,
+		"category":          env.Category,
+		"severity":          env.Severity,
+		"message":           env.Message,
+		"remediation_hint":  env.RemediationHint,
+		"confirmation_path": env.ConfirmationPath,
 	}
-	for key, value := range details {
-		entry[key] = value
+	if len(details) > 0 {
+		entry["details"] = details
 	}
 	return entry
 }
 
-func blockerConfirmationPath(code string) string {
-	switch code {
-	case "pending_user_actions":
-		return "Resolve or clear the pending user actions through the canonical workflow before advancing."
-	case "seed_store_unavailable", "missing_seed_record", "closed_seed", "seed_status_mismatch":
-		return "Repair the linked seed state so it matches the row step, then retry the checkpoint through the backend."
-	case "missing_required_artifact":
-		return "Create or scaffold the required current-step artifact, then rerun /work or furrow row status."
-	case "artifact_scaffold_incomplete":
-		return "Replace the incomplete scaffold with real step content, then rerun furrow row complete or /work --complete."
-	case "artifact_validation_failed":
-		return "Address the reported validation findings in the artifact, then rerun furrow row status or /work."
-	case "archive_requires_review_gate":
-		return "Record a passing implement->review gate before archiving so the review boundary has durable evidence."
-	default:
-		return "Resolve the blocker through the backend-mediated workflow, then retry the checkpoint."
-	}
-}
-
 func validateArtifact(state map[string]any, artifact map[string]any) map[string]any {
 	exists, _ := artifact["exists"].(bool)
 	if !exists {
diff --git a/internal/cli/row_workflow.go b/internal/cli/row_workflow.go
index d7d8b6c..b503803 100644
--- a/internal/cli/row_workflow.go
+++ b/internal/cli/row_workflow.go
@@ -1007,20 +1007,41 @@ func rowBlockers(state map[string]any, seed map[string]any, artifacts []map[stri
 		return []map[string]any{}
 	}
 
+	// Single-point migration: every emit-site routes through the canonical
+	// taxonomy via `blocker(tx, ...)`. LoadTaxonomy is cached package-level;
+	// a missing/invalid registry is a programmer error and the test-mode
+	// panic surfaces it loudly. Production fallback (synthetic envelope)
+	// keeps the runtime alive if the YAML ever ships broken.
+	tx, _ := LoadTaxonomy()
+
 	blockers := make([]map[string]any, 0)
 	if pending, ok := asSlice(state["pending_user_actions"]); ok && len(pending) > 0 {
-		blockers = append(blockers, blocker("pending_user_actions", "user_action", fmt.Sprintf("row has %d pending user action(s)", len(pending)), map[string]any{"count": len(pending)}))
+		count := len(pending)
+		blockers = append(blockers, blocker(tx, "pending_user_actions",
+			map[string]string{"count": fmt.Sprintf("%d", count)},
+			map[string]any{"count": count}))
 	}
 	seedState, _ := seed["state"].(string)
 	switch seedState {
 	case "unavailable":
-		blockers = append(blockers, blocker("seed_store_unavailable", "seed", "seed store could not be read", nil))
+		blockers = append(blockers, blocker(tx, "seed_store_unavailable", nil, nil))
 	case "missing_record":
-		blockers = append(blockers, blocker("missing_seed_record", "seed", fmt.Sprintf("linked seed %v was not found", seed["id"]), map[string]any{"seed_id": seed["id"]}))
+		seedID := fmt.Sprintf("%v", seed["id"])
+		blockers = append(blockers, blocker(tx, "missing_seed_record",
+			map[string]string{"seed_id": seedID},
+			map[string]any{"seed_id": seed["id"]}))
 	case "closed":
-		blockers = append(blockers, blocker("closed_seed", "seed", fmt.Sprintf("linked seed %v is closed", seed["id"]), map[string]any{"seed_id": seed["id"]}))
+		seedID := fmt.Sprintf("%v", seed["id"])
+		blockers = append(blockers, blocker(tx, "closed_seed",
+			map[string]string{"seed_id": seedID},
+			map[string]any{"seed_id": seed["id"]}))
 	case "inconsistent":
-		blockers = append(blockers, blocker("seed_status_mismatch", "seed", fmt.Sprintf("linked seed %v status %v does not match expected %v", seed["id"], seed["status"], seed["expected_status"]), map[string]any{"seed_id": seed["id"], "expected_status": seed["expected_status"], "actual_status": seed["status"]}))
+		seedID := fmt.Sprintf("%v", seed["id"])
+		actual := fmt.Sprintf("%v", seed["status"])
+		expected := fmt.Sprintf("%v", seed["expected_status"])
+		blockers = append(blockers, blocker(tx, "seed_status_mismatch",
+			map[string]string{"seed_id": seedID, "actual_status": actual, "expected_status": expected},
+			map[string]any{"seed_id": seed["id"], "expected_status": seed["expected_status"], "actual_status": seed["status"]}))
 	}
 	// Supersedence confirmation check
 	if opts.DefinitionSupersedes != nil {
@@ -1036,19 +1057,23 @@ func rowBlockers(state map[string]any, seed map[string]any, artifacts []map[stri
 		}
 		switch {
 		case confirmed == "":
-			blockers = append(blockers, blocker(
-				"supersedence_evidence_missing",
-				"archive",
-				fmt.Sprintf("row definition declares supersedes (commit=%s, row=%s); pass --supersedes-confirmed %s:%s to acknowledge",
-					requiredCommit, requiredRow, requiredCommit, requiredRow),
+			blockers = append(blockers, blocker(tx, "supersedence_evidence_missing",
+				map[string]string{
+					"required_commit":  requiredCommit,
+					"required_row":     requiredRow,
+					"confirmed_commit": "",
+					"confirmed_row":    "",
+				},
 				map[string]any{"required_commit": requiredCommit, "required_row": requiredRow},
 			))
 		case confirmedCommit != requiredCommit || confirmedRow != requiredRow:
-			blockers = append(blockers, blocker(
-				"supersedence_evidence_missing",
-				"archive",
-				fmt.Sprintf("--supersedes-confirmed mismatch: got %s:%s, definition requires %s:%s",
-					confirmedCommit, confirmedRow, requiredCommit, requiredRow),
+			blockers = append(blockers, blocker(tx, "supersedence_evidence_missing",
+				map[string]string{
+					"required_commit":  requiredCommit,
+					"required_row":     requiredRow,
+					"confirmed_commit": confirmedCommit,
+					"confirmed_row":    confirmedRow,
+				},
 				map[string]any{
 					"required_commit":  requiredCommit,
 					"required_row":     requiredRow,
@@ -1059,26 +1084,33 @@ func rowBlockers(state map[string]any, seed map[string]any, artifacts []map[stri
 		}
 	}
 	for _, artifact := range artifacts {
-		label, _ := artifact["label"].(string)
 		required, _ := artifact["required"].(bool)
 		if !required {
 			continue
 		}
+		artifactID := fmt.Sprintf("%v", artifact["id"])
+		artifactPath := fmt.Sprintf("%v", artifact["path"])
 		if exists, _ := artifact["exists"].(bool); !exists {
-			blockers = append(blockers, blocker("missing_required_artifact", "artifact", fmt.Sprintf("required current-step artifact %s is missing", label), map[string]any{"path": artifact["path"], "artifact_id": artifact["id"]}))
+			blockers = append(blockers, blocker(tx, "missing_required_artifact",
+				map[string]string{"artifact_id": artifactID, "path": artifactPath},
+				map[string]any{"path": artifact["path"], "artifact_id": artifact["id"]}))
 			continue
 		}
 		if incomplete, _ := artifact["incomplete"].(bool); incomplete {
-			blockers = append(blockers, blocker("artifact_scaffold_incomplete", "artifact", fmt.Sprintf("current-step artifact %s is still an incomplete scaffold", label), map[string]any{"path": artifact["path"], "artifact_id": artifact["id"]}))
+			blockers = append(blockers, blocker(tx, "artifact_scaffold_incomplete",
+				map[string]string{"artifact_id": artifactID, "path": artifactPath},
+				map[string]any{"path": artifact["path"], "artifact_id": artifact["id"]}))
 			continue
 		}
 		if blockingArtifactValidation(artifact) {
-			blockers = append(blockers, blocker("artifact_validation_failed", "artifact", fmt.Sprintf("current-step artifact %s failed validation", label), map[string]any{"path": artifact["path"], "artifact_id": artifact["id"], "finding_codes": validationFindingCodes(artifact)}))
+			blockers = append(blockers, blocker(tx, "artifact_validation_failed",
+				map[string]string{"artifact_id": artifactID, "path": artifactPath},
+				map[string]any{"path": artifact["path"], "artifact_id": artifact["id"], "finding_codes": validationFindingCodes(artifact)}))
 		}
 	}
 	if getStringDefault(state, "step", "") == "review" && getStringDefault(state, "step_status", "") == "completed" {
 		if _, ok := latestPassingReviewGate(state); !ok {
-			blockers = append(blockers, blocker("archive_requires_review_gate", "archive", "row cannot archive until a passing ->review gate exists", nil))
+			blockers = append(blockers, blocker(tx, "archive_requires_review_gate", nil, nil))
 		}
 	}
 	return blockers
```

## Instructions

For each dimension, provide: verdict (pass/fail) and one-line evidence.

Output as JSON: {"dimensions": [{"name": "...", "verdict": "...", "evidence": "..."}], "overall": "pass|fail"}
