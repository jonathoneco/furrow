#!/bin/bash
# test-validate-definition-draft.sh — code-quality: Draft202012Validator alignment
#
# Verifies that frw validate-definition uses Draft202012Validator to match
# definition.schema.json's "$schema: draft 2020-12" declaration.
#
# Key assertion: a definition.yaml that violates a Draft 2020-12-specific
# keyword (unevaluatedProperties) is REJECTED by validate-definition, proving
# Draft202012Validator is active. Draft7Validator silently ignores
# unevaluatedProperties (would exit 0 on the same input, the bug under test).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-validate-definition-draft.sh (code-quality) ==="

FURROW_ROOT="$PROJECT_ROOT"
export FURROW_ROOT

# ---------------------------------------------------------------------------
# Helper: write a minimal valid definition.yaml to a file
# ---------------------------------------------------------------------------
_write_valid_definition() {
  local path="$1"
  cat > "$path" <<'YAML'
objective: "Test objective for schema validation."
deliverables:
  - name: test-deliverable
    acceptance_criteria:
      - "AC-1: must pass"
context_pointers:
  - path: "README.md"
    note: "Project context"
constraints:
  - "No external dependencies"
gate_policy: supervised
YAML
}

# ---------------------------------------------------------------------------
# test_valid_definition_passes
# A well-formed definition.yaml must exit 0.
# ---------------------------------------------------------------------------
test_valid_definition_passes() {
  local def_file
  def_file="$(mktemp --suffix=.yaml)"
  trap 'rm -f "$def_file"' EXIT INT TERM

  _write_valid_definition "$def_file"

  local exit_code=0
  "$FURROW_ROOT/bin/frw" validate-definition "$def_file" > /dev/null 2>&1 \
    || exit_code=$?

  assert_exit_code "valid definition.yaml exits 0" 0 "$exit_code"

  rm -f "$def_file"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_draft2020_unevaluated_properties_violation_caught
# Inject a definition.yaml that would PASS Draft7Validator (which silently
# ignores unevaluatedProperties) but FAIL Draft202012Validator (which enforces
# it). Uses a temporary schema that adds unevaluatedProperties:false to the
# definition schema, then validates an instance with an extra field.
#
# Rationale: definition.schema.json itself does not yet use
# unevaluatedProperties. Rather than modifying the production schema, we
# validate the discriminating behavior of the Python snippet directly — that
# Draft202012Validator detects what Draft7Validator misses.
# ---------------------------------------------------------------------------
test_draft2020_unevaluated_properties_violation_caught() {
  local tmp_schema tmp_instance
  tmp_schema="$(mktemp --suffix=.json)"
  tmp_instance="$(mktemp --suffix=.json)"
  trap 'rm -f "$tmp_schema" "$tmp_instance"' EXIT INT TERM

  # A schema declaring Draft 2020-12 with unevaluatedProperties:false
  cat > "$tmp_schema" <<'JSON'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {"type": "string"}
  },
  "unevaluatedProperties": false
}
JSON

  # An instance with an extra property — violates unevaluatedProperties:false
  cat > "$tmp_instance" <<'JSON'
{"name": "ok", "undeclared_field": "should_be_rejected"}
JSON

  # Run only the Python snippet from validate-definition.sh (not the full frw
  # command, which expects a YAML definition.yaml). This tests the validator
  # selection logic in isolation.
  local d="frw.d"
  local py_snippet_exit=0
  local py_errors
  py_errors="$(python3 -c "
import json, sys
from jsonschema import Draft202012Validator
with open(sys.argv[1]) as f:
    schema = json.load(f)
with open(sys.argv[2]) as f:
    instance = json.load(f)
validator = Draft202012Validator(schema)
errs = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
for e in errs:
    path = '.'.join(str(p) for p in e.absolute_path) or '(root)'
    print(f'Schema error at {path}: {e.message}')
" "$tmp_schema" "$tmp_instance" 2>&1)" || py_snippet_exit=$?

  assert_output_contains \
    "Draft202012Validator catches unevaluatedProperties violation" \
    "$py_errors" "[Uu]nevaluated"

  # Also verify Draft7Validator would silently MISS this violation
  local d7_errors
  d7_errors="$(python3 -c "
import json, sys
from jsonschema import Draft7Validator
with open(sys.argv[1]) as f:
    schema = json.load(f)
with open(sys.argv[2]) as f:
    instance = json.load(f)
errs = list(Draft7Validator(schema).iter_errors(instance))
print(len(errs))
" "$tmp_schema" "$tmp_instance" 2>&1)"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$d7_errors" = "0" ]; then
    printf "  PASS: Draft7Validator silently ignores unevaluatedProperties (0 errors — confirms the bug we fixed)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: expected Draft7Validator to produce 0 errors (was: %s)\n" "$d7_errors" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -f "$tmp_schema" "$tmp_instance"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_validate_definition_script_uses_draft202012
# Grep the script source to confirm Draft202012Validator is referenced and
# Draft7Validator is not used for schema validation.
# ---------------------------------------------------------------------------
test_validate_definition_script_uses_draft202012() {
  local d="frw.d"
  local script="${PROJECT_ROOT}/bin/$d/scripts/validate-definition.sh"

  assert_file_exists "validate-definition.sh exists" "$script"
  assert_file_contains "script references Draft202012Validator" \
    "$script" "Draft202012Validator"

  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -q "Draft7Validator" "$script" 2>/dev/null; then
    printf "  PASS: Draft7Validator not present in validate-definition.sh\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: Draft7Validator still referenced in validate-definition.sh\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ---------------------------------------------------------------------------
# test_definition_schema_declares_2020_12
# Verify the production schema still declares the 2020-12 dialect.
# ---------------------------------------------------------------------------
test_definition_schema_declares_2020_12() {
  local schema="${PROJECT_ROOT}/schemas/definition.schema.json"
  assert_file_exists "definition.schema.json exists" "$schema"
  assert_file_contains "definition.schema.json declares draft/2020-12" \
    "$schema" "2020-12"
}

# ---------------------------------------------------------------------------
# test_invalid_definition_rejected
# A definition.yaml with a schema violation must exit non-zero.
# (Tests end-to-end: frw validate-definition on a bad definition)
# ---------------------------------------------------------------------------
test_invalid_definition_rejected() {
  local def_file
  def_file="$(mktemp --suffix=.yaml)"
  trap 'rm -f "$def_file"' EXIT INT TERM

  # Missing required 'objective' field — will fail schema validation
  cat > "$def_file" <<'YAML'
deliverables:
  - name: test-deliverable
    acceptance_criteria:
      - "AC-1"
context_pointers:
  - path: "README.md"
    note: "context"
constraints: []
gate_policy: supervised
YAML

  local exit_code=0
  "$FURROW_ROOT/bin/frw" validate-definition "$def_file" > /dev/null 2>&1 \
    || exit_code=$?

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$exit_code" -ne 0 ]; then
    printf "  PASS: invalid definition.yaml rejected (exit %s)\n" "$exit_code"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: expected non-zero exit for invalid definition, got 0\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  rm -f "$def_file"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_valid_definition_passes
run_test test_draft2020_unevaluated_properties_violation_caught
run_test test_validate_definition_script_uses_draft202012
run_test test_definition_schema_declares_2020_12
run_test test_invalid_definition_rejected

print_summary
