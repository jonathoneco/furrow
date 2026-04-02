#!/bin/sh
# generate-plan.sh — Generate plan.json from definition.yaml deliverables.
#
# Reads deliverables, validates specialist fields, builds a dependency graph,
# assigns waves via topological sort, and writes a validated plan.json.
#
# Usage: generate-plan.sh <name>
#   name — work unit name (kebab-case directory under .work/)
#
# Exit codes:
#   0 — plan.json written
#   1 — usage error
#   2 — definition.yaml not found
#   3 — validation error (missing specialist, cycle, etc.)

set -eu

# --- paths ---

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- argument validation ---

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>" >&2
  exit 1
fi

name="$1"
def_file="$HARNESS_ROOT/.work/${name}/definition.yaml"
plan_file="$HARNESS_ROOT/.work/${name}/plan.json"

if [ ! -f "$def_file" ]; then
  echo "Error: definition.yaml not found: $def_file" >&2
  exit 2
fi

# --- check dependencies ---

for cmd in yq jq python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
done

# --- step 1: read deliverables and check specialist field ---

missing_specialist="$(yq -r '
  [.deliverables[] | select(.specialist == null or .specialist == "")] |
  map(.name) | .[]
' "$def_file" 2>/dev/null)" || missing_specialist=""

if [ -n "$missing_specialist" ]; then
  echo "Error: deliverables missing specialist field:" >&2
  for d in $missing_specialist; do
    echo "  - $d" >&2
  done
  exit 3
fi

# --- step 2: build dependency graph and assign waves via Python ---

wave_assignments="$(python3 -c "
import json, subprocess, sys

# Parse definition.yaml via yq
result = subprocess.run(
    ['yq', '-o=json', '.', sys.argv[1]],
    capture_output=True, text=True
)
if result.returncode != 0:
    print('Error: failed to parse definition.yaml', file=sys.stderr)
    sys.exit(1)
data = json.loads(result.stdout)

deliverables = data.get('deliverables', [])
if not deliverables:
    print('Error: no deliverables found', file=sys.stderr)
    sys.exit(1)

names = [d['name'] for d in deliverables]
graph = {}       # node -> list of dependencies
reverse = {}     # node -> list of dependents
for d in deliverables:
    name = d['name']
    deps = d.get('depends_on') or []
    graph[name] = deps
    if name not in reverse:
        reverse[name] = []
    for dep in deps:
        if dep not in reverse:
            reverse[dep] = []
        reverse[dep].append(name)

# Topological sort with cycle detection (Kahn's algorithm)
in_degree = {n: len(graph[n]) for n in names}
queue = [n for n in names if in_degree[n] == 0]
topo_order = []
wave_map = {}

# Assign waves: BFS layered approach
# wave 1 = nodes with no deps, wave N = max(wave of deps) + 1
current_wave = []
next_queue = list(queue)

while next_queue:
    current_queue = sorted(next_queue)  # deterministic ordering
    next_queue = []
    for node in current_queue:
        topo_order.append(node)
    for node in current_queue:
        for dependent in reverse.get(node, []):
            in_degree[dependent] -= 1
            if in_degree[dependent] == 0:
                next_queue.append(dependent)

# Check for cycles
if len(topo_order) != len(names):
    remaining = set(names) - set(topo_order)
    print(f'Error: dependency cycle involving: {\" -> \".join(sorted(remaining))}', file=sys.stderr)
    sys.exit(1)

# Assign wave numbers based on dependency depth
wave_map = {}
for node in topo_order:
    deps = graph[node]
    if not deps:
        wave_map[node] = 1
    else:
        wave_map[node] = max(wave_map[dep] for dep in deps) + 1

# Output as JSON array
output = [{'wave': wave_map[n], 'deliverable': n} for n in topo_order]
print(json.dumps(output))
" "$def_file" 2>&1)" || {
  echo "Error: wave assignment failed" >&2
  echo "$wave_assignments" >&2
  exit 3
}

# Check if Python printed errors to stderr (exit code was still 0 but output is empty/invalid)
if ! echo "$wave_assignments" | jq empty 2>/dev/null; then
  echo "Error: wave assignment produced invalid JSON" >&2
  echo "$wave_assignments" >&2
  exit 3
fi

# --- step 3: build plan.json using jq ---

def_json="$(yq -o=json '.' "$def_file")"
created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

jq -n \
  --argjson waves "$wave_assignments" \
  --argjson def "$def_json" \
  --arg created_at "$created_at" \
  '
  # Build a lookup from deliverable name to its definition
  ($def.deliverables | map({key: .name, value: .}) | from_entries) as $del_map |

  # Group wave assignments by wave number
  ($waves | group_by(.wave)) as $groups |

  {
    waves: [
      $groups[] |
      (.[0].wave) as $w |
      [.[].deliverable] as $dels |
      {
        wave: $w,
        deliverables: $dels,
        assignments: (
          [$dels[] |
            . as $name |
            $del_map[$name] |
            {
              key: $name,
              value: {
                specialist: .specialist,
                file_ownership: (.file_ownership // []),
                skills: []
              }
            }
          ] | from_entries
        )
      }
    ],
    created_at: $created_at,
    created_by: "generate-plan"
  }
  ' > "$tmp_file"

# --- step 4: validate ---

# shellcheck source=../hooks/lib/validate.sh
. "$HARNESS_ROOT/hooks/lib/validate.sh"

if ! validate_plan_json "$tmp_file" "$def_file"; then
  echo "Error: generated plan.json failed validation" >&2
  exit 3
fi

# --- step 5: atomic write ---

mv "$tmp_file" "$plan_file"
trap - EXIT

echo "Plan written: $plan_file"
exit 0
