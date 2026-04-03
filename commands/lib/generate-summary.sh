#!/bin/sh
# generate-summary.sh — Generate summary.md skeleton from state and definition
#
# Usage: generate-summary.sh <name> [--auto-advance <evidence>]
#   name     — row name
#   When --auto-advance is passed, agent-written sections are auto-filled.
#
# Produces the skeleton sections; preserves existing agent-written sections
# unless --auto-advance is set.
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — state.json not found

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: generate-summary.sh <name> [--auto-advance <evidence>]" >&2
  exit 1
fi

name="$1"
auto_advance=""
auto_evidence=""

shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --auto-advance)
      auto_advance="true"
      auto_evidence="${2:-Step was trivially resolved}"
      shift 2 || shift 1
      ;;
    *) shift ;;
  esac
done

# --- delegate to existing regenerate-summary.sh for skeleton ---

script_dir="$(cd "$(dirname "$0")" && pwd)"
furrow_root="$(cd "${script_dir}/../.." && pwd)"

work_dir=".furrow/rows/${name}"
state_file="${work_dir}/state.json"
summary_file="${work_dir}/summary.md"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# Generate the skeleton using the existing script
"${furrow_root}/scripts/regenerate-summary.sh" "${name}"

# --- if auto-advance, overwrite agent sections with auto-generated content ---

if [ "${auto_advance}" = "true" ] && [ -f "${summary_file}" ]; then
  tmp_file="${summary_file}.tmp.$$"

  # Replace agent-written sections with auto-generated content
  awk -v evidence="${auto_evidence}" '
    /^## Key Findings/ {
      print "## Key Findings"
      print "Step auto-advanced: " evidence
      print "No manual investigation was needed."
      skip = 1
      next
    }
    /^## Open Questions/ {
      print "## Open Questions"
      print "None -- step was trivially resolved."
      print "All context carries forward from previous step."
      skip = 1
      next
    }
    /^## Recommendations/ {
      print "## Recommendations"
      print "Proceed with next step using existing artifacts."
      print "No additional preparation needed."
      skip = 1
      next
    }
    /^## / { skip = 0 }
    !skip { print }
  ' "${summary_file}" > "${tmp_file}"

  mv "${tmp_file}" "${summary_file}"
fi

echo "Summary generated: ${summary_file}"
