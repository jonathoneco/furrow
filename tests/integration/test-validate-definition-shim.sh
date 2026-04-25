#!/usr/bin/env bash
# test-validate-definition-shim.sh — Verifies the rewritten `frw validate-definition`
# shim continues to satisfy existing callers after the Go-first port (D1 of the
# pre-write-validation-go-first row).
#
# Asserts: exit 0 on a valid definition.yaml; non-zero exit on an invalid one.
# The exact non-zero code (1 or 3) is implementation-specific to the Go CLI;
# what matters for shim continuity is that valid → 0, invalid → non-zero.

set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PROJECT_ROOT
export FURROW_ROOT="${PROJECT_ROOT}"

fixtures_dir="$(mktemp -d)"
trap 'rm -rf "$fixtures_dir"' EXIT

valid_fixture="${fixtures_dir}/valid-definition.yaml"
cat > "$valid_fixture" <<'EOF'
objective: "shim continuity smoke test fixture"
deliverables:
  - name: thing
    acceptance_criteria:
      - "thing does the thing"
context_pointers:
  - path: "/tmp/foo"
    note: "fixture pointer"
constraints: []
gate_policy: supervised
mode: code
EOF

invalid_fixture="${fixtures_dir}/invalid-definition.yaml"
cat > "$invalid_fixture" <<'EOF'
deliverables: []
context_pointers:
  - path: "/tmp/foo"
    note: "n"
constraints: []
gate_policy: bogus
EOF

pass_count=0
fail_count=0

assert_exit() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass_count=$((pass_count + 1))
    echo "  PASS: $description (exit=$actual)"
  else
    fail_count=$((fail_count + 1))
    echo "  FAIL: $description (expected exit=$expected, got $actual)" >&2
  fi
}

# --- valid path → exit 0 ---
set +e
frw validate-definition "$valid_fixture" >/dev/null 2>&1
valid_exit=$?
set -e
assert_exit "valid definition.yaml exits 0" "0" "$valid_exit"

# --- invalid path → non-zero exit ---
set +e
frw validate-definition "$invalid_fixture" >/dev/null 2>&1
invalid_exit=$?
set -e
if [ "$invalid_exit" -ne 0 ]; then
  pass_count=$((pass_count + 1))
  echo "  PASS: invalid definition.yaml exits non-zero (exit=$invalid_exit)"
else
  fail_count=$((fail_count + 1))
  echo "  FAIL: invalid definition.yaml expected non-zero exit, got 0" >&2
fi

# --- usage error: missing argument → non-zero exit ---
set +e
frw validate-definition >/dev/null 2>&1
no_arg_exit=$?
set -e
if [ "$no_arg_exit" -ne 0 ]; then
  pass_count=$((pass_count + 1))
  echo "  PASS: missing argument exits non-zero (exit=$no_arg_exit)"
else
  fail_count=$((fail_count + 1))
  echo "  FAIL: missing argument expected non-zero exit, got 0" >&2
fi

echo ""
echo "Summary: $pass_count passed, $fail_count failed"
exit "$fail_count"
