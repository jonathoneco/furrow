# review-impl-scripts — Summary

## Objective
Review and fix 8 shell scripts written by subagents during harness-v2-status-eval for known bug patterns.

## Outcome
14 bugs fixed, 3 robustness concerns addressed across 8 scripts. All pass shellcheck.

## Key Fixes
- **yq syntax**: 3 instances of `--arg` (jq-only) converted to `env()` pattern
- **Word-splitting**: 7 `for in $var` loops converted to `while read` from temp files
- **Atomic writes**: 3 direct file writes replaced with mktemp+mv pattern
- **Exit codes**: 3 contracts corrected to match documented behavior
- **Error handling**: 2 silent failures given explicit error messages
- **Absolute paths**: 2 scripts using relative paths switched to `$HARNESS_ROOT`-based
- **Temp cleanup**: run-eval.sh now uses single tmpdir with trap EXIT
- **Other**: dead code removal, Python stderr separation, grep regex fix, null guard

## Scripts Modified
1. `scripts/run-eval.sh` (369 lines) — 6 fixes
2. `scripts/validate-step-artifacts.sh` (217 lines) — 3 fixes
3. `scripts/generate-plan.sh` (214 lines) — 2 fixes
4. `scripts/cross-model-review.sh` (174 lines) — 5 fixes
5. `hooks/correction-limit.sh` (88 lines) — 0 fixes (clean)
6. `scripts/select-dimensions.sh` (52 lines) — 1 fix
7. `scripts/evaluate-gate.sh` (62 lines) — 2 fixes
8. `scripts/run-ci-checks.sh` (139 lines) — 1 fix

## Process
- 3 parallel review agents (one per complexity cluster)
- 1 final review agent caught 2 bugs missed by initial reviewers
- All fixes verified with shellcheck -x -e SC1091,SC2016
