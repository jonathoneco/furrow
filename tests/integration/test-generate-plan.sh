#!/bin/bash
# test-generate-plan.sh — Integration tests for scripts/generate-plan.sh
#
# Sourced by the test runner. Requires helpers.sh (provides setup_fixture,
# teardown_fixture, assert_exit_code, assert_file_exists, assert_file_contains,
# assert_json_field, FURROW_ROOT).

# --- helper: set up symlink structure so generate-plan.sh resolves FURROW_ROOT to FIXTURE_DIR ---

_setup_plan_fixture() {
  _name="$1"
  setup_fixture "$_name"

  mkdir -p "${FIXTURE_DIR}/scripts" "${FIXTURE_DIR}/hooks/lib"
  ln -sf "${FURROW_ROOT}/scripts/generate-plan.sh" "${FIXTURE_DIR}/scripts/generate-plan.sh"
  ln -sf "${FURROW_ROOT}/hooks/lib/validate.sh" "${FIXTURE_DIR}/hooks/lib/validate.sh"
}

# --- test functions ---

test_linear_chain() {
  _setup_plan_fixture "__test-gen-plan-linear"

  cat > "${WORK_DIR}/definition.yaml" << 'YAML'
objective: "test linear chain"
deliverables:
  - name: step-c
    specialist: test-eng
    acceptance_criteria: ["c done"]
  - name: step-b
    specialist: test-eng
    depends_on: [step-c]
    acceptance_criteria: ["b done"]
  - name: step-a
    specialist: test-eng
    depends_on: [step-b]
    acceptance_criteria: ["a done"]
context_pointers:
  - path: test
    note: test
constraints: []
gate_policy: supervised
YAML

  exit_code=0
  "${FIXTURE_DIR}/scripts/generate-plan.sh" "__test-gen-plan-linear" > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "linear chain exits 0" 0 "$exit_code"
  assert_file_exists "plan.json created" "${WORK_DIR}/plan.json"

  # Wave assignments: step-c=1, step-b=2, step-a=3
  assert_json_field "step-c in wave 1" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 1) | .deliverables[]] | map(select(. == "step-c")) | length' "1"
  assert_json_field "step-b in wave 2" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 2) | .deliverables[]] | map(select(. == "step-b")) | length' "1"
  assert_json_field "step-a in wave 3" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 3) | .deliverables[]] | map(select(. == "step-a")) | length' "1"
  assert_json_field "exactly 3 waves" "${WORK_DIR}/plan.json" \
    '.waves | length' "3"

  teardown_fixture
}

test_diamond_dependency() {
  _setup_plan_fixture "__test-gen-plan-diamond"

  cat > "${WORK_DIR}/definition.yaml" << 'YAML'
objective: "test diamond dependency"
deliverables:
  - name: base
    specialist: test-eng
    acceptance_criteria: ["done"]
  - name: left
    specialist: test-eng
    depends_on: [base]
    acceptance_criteria: ["done"]
  - name: right
    specialist: test-eng
    depends_on: [base]
    acceptance_criteria: ["done"]
  - name: top
    specialist: test-eng
    depends_on: [left, right]
    acceptance_criteria: ["done"]
context_pointers:
  - path: test
    note: test
constraints: []
gate_policy: supervised
YAML

  exit_code=0
  "${FIXTURE_DIR}/scripts/generate-plan.sh" "__test-gen-plan-diamond" > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "diamond dependency exits 0" 0 "$exit_code"
  assert_file_exists "plan.json created" "${WORK_DIR}/plan.json"

  # Wave assignments: base=1, left+right=2, top=3
  assert_json_field "base in wave 1" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 1) | .deliverables[]] | map(select(. == "base")) | length' "1"
  assert_json_field "left in wave 2" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 2) | .deliverables[]] | map(select(. == "left")) | length' "1"
  assert_json_field "right in wave 2" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 2) | .deliverables[]] | map(select(. == "right")) | length' "1"
  assert_json_field "top in wave 3" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 3) | .deliverables[]] | map(select(. == "top")) | length' "1"
  assert_json_field "exactly 3 waves" "${WORK_DIR}/plan.json" \
    '.waves | length' "3"

  teardown_fixture
}

test_cycle_detection() {
  _setup_plan_fixture "__test-gen-plan-cycle"

  cat > "${WORK_DIR}/definition.yaml" << 'YAML'
objective: "test cycle detection"
deliverables:
  - name: alpha
    specialist: test-eng
    depends_on: [gamma]
    acceptance_criteria: ["done"]
  - name: beta
    specialist: test-eng
    depends_on: [alpha]
    acceptance_criteria: ["done"]
  - name: gamma
    specialist: test-eng
    depends_on: [beta]
    acceptance_criteria: ["done"]
context_pointers:
  - path: test
    note: test
constraints: []
gate_policy: supervised
YAML

  stderr_file="${FIXTURE_DIR}/stderr.txt"

  exit_code=0
  "${FIXTURE_DIR}/scripts/generate-plan.sh" "__test-gen-plan-cycle" > /dev/null 2>"$stderr_file" || exit_code=$?

  assert_exit_code "cycle detection exits 3" 3 "$exit_code"
  assert_file_contains "stderr mentions cycle" "$stderr_file" "cycle"

  assert_file_not_exists "no plan.json after cycle error" "${WORK_DIR}/plan.json"

  teardown_fixture
}

test_multi_root_dag() {
  _setup_plan_fixture "__test-gen-plan-multi-root"

  cat > "${WORK_DIR}/definition.yaml" << 'YAML'
objective: "test multi-root DAG"
deliverables:
  - name: root-a
    specialist: test-eng
    acceptance_criteria: ["done"]
  - name: root-b
    specialist: test-eng
    acceptance_criteria: ["done"]
  - name: child-a
    specialist: test-eng
    depends_on: [root-a]
    acceptance_criteria: ["done"]
  - name: child-b
    specialist: test-eng
    depends_on: [root-b]
    acceptance_criteria: ["done"]
context_pointers:
  - path: test
    note: test
constraints: []
gate_policy: supervised
YAML

  exit_code=0
  "${FIXTURE_DIR}/scripts/generate-plan.sh" "__test-gen-plan-multi-root" > /dev/null 2>&1 || exit_code=$?

  assert_exit_code "multi-root DAG exits 0" 0 "$exit_code"
  assert_file_exists "plan.json created" "${WORK_DIR}/plan.json"

  # Wave assignments: root-a + root-b = wave 1, child-a + child-b = wave 2
  assert_json_field "root-a in wave 1" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 1) | .deliverables[]] | map(select(. == "root-a")) | length' "1"
  assert_json_field "root-b in wave 1" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 1) | .deliverables[]] | map(select(. == "root-b")) | length' "1"
  assert_json_field "child-a in wave 2" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 2) | .deliverables[]] | map(select(. == "child-a")) | length' "1"
  assert_json_field "child-b in wave 2" "${WORK_DIR}/plan.json" \
    '[.waves[] | select(.wave == 2) | .deliverables[]] | map(select(. == "child-b")) | length' "1"
  assert_json_field "exactly 2 waves" "${WORK_DIR}/plan.json" \
    '.waves | length' "2"

  teardown_fixture
}

test_missing_specialist() {
  _setup_plan_fixture "__test-gen-plan-no-spec"

  cat > "${WORK_DIR}/definition.yaml" << 'YAML'
objective: "test missing specialist"
deliverables:
  - name: no-spec
    acceptance_criteria: ["done"]
context_pointers:
  - path: test
    note: test
constraints: []
gate_policy: supervised
YAML

  stderr_file="${FIXTURE_DIR}/stderr.txt"

  exit_code=0
  "${FIXTURE_DIR}/scripts/generate-plan.sh" "__test-gen-plan-no-spec" > /dev/null 2>"$stderr_file" || exit_code=$?

  assert_exit_code "missing specialist exits 3" 3 "$exit_code"
  assert_file_contains "stderr mentions specialist" "$stderr_file" "specialist"

  assert_file_not_exists "no plan.json after specialist error" "${WORK_DIR}/plan.json"

  teardown_fixture
}
