#!/bin/sh
# validate-naming.sh — Validate naming conventions for Furrow artifacts
#
#
# Usage:
#   validate-naming.sh row <name>
#   validate-naming.sh deliverable <name>
#   validate-naming.sh gate-file <filename>
#   validate-naming.sh review-file <filename>
#
# Designed to be sourced by other scripts for reuse:
#   . validate-naming.sh
#   validate_kebab_case "my-name" "row"

set -eu

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

# --- CLI interface (only runs when executed, not when sourced) ---

# Guard: if sourced, the caller sets their own main logic.
# When executed directly, $0 matches the script name.
case "${0##*/}" in
  validate-naming.sh)
    if [ "$#" -lt 2 ]; then
      echo "Usage: validate-naming.sh <type> <value>" >&2
      echo "Types: row, deliverable, gate-file, review-file" >&2
      exit 1
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
        exit 1
        ;;
    esac
    ;;
esac
