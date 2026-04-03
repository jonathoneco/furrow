#!/bin/sh
# triage-todos.sh — Read todos.yaml and output dependency graph + file conflict data.
#
# Reads todos.yaml, builds a dependency graph from depends_on fields,
# assigns waves via topological sort, detects file conflicts between
# TODOs in the same wave, and outputs structured JSON.
#
# Usage: triage-todos.sh [path-to-todos.yaml]
#   path — path to todos.yaml (default: ./todos.yaml)
#
# Exit codes:
#   0 — success (JSON on stdout)
#   1 — usage error
#   2 — file not found
#   3 — validation error (dangling deps, cycles)

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- argument handling ---

todos_file="${1:-./todos.yaml}"

if [ ! -f "$todos_file" ]; then
  echo "Error: todos.yaml not found: $todos_file" >&2
  exit 2
fi

# --- check dependencies ---

for cmd in yq jq python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
done

# --- step 1: convert todos.yaml to JSON ---

todos_json="$(yq -o=json '.' "$todos_file" 2>/dev/null)" || {
  echo "Error: failed to parse todos.yaml" >&2
  exit 3
}

# --- step 2: filter active TODOs and build dependency graph ---

python_errors="$(mktemp)"
trap 'rm -f "$python_errors"' EXIT

graph_output="$(python3 -c "
import json, sys

todos = json.loads(sys.argv[1])

# Filter: only active and blocked TODOs (skip done, deferred)
active = [t for t in todos if t.get('status', 'active') not in ('done', 'deferred')]

if not active:
    # No active TODOs — output empty structure
    print(json.dumps({
        'todos': [],
        'graph': {'topo_order': [], 'waves': [], 'cycles': []},
        'conflicts': []
    }))
    sys.exit(0)

ids = {t['id'] for t in active}
# all_ids includes done/deferred — a dep on a done TODO is valid (satisfied),
# but a dep on a nonexistent ID is an error.
all_ids = {t['id'] for t in todos}
graph = {}

for t in active:
    tid = t['id']
    deps = t.get('depends_on') or []
    # Validate: deps must reference existing TODO IDs
    for dep in deps:
        if dep not in all_ids:
            print(f'Error: dangling dependency: {tid} depends on {dep} which does not exist', file=sys.stderr)
            sys.exit(1)
    # Only track deps that are also active (done deps are satisfied)
    active_deps = [d for d in deps if d in ids]
    graph[tid] = active_deps

# Build reverse graph
reverse = {n: [] for n in ids}
for node, deps in graph.items():
    for dep in deps:
        reverse[dep].append(node)

# Kahn's algorithm — topological sort with wave assignment
in_degree = {n: len(graph[n]) for n in ids}
queue = sorted([n for n in ids if in_degree[n] == 0])
topo_order = []

while queue:
    current = sorted(queue)
    queue = []
    for node in current:
        topo_order.append(node)
    for node in current:
        for dependent in reverse.get(node, []):
            in_degree[dependent] -= 1
            if in_degree[dependent] == 0:
                queue.append(dependent)

# Cycle detection
if len(topo_order) != len(ids):
    remaining = sorted(ids - set(topo_order))
    print(f'Error: dependency cycle involving: {\" -> \".join(remaining)}', file=sys.stderr)
    sys.exit(1)

# Assign wave numbers
wave_map = {}
for node in topo_order:
    deps = graph[node]
    if not deps:
        wave_map[node] = 1
    else:
        wave_map[node] = max(wave_map[dep] for dep in deps) + 1

# Build wave groups
max_wave = max(wave_map.values()) if wave_map else 0
waves = []
for w in range(1, max_wave + 1):
    wave_todos = sorted([n for n, wv in wave_map.items() if wv == w])
    waves.append({'wave': w, 'todos': wave_todos})

# Build todo output with triage data
todo_output = []
for t in active:
    tid = t['id']
    todo_output.append({
        'id': tid,
        'title': t.get('title', ''),
        'depends_on': t.get('depends_on') or [],
        'files_touched': t.get('files_touched') or [],
        'urgency': t.get('urgency'),
        'impact': t.get('impact'),
        'effort': t.get('effort'),
        'status': t.get('status', 'active')
    })

result = {
    'todos': todo_output,
    'graph': {
        'topo_order': topo_order,
        'waves': waves,
        'cycles': []
    }
}

print(json.dumps(result))
" "$todos_json" 2>"$python_errors")" || {
  cat "$python_errors" >&2
  exit 3
}

# Check for stderr output (warnings/errors from Python)
if [ -s "$python_errors" ]; then
  cat "$python_errors" >&2
  exit 3
fi

# Validate JSON output
if ! echo "$graph_output" | jq empty 2>/dev/null; then
  echo "Error: graph analysis produced invalid JSON" >&2
  exit 3
fi

# --- step 3: detect file conflicts between TODOs in the same wave ---

conflicts="$(echo "$graph_output" | jq '
  # For each wave, check all pairs of TODOs for file_touched overlap
  .graph.waves as $waves |
  .todos as $todos |

  # Build lookup: id -> files_touched
  ($todos | map({key: .id, value: .files_touched}) | from_entries) as $files |

  [
    $waves[] |
    .todos as $wave_todos |
    # Generate all pairs within this wave
    [range($wave_todos | length)] as $indices |
    $indices[] as $i |
    $indices[] as $j |
    select($i < $j) |
    $wave_todos[$i] as $a |
    $wave_todos[$j] as $b |
    $files[$a] as $files_a |
    $files[$b] as $files_b |
    # Skip if either has no files
    select(($files_a | length) > 0 and ($files_b | length) > 0) |
    # Check overlap: does any file in A match any glob in B or vice versa?
    [
      $files_a[] as $fa |
      $files_b[] as $fb |
      select(
        ($fa | test($fb | gsub("/$"; "/**") | gsub("\\*\\*"; "\u0000") | gsub("\\*"; "[^/]*") | gsub("\u0000"; ".*"))) or
        ($fb | test($fa | gsub("/$"; "/**") | gsub("\\*\\*"; "\u0000") | gsub("\\*"; "[^/]*") | gsub("\u0000"; ".*")))
      ) |
      ($fa, $fb)
    ] | unique as $overlaps |
    select(($overlaps | length) > 0) |
    {
      todo_a: $a,
      todo_b: $b,
      overlapping_files: $overlaps
    }
  ]
')"

# --- step 4: assemble final output ---

echo "$graph_output" | jq --argjson conflicts "$conflicts" '
  .conflicts = $conflicts
'

exit 0
