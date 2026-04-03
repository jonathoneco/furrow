# Spec: triage-script

## Interface Contract
- **Input**: Path to `todos.yaml` (default: `./todos.yaml`)
- **Output**: JSON to stdout
- **Exit codes**: 0 (success), 1 (usage error), 2 (file not found), 3 (validation/cycle error)

## Usage

```
scripts/triage-todos.sh [path-to-todos.yaml]
```

## Output Format

```json
{
  "todos": [
    {
      "id": "auto-advance-enforcement",
      "title": "Auto-Advance Enforcement",
      "depends_on": [],
      "files_touched": ["scripts/auto-advance.sh", "commands/lib/auto-advance.sh"],
      "urgency": "medium",
      "impact": "medium",
      "effort": "medium",
      "status": "active",
      "phase": 1
    }
  ],
  "graph": {
    "topo_order": ["id1", "id2", "id3"],
    "waves": [
      { "wave": 1, "todos": ["id1", "id2"] },
      { "wave": 2, "todos": ["id3"] }
    ],
    "cycles": []
  },
  "conflicts": [
    {
      "todo_a": "id1",
      "todo_b": "id2",
      "overlapping_files": ["scripts/foo.sh"]
    }
  ]
}
```

## Algorithm

### Step 1: Read and parse
- Read todos.yaml via `yq -o=json '.'`
- Extract id, depends_on, files_touched, status for each TODO
- Filter out `done` and `deferred` status entries (only active/blocked proceed)

### Step 2: Dependency graph (Python subprocess)
Adapted from generate-plan.sh lines 66-137:
- Build adjacency list from `depends_on` arrays
- Validate all depends_on references exist (error if dangling)
- Kahn's algorithm: BFS layered wave assignment
- `wave(node) = max(wave(deps)) + 1`, wave 1 for no-dep nodes
- Cycle detection: compare topo-sort output length to input count
- Output: topo_order, waves array, cycles array

### Step 3: File conflict detection (jq)
Adapted from check-wave-conflicts.sh:
- For each pair of TODOs in the same wave, compare files_touched globs
- Glob-to-regex: `gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*")`
- If any file in todo_a matches any glob in todo_b (or vice versa), record conflict
- Output: array of conflict objects

### Step 4: Assemble output
- Combine all data into the output JSON structure via jq

## Edge Cases
- TODOs with empty or missing `depends_on`: treated as wave 1 (no dependencies)
- TODOs with empty or missing `files_touched`: excluded from conflict detection
- All TODOs done/deferred: output empty arrays, exit 0
- Dangling depends_on reference: error message to stderr, exit 3
- Dependency cycle: report cycle members to stderr, exit 3

## Acceptance Criteria
1. Reads todos.yaml and outputs valid JSON to stdout
2. Topological sort correctly assigns waves based on depends_on
3. Detects file conflicts between TODOs in the same wave
4. Reports cycles to stderr and exits 3
5. Reports dangling depends_on references to stderr and exits 3
6. Handles missing optional fields (depends_on, files_touched) gracefully
7. Filters out done/deferred status TODOs

## Implementation Notes
- Use POSIX sh outer shell, Python3 subprocess for graph ops (matches generate-plan.sh pattern)
- jq for JSON assembly and file conflict detection
- yq for YAML-to-JSON conversion
- mktemp + trap cleanup for temp files
