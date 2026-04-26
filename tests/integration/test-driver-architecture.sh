#!/bin/bash
# test-driver-architecture.sh — Integration tests for D2 driver architecture.
#
# Tests the following ACs:
#   AC1/AC2  — 7 driver YAMLs exist and match schema (structural check)
#   AC3      — skills/shared/layer-protocol.md has required sections
#   AC4      — skills/shared/specialist-delegation.md rewritten for driver→engine framing
#   AC5      — all 7 step skills addressed to phase driver
#   AC6      — team-plan.md creation prescriptions removed from skills/ and commands/
#   AC7      — commands/work.md.tmpl renders for both runtimes (Claude + Pi blocks)
#   AC8      — furrow render adapters --runtime=claude produces .claude/agents/ files
#   AC12     — go build/vet/test pass

set -euo pipefail

# shellcheck source=helpers.sh
. "$(dirname "$0")/helpers.sh"

DRIVER_DIR="$PROJECT_ROOT/.furrow/drivers"
SKILLS_DIR="$PROJECT_ROOT/skills"
SCHEMAS_DIR="$PROJECT_ROOT/schemas"

# Build the furrow binary once into a temp file for all render tests
FURROW_BIN=""

setup_furrow_bin() {
  FURROW_BIN="$(mktemp)"
  go build -o "$FURROW_BIN" "$PROJECT_ROOT/cmd/furrow" >/dev/null 2>&1
}

teardown_furrow_bin() {
  if [ -n "$FURROW_BIN" ] && [ -f "$FURROW_BIN" ]; then
    rm -f "$FURROW_BIN"
  fi
}

# ---------------------------------------------------------------------------
# AC1: 7 driver YAMLs exist
# ---------------------------------------------------------------------------
test_driver_yaml_count() {
  local count
  count=$(find "$DRIVER_DIR" -name "driver-*.yaml" | wc -l | tr -d ' ')
  assert_ge "7 driver YAMLs exist" "$count" 7
}

# ---------------------------------------------------------------------------
# AC1: each driver YAML has required fields
# ---------------------------------------------------------------------------
test_driver_yaml_schema() {
  local steps="ideate research plan spec decompose implement review"
  for step in $steps; do
    local path="$DRIVER_DIR/driver-${step}.yaml"
    assert_file_exists "driver-${step}.yaml exists" "$path"
    assert_file_contains "driver-${step}.yaml has name field" "$path" "^name: driver:${step}"
    assert_file_contains "driver-${step}.yaml has step field" "$path" "^step: ${step}"
    assert_file_contains "driver-${step}.yaml has tools_allowlist" "$path" "^tools_allowlist:"
    assert_file_contains "driver-${step}.yaml has model field" "$path" "^model:"
  done
}

# ---------------------------------------------------------------------------
# AC2: schema has additionalProperties: false and correct enum values
# ---------------------------------------------------------------------------
test_driver_schema_strictness() {
  local schema="$SCHEMAS_DIR/driver-definition.schema.json"
  assert_file_exists "driver-definition.schema.json exists" "$schema"
  assert_file_contains "schema has additionalProperties: false" "$schema" '"additionalProperties": false'
  assert_file_contains "schema has name pattern constraint" "$schema" '"pattern"'
  local steps="ideate research plan spec decompose implement review"
  for step in $steps; do
    assert_file_contains "schema enumerates step '$step'" "$schema" "\"${step}\""
  done
}

# ---------------------------------------------------------------------------
# AC3: layer-protocol.md has required sections
# ---------------------------------------------------------------------------
test_layer_protocol_sections() {
  local doc="$SKILLS_DIR/shared/layer-protocol.md"
  assert_file_exists "layer-protocol.md exists" "$doc"
  assert_file_contains "layer-protocol.md has ## Operator section" "$doc" "^## Operator"
  assert_file_contains "layer-protocol.md has ## Phase Driver section" "$doc" "## Phase Driver"
  assert_file_contains "layer-protocol.md has ## Engine section" "$doc" "^## Engine"
  assert_file_contains "layer-protocol.md has ## Handoff Exchange section" "$doc" "## Handoff Exchange"
  assert_file_contains "layer-protocol.md has ## Engine-Team-Composed-at-Dispatch section" "$doc" "## Engine-Team-Composed-at-Dispatch"
}

# ---------------------------------------------------------------------------
# AC4: specialist-delegation.md rewritten for driver→engine framing
# ---------------------------------------------------------------------------
test_specialist_delegation_rewritten() {
  local doc="$SKILLS_DIR/shared/specialist-delegation.md"
  assert_file_exists "specialist-delegation.md exists" "$doc"
  assert_file_not_contains "specialist-delegation.md no longer has 'operator dispatches'" "$doc" "operator dispatches"
  assert_file_contains "specialist-delegation.md references driver" "$doc" "driver"
  assert_file_contains "specialist-delegation.md references engine" "$doc" "engine"
  assert_file_contains "specialist-delegation.md references dispatch primitive" "$doc" "furrow handoff render"
}

# ---------------------------------------------------------------------------
# AC5: all 7 step skills addressed to phase driver
# ---------------------------------------------------------------------------
test_step_skills_addressed_to_driver() {
  local steps="ideate research plan spec decompose implement review"
  for step in $steps; do
    local path="$SKILLS_DIR/${step}.md"
    assert_file_exists "${step}.md exists" "$path"
    assert_file_contains "${step}.md contains 'phase driver'" "$path" "phase driver"
  done
}

# ---------------------------------------------------------------------------
# AC6: team-plan.md creation prescriptions removed
# AC7 (plan.md): plan.md does not prescribe creating team-plan.md
# ---------------------------------------------------------------------------
test_team_plan_md_dropped_from_plan() {
  local path="$SKILLS_DIR/plan.md"
  assert_file_not_contains "plan.md does not prescribe creating team-plan.md" "$path" "create.*team-plan"
  # plan.md should note team-plan.md is retired
  assert_file_contains "plan.md notes team-plan.md is retired" "$path" "retired"
}

test_team_plan_md_dropped_from_decompose() {
  local path="$SKILLS_DIR/decompose.md"
  assert_file_not_contains "decompose.md does not prescribe creating team-plan.md" "$path" "create.*team-plan"
  assert_file_contains "decompose.md notes team-plan.md is retired" "$path" "retired"
}

# ---------------------------------------------------------------------------
# AC8: commands/work.md.tmpl has runtime branches
# ---------------------------------------------------------------------------
test_work_tmpl_has_runtime_branches() {
  local tmpl="$PROJECT_ROOT/commands/work.md.tmpl"
  assert_file_exists "commands/work.md.tmpl exists" "$tmpl"
  assert_file_contains "work.md.tmpl has Claude runtime branch" "$tmpl" 'eq .Runtime "claude"'
  assert_file_contains "work.md.tmpl has Pi runtime branch" "$tmpl" '"pi"'
  assert_file_contains "work.md.tmpl references pi-subagents in Pi block" "$tmpl" "pi-subagents"
  assert_file_contains "work.md.tmpl references Agent() in Claude block" "$tmpl" "Agent("
}

# ---------------------------------------------------------------------------
# AC9: furrow render adapters --runtime=claude produces manifested output
# ---------------------------------------------------------------------------
test_render_adapters_claude() {
  if [ -z "$FURROW_BIN" ]; then
    setup_furrow_bin
    trap teardown_furrow_bin EXIT
  fi

  local output
  output=$("$FURROW_BIN" render adapters --runtime=claude --project-dir="$PROJECT_ROOT" 2>&1)
  assert_output_contains "Claude render output includes driver-ideate.md" "$output" "driver-ideate.md"
  assert_output_contains "Claude render output includes driver-research.md" "$output" "driver-research.md"
  assert_output_contains "Claude render output includes driver-implement.md" "$output" "driver-implement.md"
  assert_output_contains "Claude render output includes driver-review.md" "$output" "driver-review.md"
  assert_output_contains "Claude render output has name frontmatter" "$output" '"driver:'
  assert_output_contains "Claude render output has model frontmatter" "$output" 'model:'
  assert_output_contains "Claude render work.md has Agent() call" "$output" "Agent("
}

# ---------------------------------------------------------------------------
# AC9: furrow render adapters --runtime=pi produces pi work.md (no agents/)
# ---------------------------------------------------------------------------
test_render_adapters_pi() {
  if [ -z "$FURROW_BIN" ]; then
    setup_furrow_bin
    trap teardown_furrow_bin EXIT
  fi

  local output
  output=$("$FURROW_BIN" render adapters --runtime=pi --project-dir="$PROJECT_ROOT" 2>&1)
  assert_output_contains "Pi render work.md has pi-subagents reference" "$output" "pi-subagents"
  assert_file_not_contains "Pi render has no .claude/agents/ paths in output" <(echo "$output") ".claude/agents/"
}

# ---------------------------------------------------------------------------
# Model defaults per spec
# ---------------------------------------------------------------------------
test_driver_model_defaults() {
  assert_file_contains "driver-research.yaml uses opus" "$DRIVER_DIR/driver-research.yaml" "^model: opus"
  local sonnet_steps="ideate plan spec decompose implement review"
  for step in $sonnet_steps; do
    assert_file_contains "driver-${step}.yaml uses sonnet" "$DRIVER_DIR/driver-${step}.yaml" "^model: sonnet"
  done
}

# ---------------------------------------------------------------------------
# implement driver has Edit and Write tools
# ---------------------------------------------------------------------------
test_implement_driver_tools() {
  local path="$DRIVER_DIR/driver-implement.yaml"
  assert_file_contains "driver-implement.yaml has Edit tool" "$path" "Edit"
  assert_file_contains "driver-implement.yaml has Write tool" "$path" "Write"
}

# ---------------------------------------------------------------------------
# Pi extension: exists and documents recursive-spawn verdict
# ---------------------------------------------------------------------------
test_pi_extension_exists() {
  local ext="$PROJECT_ROOT/adapters/pi/extension/index.ts"
  assert_file_exists "adapters/pi/extension/index.ts exists" "$ext"
  assert_file_contains "extension documents FALLBACK_NEEDED verdict" "$ext" "FALLBACK_NEEDED"
  assert_file_contains "extension documents EXCLUDED_TOOL_NAMES finding" "$ext" "EXCLUDED_TOOL_NAMES"
  assert_file_contains "extension has before_agent_start hook" "$ext" "before_agent_start"
  assert_file_contains "extension has tool_call hook" "$ext" "tool_call"
}

# ---------------------------------------------------------------------------
# AC12: go build + go vet + go test pass
# ---------------------------------------------------------------------------
test_go_toolchain() {
  local build_out
  if build_out=$(go build ./... 2>&1); then
    assert_not_empty "go build succeeded" "ok"
  else
    assert_not_empty "go build FAILED: $build_out" ""
  fi

  local vet_out
  if vet_out=$(go vet ./... 2>&1); then
    assert_not_empty "go vet succeeded" "ok"
  else
    assert_not_empty "go vet FAILED: $vet_out" ""
  fi

  local test_out
  if test_out=$(go test ./... 2>&1); then
    assert_not_empty "go test ./... succeeded" "ok"
  else
    assert_not_empty "go test ./... FAILED: $test_out" ""
  fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
setup_furrow_bin
trap teardown_furrow_bin EXIT

run_test test_driver_yaml_count
run_test test_driver_yaml_schema
run_test test_driver_schema_strictness
run_test test_layer_protocol_sections
run_test test_specialist_delegation_rewritten
run_test test_step_skills_addressed_to_driver
run_test test_team_plan_md_dropped_from_plan
run_test test_team_plan_md_dropped_from_decompose
run_test test_work_tmpl_has_runtime_branches
run_test test_render_adapters_claude
run_test test_render_adapters_pi
run_test test_driver_model_defaults
run_test test_implement_driver_tools
run_test test_pi_extension_exists
run_test test_go_toolchain

print_summary
