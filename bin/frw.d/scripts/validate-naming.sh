#!/bin/sh
# validate-naming.sh — Validate naming conventions for Furrow artifacts
#
# Usage:
#   frw validate-naming <type> <value>
#   Types: row, deliverable, gate-file, review-file
#
# Designed to be sourced by other scripts for reuse:
#   . "$FURROW_ROOT/bin/frw.d/scripts/validate-naming.sh"
#   validate_kebab_case "my-name" "row"

# --- validation functions (reusable when sourced) ---

# Validates kebab-case: lowercase letters/digits, separated by single hyphens,
# must start with a letter, must not start or end with a hyphen.
validate_kebab_case() {
  value="$1"
  label="$2"

  if ! echo "${value}" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
    echo "Invalid ${label} name '${value}': must be kebab-case (lowercase letters, digits, hyphens; start with letter; no leading/trailing/consecutive hyphens)" >&2
    return 1
  fi
  return 0
}

# Validates gate evidence filename: {from}-to-{to}.json
# Both {from} and {to} must be valid step names (kebab-case).
validate_gate_filename() {
  filename="$1"

  if ! echo "${filename}" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*-to-[a-z][a-z0-9]*(-[a-z0-9]+)*\.json$'; then
    echo "Invalid gate filename '${filename}': must match {from}-to-{to}.json pattern (e.g., plan-to-spec.json)" >&2
    return 1
  fi
  return 0
}

# Validates review filename: {deliverable}.json where deliverable is kebab-case.
validate_review_filename() {
  filename="$1"

  # Strip .json extension and validate the base name
  base="${filename%.json}"
  if [ "${base}" = "${filename}" ]; then
    echo "Invalid review filename '${filename}': must end with .json" >&2
    return 1
  fi

  if ! validate_kebab_case "${base}" "review deliverable"; then
    return 1
  fi
  return 0
}

# --- CLI interface ---

frw_validate_naming() {
  set -eu

  if [ "$#" -lt 2 ]; then
    echo "Usage: frw validate-naming <type> <value>" >&2
    echo "Types: row, deliverable, gate-file, review-file" >&2
    return 1
  fi

  type="$1"
  value="$2"

  case "${type}" in
    row)
      validate_kebab_case "${value}" "row"
      ;;
    deliverable)
      validate_kebab_case "${value}" "deliverable"
      ;;
    gate-file)
      validate_gate_filename "${value}"
      ;;
    review-file)
      validate_review_filename "${value}"
      ;;
    *)
      echo "Unknown type '${type}'. Expected: row, deliverable, gate-file, review-file" >&2
      return 1
      ;;
  esac
}
