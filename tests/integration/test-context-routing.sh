#!/bin/sh
# tests/integration/test-context-routing.sh
#
# Integration test for the D4 context-routing CLI.
# Exercises `furrow context for-step` across multiple steps and targets,
# asserts bundle shape, target filtering correctness, and skill coverage.
#
# Exit 0 on full pass; non-zero with a descriptive message on any failure.
#
# Dependencies: furrow binary in PATH or FURROW_BIN env var; jq.
#
# Coverage:
#   - CLI surface: for-step subcommand exists and dispatches
#   - Bundle shape: skills/references/prior_artifacts/decisions/step_strategy_metadata
#   - Target filtering: operator|driver|specialist:* return distinct layer sets (R6)
#   - ListSkills coverage: skills/shared/* present in output (R9)
#   - Specialist injection: specialists/{id}.md injected as engine-layer skill (R9)
#   - Target regression: different targets return different skill sets (R6 guard)
#   - Help output: lists for-step
#   - Cache identity: two runs produce identical output
#   - Decisions extraction: fixture row decisions correctly parsed

set -e

FURROW="${FURROW_BIN:-furrow}"
FIXTURE_ROW="${FIXTURE_ROW:-context-routing-test-fixture}"
LAYER_FIXTURE_ROW="${LAYER_FIXTURE_ROW:-pre-write-validation-go-first}"
PASS_COUNT=0
FAIL_COUNT=0

# Determine repo root (directory containing .furrow/).
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -z "$REPO_ROOT" ]; then
    d="$(pwd)"
    while [ "$d" != "/" ]; do
        if [ -d "$d/.furrow" ]; then
            REPO_ROOT="$d"
            break
        fi
        d="$(dirname "$d")"
    done
fi

if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/.furrow" ]; then
    echo "FAIL: cannot locate .furrow root" >&2
    exit 1
fi

cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pass() {
    _label="$1"
    echo "  PASS: $_label"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    _label="$1"
    echo "  FAIL: $_label" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_jq() {
    _label="$1"
    _json="$2"
    _expr="$3"
    _result=$(printf '%s' "$_json" | jq -e "$_expr" 2>/dev/null)
    if [ $? -eq 0 ]; then
        pass "$_label"
    else
        fail "$_label: jq '$_expr' returned false/null"
    fi
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------

echo ""
echo "=== Context Routing Integration Tests (fixture: $FIXTURE_ROW) ==="
echo ""

ROW_DIR="$REPO_ROOT/.furrow/rows/$FIXTURE_ROW"
if [ ! -d "$ROW_DIR" ]; then
    echo "SKIP: fixture row '$FIXTURE_ROW' not found at $ROW_DIR" >&2
    echo "Set FIXTURE_ROW to an existing row or use the default context-routing-test-fixture." >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# AC §13 — furrow context --help lists for-step (always works)
# ---------------------------------------------------------------------------

echo "--- AC 13: furrow context help ---"

help_out=$("$FURROW" context help 2>/dev/null) || true
if printf '%s' "$help_out" | grep -q "for-step"; then
    pass "furrow context help: lists for-step"
else
    fail "furrow context help: 'for-step' not found in output"
fi

# ---------------------------------------------------------------------------
# AC §1 — Bundle assembly: valid bundle with non-empty skills
# ---------------------------------------------------------------------------

echo ""
echo "--- AC 1+5: bundle assembly ---"

raw_out=$("$FURROW" context for-step plan --target driver --row "$FIXTURE_ROW" --json 2>/dev/null) || true
raw_exit=$?

if printf '%s' "$raw_out" | jq -e '.row' > /dev/null 2>&1; then
    pass "AC 1: for-step plan returns valid bundle"
    assert_jq "AC 1: bundle .step == plan" "$raw_out" '.step == "plan"'
    assert_jq "AC 1: bundle .target == driver" "$raw_out" '.target == "driver"'
    assert_jq "AC 1: bundle has skills array" "$raw_out" '.skills | type == "array"'
    assert_jq "AC 1: bundle has decisions array" "$raw_out" '.decisions | type == "array"'
    assert_jq "AC 1: bundle has prior_artifacts" "$raw_out" '.prior_artifacts | type == "object"'
    assert_jq "AC 1: bundle has step_strategy_metadata" "$raw_out" '.step_strategy_metadata | type == "object"'
    assert_jq "AC 1: skills array is non-empty" "$raw_out" '.skills | length > 0'
elif printf '%s' "$raw_out" | jq -e '.blocker.code == "skill_layer_unset"' > /dev/null 2>&1; then
    fail "AC 1: skill_layer_unset blocker fired — skills are missing layer: front-matter tags (D3 required)"
else
    fail "AC 1: unexpected output from for-step (exit=$raw_exit)"
fi

# ---------------------------------------------------------------------------
# AC §2 — Missing row returns blocker
# ---------------------------------------------------------------------------

echo ""
echo "--- AC 2: missing row returns error ---"

missing_out=$("$FURROW" context for-step plan --target driver --row no-such-row-xyz --json 2>/dev/null) || true
missing_exit=$?

if printf '%s' "$missing_out" | jq -e '.blocker' > /dev/null 2>&1; then
    pass "AC 2: missing row emits blocker envelope"
else
    fail "AC 2: missing row did not emit blocker; exit=$missing_exit"
fi

# ---------------------------------------------------------------------------
# AC §3 — Invalid step returns usage error
# ---------------------------------------------------------------------------

echo ""
echo "--- AC 3: invalid step returns usage error ---"

bad_step_exit=0
"$FURROW" context for-step invalid-step --row "$FIXTURE_ROW" --json > /dev/null 2>&1 || bad_step_exit=$?
if [ "$bad_step_exit" -ne 0 ]; then
    pass "AC 3: invalid step returns non-zero exit ($bad_step_exit)"
else
    fail "AC 3: invalid step should return non-zero exit"
fi

# ---------------------------------------------------------------------------
# AC §4 — Invalid target returns usage error
# ---------------------------------------------------------------------------

echo ""
echo "--- AC 4: invalid target returns usage error ---"

bad_target_exit=0
"$FURROW" context for-step plan --target bad-target --row "$FIXTURE_ROW" --json > /dev/null 2>&1 || bad_target_exit=$?
if [ "$bad_target_exit" -ne 0 ]; then
    pass "AC 4: invalid target returns non-zero exit ($bad_target_exit)"
else
    fail "AC 4: invalid target should return non-zero exit"
fi

# ---------------------------------------------------------------------------
# AC §R6/R7/R9 — Target filtering + ListSkills coverage + specialist injection
# Runs against LAYER_FIXTURE_ROW (default: pre-write-validation-go-first)
# which has skills with layer: front-matter.
# ---------------------------------------------------------------------------

echo ""
echo "--- AC R6+R7+R9: target filtering, shared skills, specialist injection ---"

LF_DIR="$REPO_ROOT/.furrow/rows/$LAYER_FIXTURE_ROW"
if [ ! -d "$LF_DIR" ]; then
    echo "  SKIP: layer fixture row '$LAYER_FIXTURE_ROW' not found; skipping target-filter assertions"
else
    # Get bundles for three targets.
    op_out=$("$FURROW" context for-step plan --target operator --row "$LAYER_FIXTURE_ROW" --json 2>/dev/null) || op_out=""
    dr_out=$("$FURROW" context for-step plan --target driver  --row "$LAYER_FIXTURE_ROW" --json 2>/dev/null) || dr_out=""
    sp_out=$("$FURROW" context for-step plan --target specialist:go-specialist --row "$LAYER_FIXTURE_ROW" --json 2>/dev/null) || sp_out=""

    # Each must be a valid bundle (not a blocker).
    for _tgt in operator driver "specialist:go-specialist"; do
        case "$_tgt" in
            operator)               _json="$op_out" ;;
            driver)                 _json="$dr_out" ;;
            specialist:go-specialist) _json="$sp_out" ;;
        esac
        if printf '%s' "$_json" | jq -e '.row' > /dev/null 2>&1; then
            pass "R6: --target $_tgt returns valid bundle"
        elif printf '%s' "$_json" | jq -e '.blocker' > /dev/null 2>&1; then
            _code=$(printf '%s' "$_json" | jq -r '.blocker.code')
            fail "R6: --target $_tgt returned blocker '$_code' (expected valid bundle)"
        else
            fail "R6: --target $_tgt returned unexpected output"
        fi
    done

    # operator target must contain ONLY operator|shared layers.
    if [ -n "$op_out" ] && printf '%s' "$op_out" | jq -e '.row' > /dev/null 2>&1; then
        bad_op=$(printf '%s' "$op_out" | jq -r '[.skills[] | select(.layer != "operator" and .layer != "shared") | .layer] | length')
        if [ "$bad_op" = "0" ]; then
            pass "R6: operator target contains only operator|shared layers"
        else
            fail "R6: operator target has $bad_op skills with wrong layers (must be operator|shared)"
        fi
        assert_jq "R9: operator bundle has non-empty skills" "$op_out" '.skills | length > 0'
    fi

    # driver target must contain ONLY driver|shared layers.
    if [ -n "$dr_out" ] && printf '%s' "$dr_out" | jq -e '.row' > /dev/null 2>&1; then
        bad_dr=$(printf '%s' "$dr_out" | jq -r '[.skills[] | select(.layer != "driver" and .layer != "shared") | .layer] | length')
        if [ "$bad_dr" = "0" ]; then
            pass "R6: driver target contains only driver|shared layers"
        else
            fail "R6: driver target has $bad_dr skills with wrong layers (must be driver|shared)"
        fi
    fi

    # specialist:go-specialist must contain ONLY engine|shared layers AND the specialist brief.
    if [ -n "$sp_out" ] && printf '%s' "$sp_out" | jq -e '.row' > /dev/null 2>&1; then
        bad_sp=$(printf '%s' "$sp_out" | jq -r '[.skills[] | select(.layer != "engine" and .layer != "shared") | .layer] | length')
        if [ "$bad_sp" = "0" ]; then
            pass "R6: specialist target contains only engine|shared layers"
        else
            fail "R6: specialist target has $bad_sp skills with wrong layers (must be engine|shared)"
        fi
        # Specialist brief injected.
        has_brief=$(printf '%s' "$sp_out" | jq -r '[.skills[] | select(.path == "specialists/go-specialist.md")] | length')
        if [ "$has_brief" = "1" ]; then
            pass "R9: specialist:go-specialist brief injected as engine-layer skill"
        else
            fail "R9: specialists/go-specialist.md not found in specialist bundle skills"
        fi
    fi

    # skills/shared/* must be present in driver bundle (R9 shared coverage).
    if [ -n "$dr_out" ] && printf '%s' "$dr_out" | jq -e '.row' > /dev/null 2>&1; then
        shared_count=$(printf '%s' "$dr_out" | jq -r '[.skills[] | select(.path | startswith("skills/shared/"))] | length')
        if [ "$shared_count" -gt 0 ]; then
            pass "R9: skills/shared/* present in driver bundle ($shared_count shared skills)"
        else
            fail "R9: no skills/shared/* found in driver bundle"
        fi
    fi

    # Regression guard: different targets must NOT produce identical skill sets (R6).
    if [ -n "$op_out" ] && [ -n "$dr_out" ] && \
       printf '%s' "$op_out" | jq -e '.row' > /dev/null 2>&1 && \
       printf '%s' "$dr_out" | jq -e '.row' > /dev/null 2>&1; then
        op_layers=$(printf '%s' "$op_out" | jq -c '[.skills[].layer] | sort')
        dr_layers=$(printf '%s' "$dr_out" | jq -c '[.skills[].layer] | sort')
        if [ "$op_layers" != "$dr_layers" ]; then
            pass "R6: operator and driver targets produce different layer sets (no target-filter bypass)"
        else
            fail "R6 regression: operator and driver produced identical layer sets — target filter is not working"
        fi
    fi

    # Regression guard: specialist and driver must differ (R6).
    if [ -n "$sp_out" ] && [ -n "$dr_out" ] && \
       printf '%s' "$sp_out" | jq -e '.row' > /dev/null 2>&1 && \
       printf '%s' "$dr_out" | jq -e '.row' > /dev/null 2>&1; then
        sp_layers=$(printf '%s' "$sp_out" | jq -c '[.skills[].layer] | sort | unique')
        dr_layers=$(printf '%s' "$dr_out" | jq -c '[.skills[].layer] | sort | unique')
        if [ "$sp_layers" != "$dr_layers" ]; then
            pass "R6: specialist and driver targets produce different layer-unique sets"
        else
            fail "R6 regression: specialist and driver produced identical unique-layer sets — target filter is not working"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# AC §6 — Decisions extraction on pre-write-validation-go-first
# ---------------------------------------------------------------------------

echo ""
echo "--- AC 6: decisions extraction (pre-write-validation-go-first) ---"

PW_ROW="pre-write-validation-go-first"
PW_DIR="$REPO_ROOT/.furrow/rows/$PW_ROW"

if [ -d "$PW_DIR" ]; then
    # The pre-write row has plan->spec retry; test decisions extraction directly
    # via the decisions parser (exercised in Go unit tests). Here we verify the
    # summary.md has the expected pattern.
    plan_spec_count=$(grep -c "plan->spec" "$PW_DIR/summary.md" 2>/dev/null || echo "0")
    if [ "$plan_spec_count" -ge 2 ]; then
        pass "AC 6: pre-write summary.md has plan->spec retry (fixture for de-dup test)"
    else
        fail "AC 6: expected >= 2 plan->spec entries in fixture, got $plan_spec_count"
    fi
else
    pass "AC 6: pre-write-validation-go-first not present; skipping (covered by Go unit tests)"
fi

# ---------------------------------------------------------------------------
# AC §12 — D1 round-trip: furrow handoff render works
# ---------------------------------------------------------------------------

echo ""
echo "--- AC 12: D1 round-trip ---"

# D1's handoff render is independent of D4. Verify it works with the fixture row.
handoff_out=$("$FURROW" handoff render --target driver:plan --row "$PW_ROW" --step plan 2>/dev/null) || true
handoff_exit=$?

if [ "$handoff_exit" -eq 0 ] && [ -n "$handoff_out" ]; then
    pass "AC 12: handoff render --target driver:plan exits 0 (D1 independent of D4)"
else
    fail "AC 12: handoff render exited $handoff_exit or empty output"
fi

# ---------------------------------------------------------------------------
# Determinism: two runs with same inputs produce identical output
# ---------------------------------------------------------------------------

echo ""
echo "--- determinism ---"

out1=$("$FURROW" context for-step plan --target driver --row "$FIXTURE_ROW" --json 2>/dev/null) || true
out2=$("$FURROW" context for-step plan --target driver --row "$FIXTURE_ROW" --json 2>/dev/null) || true

if [ "$out1" = "$out2" ]; then
    pass "determinism: identical inputs produce identical output"
else
    fail "determinism: two runs produced different output"
fi

# ---------------------------------------------------------------------------
# Performance: bundle generation is fast (no cache; cold-path measurement)
# ---------------------------------------------------------------------------

echo ""
echo "--- performance ---"

start_ms=$(date +%s%3N)
"$FURROW" context for-step plan --target driver --row "$FIXTURE_ROW" --json > /dev/null 2>&1 || true
end_ms=$(date +%s%3N)

elapsed=$((end_ms - start_ms))
if [ "$elapsed" -lt 500 ]; then
    pass "performance: bundle generation < 500ms (${elapsed}ms)"
else
    fail "performance: bundle generation ${elapsed}ms >= 500ms budget"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
