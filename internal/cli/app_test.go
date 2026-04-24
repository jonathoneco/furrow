package cli

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestRootHelp(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	app := New(&stdout, &stderr)
	code := app.Run(nil)
	if code != 0 {
		t.Fatalf("expected exit 0, got %d", code)
	}
	if !bytes.Contains(stdout.Bytes(), []byte("furrow — Go CLI surface draft")) {
		t.Fatalf("expected root help output, got %s", stdout.String())
	}
}

func TestAlmanacValidateJSON(t *testing.T) {
	t.Run("valid", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)

		code, payload, stderr := runJSONCommand(t, root, []string{"almanac", "validate", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		if payload["ok"] != true {
			t.Fatalf("expected ok=true, got %#v", payload["ok"])
		}
		data := payload["data"].(map[string]any)
		summary := data["summary"].(map[string]any)
		if summary["valid"] != true {
			t.Fatalf("expected valid=true, got %#v", summary["valid"])
		}
	})

	cases := []struct {
		name               string
		mutate             func(t *testing.T, root string)
		expectedCode       int
		expectedCodeString string
	}{
		{
			name: "duplicate todo id",
			mutate: func(t *testing.T, root string) {
				writeValidAlmanac(t, root)
				mustWrite(t, filepath.Join(root, ".furrow", "almanac", "todos.yaml"), `
- id: duplicate-id
  title: First
  context: One
  work_needed: One
  created_at: "2026-04-23T00:00:00Z"
  updated_at: "2026-04-23T00:00:00Z"
- id: duplicate-id
  title: Second
  context: Two
  work_needed: Two
  created_at: "2026-04-23T00:00:00Z"
  updated_at: "2026-04-23T00:00:00Z"
`)
			},
			expectedCode:       3,
			expectedCodeString: "duplicate_id",
		},
		{
			name: "dangling todo dependency",
			mutate: func(t *testing.T, root string) {
				writeValidAlmanac(t, root)
				mustWrite(t, filepath.Join(root, ".furrow", "almanac", "todos.yaml"), `
- id: root-task
  title: Root Task
  context: Testing
  work_needed: Do it
  created_at: "2026-04-23T00:00:00Z"
  updated_at: "2026-04-23T00:00:00Z"
  depends_on:
    - missing-task
`)
			},
			expectedCode:       3,
			expectedCodeString: "dangling_dependency",
		},
		{
			name: "malformed observation trigger",
			mutate: func(t *testing.T, root string) {
				writeValidAlmanac(t, root)
				mustWrite(t, filepath.Join(root, ".furrow", "almanac", "observations.yaml"), `
- id: bad-observation
  kind: watch
  title: Bad Observation
  triggered_by:
    type: rows_since
    since_row: missing-row
    count: 0
  lifecycle: open
  created_at: "2026-04-23T00:00:00Z"
  updated_at: "2026-04-23T00:00:00Z"
  signal: Check it
`)
			},
			expectedCode:       3,
			expectedCodeString: "invalid_count",
		},
		{
			name: "roadmap references missing todo",
			mutate: func(t *testing.T, root string) {
				writeValidAlmanac(t, root)
				mustWrite(t, filepath.Join(root, ".furrow", "almanac", "roadmap.yaml"), `
schema_version: "1.0"
metadata:
  project: furrow
  generated_at: "2026-04-23T00:00:00Z"
  total_phases: 1
  completed_phases: 0
dependency_graph:
  nodes:
    - id: missing-todo
      label: Missing Todo
      phase: 1
      status: active
  edges: []
  waves:
    - wave: 1
      todos: [missing-todo]
phases:
  - number: 1
    title: Test
    status: planned
    rationale: Test
    rows:
      - index: 1
        branch: work/test
        description: Test row
        todos: [missing-todo]
        key_files: []
        conflict_risk: low
        depends_on: []
        completed_at: null
deferred: []
handoff:
  template: "start"
`)
			},
			expectedCode:       3,
			expectedCodeString: "missing_todo",
		},
		{
			name: "roadmap references missing observation",
			mutate: func(t *testing.T, root string) {
				writeValidAlmanac(t, root)
				mustWrite(t, filepath.Join(root, ".furrow", "almanac", "roadmap.yaml"), `
schema_version: "1.0"
metadata:
  project: furrow
  generated_at: "2026-04-23T00:00:00Z"
  total_phases: 1
  completed_phases: 0
dependency_graph:
  nodes:
    - id: go-cli-contract
      label: Go CLI Contract
      phase: 1
      status: active
  edges: []
  waves:
    - wave: 1
      todos: [go-cli-contract]
phases:
  - number: 1
    title: Test
    status: planned
    rationale: Test
    rows:
      - index: 1
        branch: work/test
        description: Test row
        todos: [go-cli-contract]
        key_files: []
        conflict_risk: low
        depends_on: []
        completed_at: null
deferred: []
active_observations:
  - id: missing-observation
    kind: watch
    title: Missing Observation
    activation_reason: test
handoff:
  template: "start"
`)
			},
			expectedCode:       3,
			expectedCodeString: "missing_observation",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			root := setupFurrowRoot(t)
			tc.mutate(t, root)
			code, payload, stderr := runJSONCommand(t, root, []string{"almanac", "validate", "--json"})
			if code != tc.expectedCode {
				t.Fatalf("expected exit %d, got %d stderr=%s", tc.expectedCode, code, stderr)
			}
			if payload["ok"] != false {
				t.Fatalf("expected ok=false, got %#v", payload["ok"])
			}
			if !jsonContains(payload, tc.expectedCodeString) {
				t.Fatalf("expected payload to contain %q, got %s", tc.expectedCodeString, mustJSONPayload(t, payload))
			}
		})
	}
}

func TestRowListJSON(t *testing.T) {
	t.Run("empty rows", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		code, payload, stderr := runJSONCommand(t, root, []string{"row", "list", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		data := payload["data"].(map[string]any)
		rows := data["rows"].([]any)
		if len(rows) != 0 {
			t.Fatalf("expected 0 rows, got %d", len(rows))
		}
	})

	t.Run("archived rows included and focused reflected", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "active-row", map[string]any{
			"name": "active-row", "title": "Active Row", "step": "implement", "step_status": "in_progress", "updated_at": "2026-04-23T10:00:00Z", "archived_at": nil,
			"deliverables": map[string]any{"a": map[string]any{"status": "completed"}},
		})
		writeRowState(t, root, "archived-row", map[string]any{
			"name": "archived-row", "title": "Archived Row", "step": "review", "step_status": "completed", "updated_at": "2026-04-23T09:00:00Z", "archived_at": "2026-04-23T09:30:00Z",
			"deliverables": map[string]any{},
		})
		mustWrite(t, filepath.Join(root, ".furrow", ".focused"), "active-row\n")

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "list", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		data := payload["data"].(map[string]any)
		rows := data["rows"].([]any)
		if len(rows) != 2 {
			t.Fatalf("expected 2 rows, got %d", len(rows))
		}
		first := rows[0].(map[string]any)
		if first["name"] != "active-row" || first["focused"] != true {
			t.Fatalf("expected active focused row first, got %#v", first)
		}
	})

	t.Run("tolerates heterogeneous row state", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		mustMkdirAll(t, filepath.Join(root, ".furrow", "rows", "legacy-row"))
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "legacy-row", "state.json"), `{"name":"legacy-row","title":"Legacy","step":"review","step_status":"completed","updated_at":"2026-04-23T00:00:00Z","archived_at":"2026-04-23T00:00:01Z","deliverables":{"d1":{"status":"completed","wave":2,"corrections":0}}}`)

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "list", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		data := payload["data"].(map[string]any)
		rows := data["rows"].([]any)
		if len(rows) != 1 {
			t.Fatalf("expected 1 row, got %d", len(rows))
		}
		row := rows[0].(map[string]any)
		deliverables := row["deliverables"].(map[string]any)
		if deliverables["completed"].(float64) != 1 {
			t.Fatalf("expected completed count 1, got %#v", deliverables)
		}
	})
}

func TestRowStatusJSON(t *testing.T) {
	t.Run("explicit row", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "demo-row", map[string]any{
			"name":           "demo-row",
			"title":          "Demo Row",
			"description":    "Testing",
			"step":           "implement",
			"step_status":    "in_progress",
			"updated_at":     "2026-04-23T10:00:00Z",
			"archived_at":    nil,
			"mode":           "code",
			"branch":         "work/demo-row",
			"steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"},
			"deliverables": map[string]any{
				"one": map[string]any{"status": "completed", "wave": 1, "corrections": 0},
				"two": map[string]any{"status": "in_progress", "wave": 2, "corrections": 1},
			},
			"gates": []any{map[string]any{"boundary": "decompose->implement", "outcome": "pass", "decided_by": "manual", "timestamp": "2026-04-23T09:00:00Z"}},
		})

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "status", "demo-row", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		data := payload["data"].(map[string]any)
		resolution := data["resolution"].(map[string]any)
		if resolution["source"] != "explicit" {
			t.Fatalf("expected explicit resolution, got %#v", resolution)
		}
		row := data["row"].(map[string]any)
		if row["name"] != "demo-row" {
			t.Fatalf("expected demo-row, got %#v", row)
		}
		next := row["next_valid_transitions"].([]any)
		if len(next) != 1 {
			t.Fatalf("expected next transition, got %#v", next)
		}
	})

	t.Run("focused row", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "focused-row", map[string]any{"name": "focused-row", "title": "Focused", "step": "plan", "step_status": "in_progress", "updated_at": "2026-04-23T10:00:00Z", "archived_at": nil, "steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}, "deliverables": map[string]any{}})
		mustWrite(t, filepath.Join(root, ".furrow", ".focused"), "focused-row\n")
		code, payload, stderr := runJSONCommand(t, root, []string{"row", "status", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		data := payload["data"].(map[string]any)
		if data["resolution"].(map[string]any)["source"] != "focused" {
			t.Fatalf("expected focused resolution, got %#v", data["resolution"])
		}
	})

	t.Run("latest active fallback", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "older-row", map[string]any{"name": "older-row", "title": "Older", "step": "research", "step_status": "in_progress", "updated_at": "2026-04-23T09:00:00Z", "archived_at": nil, "steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}, "deliverables": map[string]any{}})
		writeRowState(t, root, "newer-row", map[string]any{"name": "newer-row", "title": "Newer", "step": "plan", "step_status": "in_progress", "updated_at": "2026-04-23T11:00:00Z", "archived_at": nil, "steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}, "deliverables": map[string]any{}})
		code, payload, stderr := runJSONCommand(t, root, []string{"row", "status", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		row := payload["data"].(map[string]any)["row"].(map[string]any)
		if row["name"] != "newer-row" {
			t.Fatalf("expected newer-row fallback, got %#v", row)
		}
	})

	t.Run("missing row", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		code, _, _ := runJSONCommand(t, root, []string{"row", "status", "missing-row", "--json"})
		if code != 5 {
			t.Fatalf("expected exit 5, got %d", code)
		}
	})

	t.Run("invalid json", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		mustMkdirAll(t, filepath.Join(root, ".furrow", "rows", "broken-row"))
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "broken-row", "state.json"), `{not-json}`)
		code, _, _ := runJSONCommand(t, root, []string{"row", "status", "broken-row", "--json"})
		if code != 3 {
			t.Fatalf("expected exit 3, got %d", code)
		}
	})
}

func TestRowTransitionJSON(t *testing.T) {
	t.Run("adjacent forward transition succeeds and preserves unknown fields", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "transition-row", map[string]any{
			"name":           "transition-row",
			"title":          "Transition Row",
			"step":           "plan",
			"step_status":    "completed",
			"updated_at":     "2026-04-23T10:00:00Z",
			"archived_at":    nil,
			"steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"},
			"deliverables":   map[string]any{},
			"gates":          []any{},
			"unknown_field":  "keep-me",
		})

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "transition", "transition-row", "--step", "spec", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		row := payload["data"].(map[string]any)["row"].(map[string]any)
		if row["previous_step"] != "plan" || row["step"] != "spec" {
			t.Fatalf("unexpected transition payload %#v", row)
		}
		state := readJSONFile(t, filepath.Join(root, ".furrow", "rows", "transition-row", "state.json"))
		if state["step"] != "spec" {
			t.Fatalf("expected persisted step spec, got %#v", state["step"])
		}
		if state["unknown_field"] != "keep-me" {
			t.Fatalf("expected unknown field preserved, got %#v", state["unknown_field"])
		}
		gates := state["gates"].([]any)
		if len(gates) != 1 {
			t.Fatalf("expected gate record written, got %#v", gates)
		}
	})

	t.Run("non adjacent blocked", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "blocked-row", map[string]any{"name": "blocked-row", "title": "Blocked", "step": "plan", "step_status": "completed", "updated_at": "2026-04-23T10:00:00Z", "archived_at": nil, "steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}, "deliverables": map[string]any{}, "gates": []any{}})
		code, _, _ := runJSONCommand(t, root, []string{"row", "transition", "blocked-row", "--step", "implement", "--json"})
		if code != 2 {
			t.Fatalf("expected exit 2, got %d", code)
		}
	})

	t.Run("archived row blocked", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "archived-row", map[string]any{"name": "archived-row", "title": "Archived", "step": "plan", "step_status": "completed", "updated_at": "2026-04-23T10:00:00Z", "archived_at": "2026-04-23T10:05:00Z", "steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}, "deliverables": map[string]any{}, "gates": []any{}})
		code, _, _ := runJSONCommand(t, root, []string{"row", "transition", "archived-row", "--step", "spec", "--json"})
		if code != 2 {
			t.Fatalf("expected exit 2, got %d", code)
		}
	})

	t.Run("malformed state", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		mustMkdirAll(t, filepath.Join(root, ".furrow", "rows", "malformed-row"))
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "malformed-row", "state.json"), `{"name":"malformed-row","title":"Malformed","step":"plan","step_status":"in_progress","updated_at":"2026-04-23T10:00:00Z","archived_at":null,"deliverables":{},"gates":[],"steps_sequence":"bad"}`)
		code, _, _ := runJSONCommand(t, root, []string{"row", "transition", "malformed-row", "--step", "spec", "--json"})
		if code != 3 {
			t.Fatalf("expected exit 3, got %d", code)
		}
	})

	t.Run("missing row", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		code, _, _ := runJSONCommand(t, root, []string{"row", "transition", "missing-row", "--step", "spec", "--json"})
		if code != 5 {
			t.Fatalf("expected exit 5, got %d", code)
		}
	})
}

func TestRowCompleteJSON(t *testing.T) {
	t.Run("completes step status and deliverables while preserving unknown fields", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "complete-row", map[string]any{
			"name":        "complete-row",
			"title":       "Complete Row",
			"step":        "review",
			"step_status": "not_started",
			"updated_at":  "2026-04-24T15:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"one": map[string]any{"status": "in_progress", "wave": 1, "corrections": 0, "assigned_to": "pi"},
				"two": map[string]any{"status": "not_started", "wave": 1, "corrections": 0},
			},
			"unknown_field": "keep-me",
		})

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "complete", "complete-row", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		data := payload["data"].(map[string]any)
		row := data["row"].(map[string]any)
		if row["step_status"] != "completed" {
			t.Fatalf("expected completed step status, got %#v", row)
		}
		deliverables := data["deliverables"].(map[string]any)
		if deliverables["updated"].(float64) != 2 {
			t.Fatalf("expected 2 deliverables updated, got %#v", deliverables)
		}

		state := readJSONFile(t, filepath.Join(root, ".furrow", "rows", "complete-row", "state.json"))
		if state["step_status"] != "completed" {
			t.Fatalf("expected persisted step_status completed, got %#v", state["step_status"])
		}
		if state["unknown_field"] != "keep-me" {
			t.Fatalf("expected unknown field preserved, got %#v", state["unknown_field"])
		}
		persistedDeliverables := state["deliverables"].(map[string]any)
		if persistedDeliverables["one"].(map[string]any)["status"] != "completed" {
			t.Fatalf("expected deliverable one completed, got %#v", persistedDeliverables["one"])
		}
		if persistedDeliverables["two"].(map[string]any)["status"] != "completed" {
			t.Fatalf("expected deliverable two completed, got %#v", persistedDeliverables["two"])
		}
	})

	t.Run("idempotent when already complete", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "already-complete", map[string]any{
			"name":        "already-complete",
			"title":       "Already Complete",
			"step":        "review",
			"step_status": "completed",
			"updated_at":  "2026-04-24T15:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"one": map[string]any{"status": "completed", "wave": 1},
			},
		})

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "complete", "already-complete", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		data := payload["data"].(map[string]any)
		if data["write_performed"] != false {
			t.Fatalf("expected no-op write_performed=false, got %#v", data["write_performed"])
		}
		if len(data["changed"].([]any)) != 0 {
			t.Fatalf("expected no changed fields, got %#v", data["changed"])
		}
		state := readJSONFile(t, filepath.Join(root, ".furrow", "rows", "already-complete", "state.json"))
		if state["updated_at"] != "2026-04-24T15:00:00Z" {
			t.Fatalf("expected unchanged updated_at, got %#v", state["updated_at"])
		}
	})

	t.Run("missing deliverables is tolerated", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "step-only", map[string]any{
			"name":        "step-only",
			"title":       "Step Only",
			"step":        "review",
			"step_status": "in_progress",
			"updated_at":  "2026-04-24T15:00:00Z",
			"archived_at": nil,
		})
		statePath := filepath.Join(root, ".furrow", "rows", "step-only", "state.json")
		state := readJSONFile(t, statePath)
		delete(state, "deliverables")
		payloadBytes, err := json.MarshalIndent(state, "", "  ")
		if err != nil {
			t.Fatal(err)
		}
		mustWrite(t, statePath, string(payloadBytes))

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "complete", "step-only", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		data := payload["data"].(map[string]any)
		if data["write_performed"] != true {
			t.Fatalf("expected write performed for step status, got %#v", data["write_performed"])
		}
		persisted := readJSONFile(t, statePath)
		if persisted["step_status"] != "completed" {
			t.Fatalf("expected step_status completed, got %#v", persisted["step_status"])
		}
	})

	t.Run("non-object deliverables blocked as invalid state", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "bad-deliverables", map[string]any{
			"name":         "bad-deliverables",
			"title":        "Bad Deliverables",
			"step":         "review",
			"step_status":  "in_progress",
			"updated_at":   "2026-04-24T15:00:00Z",
			"archived_at":  nil,
			"deliverables": []any{"bad"},
		})
		code, _, _ := runJSONCommand(t, root, []string{"row", "complete", "bad-deliverables", "--json"})
		if code != 3 {
			t.Fatalf("expected exit 3, got %d", code)
		}
	})

	t.Run("archived row blocked", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "archived-complete", map[string]any{
			"name":         "archived-complete",
			"title":        "Archived Complete",
			"step":         "review",
			"step_status":  "not_started",
			"updated_at":   "2026-04-24T15:00:00Z",
			"archived_at":  "2026-04-24T15:01:00Z",
			"deliverables": map[string]any{},
		})
		code, _, _ := runJSONCommand(t, root, []string{"row", "complete", "archived-complete", "--json"})
		if code != 2 {
			t.Fatalf("expected exit 2, got %d", code)
		}
	})
}

func TestRowInitFocusAndScaffoldJSON(t *testing.T) {
	t.Run("row init creates state and seed", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "init", "my-new-row", "--title", "My New Row", "--source-todo", "go-cli-contract", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		data := payload["data"].(map[string]any)
		row := data["row"].(map[string]any)
		if row["name"] != "my-new-row" {
			t.Fatalf("expected my-new-row, got %#v", row)
		}
		seed := data["seed"].(map[string]any)
		if seed["id"] == nil {
			t.Fatalf("expected linked seed, got %#v", seed)
		}
		state := readJSONFile(t, filepath.Join(root, ".furrow", "rows", "my-new-row", "state.json"))
		if state["seed_id"] == nil || state["seed_id"] == "" {
			t.Fatalf("expected persisted seed_id, got %#v", state["seed_id"])
		}
		todosBytes, err := os.ReadFile(filepath.Join(root, ".furrow", "almanac", "todos.yaml"))
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Contains(todosBytes, []byte("seed_id:")) {
			t.Fatalf("expected todo seed link backfill, got %s", string(todosBytes))
		}
	})

	t.Run("row focus set show and clear", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "focus-row", map[string]any{"name": "focus-row", "title": "Focus", "step": "plan", "step_status": "in_progress", "updated_at": "2026-04-24T18:00:00Z", "archived_at": nil, "deliverables": map[string]any{}})

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "focus", "focus-row", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		if payload["data"].(map[string]any)["focused_row"] != "focus-row" {
			t.Fatalf("expected focus-row, got %#v", payload)
		}
		focusedBytes, err := os.ReadFile(filepath.Join(root, ".furrow", ".focused"))
		if err != nil {
			t.Fatal(err)
		}
		if string(focusedBytes) != "focus-row\n" {
			t.Fatalf("expected .focused to contain focus-row, got %q", string(focusedBytes))
		}

		code, payload, stderr = runJSONCommand(t, root, []string{"row", "focus", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		if payload["data"].(map[string]any)["focused_row"] != "focus-row" {
			t.Fatalf("expected focus-row on readback, got %#v", payload)
		}

		code, payload, stderr = runJSONCommand(t, root, []string{"row", "focus", "--clear", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		if payload["data"].(map[string]any)["focused_row"] != nil {
			t.Fatalf("expected cleared focus, got %#v", payload)
		}
		if _, err := os.Stat(filepath.Join(root, ".furrow", ".focused")); !os.IsNotExist(err) {
			t.Fatalf("expected .focused removed, got err=%v", err)
		}
	})

	t.Run("scaffold creates incomplete current-step artifact and completion is blocked", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "scaffold-row", map[string]any{
			"name":             "scaffold-row",
			"title":            "Scaffold Row",
			"step":             "ideate",
			"step_status":      "in_progress",
			"updated_at":       "2026-04-24T18:00:00Z",
			"archived_at":      nil,
			"deliverables":     map[string]any{},
			"gates":            []any{},
			"gate_policy_init": "supervised",
		})

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "scaffold", "scaffold-row", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		created := payload["data"].(map[string]any)["created"].([]any)
		if len(created) != 1 {
			t.Fatalf("expected 1 created artifact, got %#v", created)
		}
		definitionBytes, err := os.ReadFile(filepath.Join(root, ".furrow", "rows", "scaffold-row", "definition.yaml"))
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Contains(definitionBytes, []byte(scaffoldMarker)) {
			t.Fatalf("expected scaffold marker in definition, got %s", string(definitionBytes))
		}

		code, payload, stderr = runJSONCommand(t, root, []string{"row", "status", "scaffold-row", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		if !jsonContains(payload, "artifact_scaffold_incomplete") {
			t.Fatalf("expected incomplete scaffold blocker, got %s", mustJSONPayload(t, payload))
		}

		code, _, _ = runJSONCommand(t, root, []string{"row", "complete", "scaffold-row", "--json"})
		if code != 2 {
			t.Fatalf("expected completion blocked with exit 2, got %d", code)
		}
	})

	t.Run("transition blocked by incomplete scaffold", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "transition-blocked", map[string]any{
			"name":             "transition-blocked",
			"title":            "Transition Blocked",
			"step":             "ideate",
			"step_status":      "completed",
			"updated_at":       "2026-04-24T18:00:00Z",
			"archived_at":      nil,
			"deliverables":     map[string]any{},
			"gates":            []any{},
			"gate_policy_init": "supervised",
		})
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "transition-blocked", "definition.yaml"), "# "+scaffoldMarker+"\nobjective: \"TODO\"\n")

		code, payload, _ := runJSONCommand(t, root, []string{"row", "transition", "transition-blocked", "--step", "research", "--json"})
		if code != 2 {
			t.Fatalf("expected exit 2, got %d", code)
		}
		if !jsonContains(payload, "artifact_scaffold_incomplete") {
			t.Fatalf("expected scaffold blocker in payload, got %s", mustJSONPayload(t, payload))
		}
	})
}

func TestDoctorJSON(t *testing.T) {
	t.Run("missing root", func(t *testing.T) {
		temp := t.TempDir()
		code, _, _ := runJSONCommand(t, temp, []string{"doctor", "--json"})
		if code != 5 {
			t.Fatalf("expected exit 5, got %d", code)
		}
	})

	t.Run("minimal valid root", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "active-row", map[string]any{"name": "active-row", "title": "Active", "step": "implement", "step_status": "in_progress", "updated_at": "2026-04-23T10:00:00Z", "archived_at": nil, "steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}, "deliverables": map[string]any{}, "gates": []any{}})
		code, payload, stderr := runJSONCommand(t, root, []string{"doctor", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		if payload["ok"] != true {
			t.Fatalf("expected ok=true, got %#v", payload["ok"])
		}
	})

	t.Run("invalid almanac fails", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "active-row", map[string]any{"name": "active-row", "title": "Active", "step": "implement", "step_status": "in_progress", "updated_at": "2026-04-23T10:00:00Z", "archived_at": nil, "steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}, "deliverables": map[string]any{}, "gates": []any{}})
		mustWrite(t, filepath.Join(root, ".furrow", "almanac", "todos.yaml"), `
- id: broken
  title: Broken
  context: Broken
  work_needed: Broken
  created_at: "2026-04-23T00:00:00Z"
  updated_at: "2026-04-23T00:00:00Z"
  depends_on: [missing]
`)
		code, payload, _ := runJSONCommand(t, root, []string{"doctor", "--json"})
		if code != 3 {
			t.Fatalf("expected exit 3, got %d", code)
		}
		if !jsonContains(payload, "almanac_validation") {
			t.Fatalf("expected doctor payload to mention almanac_validation, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("stale focused row is warning only", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "active-row", map[string]any{"name": "active-row", "title": "Active", "step": "implement", "step_status": "in_progress", "updated_at": "2026-04-23T10:00:00Z", "archived_at": nil, "steps_sequence": []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}, "deliverables": map[string]any{}, "gates": []any{}})
		mustWrite(t, filepath.Join(root, ".furrow", ".focused"), "missing-row\n")
		code, payload, stderr := runJSONCommand(t, root, []string{"doctor", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		if !jsonContains(payload, "warn") {
			t.Fatalf("expected warning in doctor payload, got %s", mustJSONPayload(t, payload))
		}
	})
}

func runJSONCommand(t *testing.T, dir string, args []string) (int, map[string]any, string) {
	t.Helper()
	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	app := New(&stdout, &stderr)
	code := app.Run(args)

	payload := map[string]any{}
	if stdout.Len() > 0 {
		if err := json.Unmarshal(stdout.Bytes(), &payload); err != nil {
			t.Fatalf("invalid json output: %v\n%s", err, stdout.String())
		}
	}
	return code, payload, stderr.String()
}

func setupFurrowRoot(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	mustMkdirAll(t, filepath.Join(root, ".furrow", "rows"))
	mustMkdirAll(t, filepath.Join(root, ".furrow", "almanac"))
	mustMkdirAll(t, filepath.Join(root, ".furrow", "seeds"))
	mustWrite(t, filepath.Join(root, ".furrow", "seeds", "config"), "furrow\n")
	mustWrite(t, filepath.Join(root, ".furrow", "seeds", "seeds.jsonl"), "")
	mustWrite(t, filepath.Join(root, ".furrow", "seeds", ".lock"), "")
	return root
}

func writeValidAlmanac(t *testing.T, root string) {
	t.Helper()
	mustWrite(t, filepath.Join(root, ".furrow", "almanac", "todos.yaml"), `
- id: go-cli-contract
  title: Go CLI Contract
  context: Contract work
  work_needed: Implement the contract
  created_at: "2026-04-23T00:00:00Z"
  updated_at: "2026-04-23T00:00:00Z"
  status: active
- id: row-status
  title: Row Status
  context: Row status work
  work_needed: Implement row status
  created_at: "2026-04-23T00:00:00Z"
  updated_at: "2026-04-23T00:00:00Z"
  status: active
  depends_on:
    - go-cli-contract
`)
	mustWrite(t, filepath.Join(root, ".furrow", "almanac", "observations.yaml"), `
- id: re-evaluate-dispatch
  kind: watch
  title: Re-evaluate dispatch
  triggered_by:
    type: manual
  lifecycle: open
  created_at: "2026-04-23T00:00:00Z"
  updated_at: "2026-04-23T00:00:00Z"
  signal: Check whether dispatch works
`)
	mustWrite(t, filepath.Join(root, ".furrow", "almanac", "roadmap.yaml"), `
schema_version: "1.0"
metadata:
  project: furrow
  generated_at: "2026-04-23T00:00:00Z"
  total_phases: 1
  completed_phases: 0
dependency_graph:
  nodes:
    - id: go-cli-contract
      label: Go CLI Contract
      phase: 1
      status: active
    - id: row-status
      label: Row Status
      phase: 1
      status: active
  edges:
    - from: row-status
      to: go-cli-contract
      kind: hard
      reason: explicit depends_on
  waves:
    - wave: 1
      todos:
        - go-cli-contract
phases:
  - number: 1
    title: Backend slice
    status: planned
    rationale: Initial phase
    rows:
      - index: 1
        branch: work/backend-slice
        description: Implement backend slice
        todos:
          - go-cli-contract
          - row-status
        key_files:
          - internal/cli/app.go
        conflict_risk: low
        depends_on: []
        completed_at: null
deferred: []
active_observations:
  - id: re-evaluate-dispatch
    kind: watch
    title: Re-evaluate dispatch
    activation_reason: manual
handoff:
  template: "Start with: /work"
`)
}

func writeRowState(t *testing.T, root, name string, state map[string]any) {
	t.Helper()
	mustMkdirAll(t, filepath.Join(root, ".furrow", "rows", name))
	if _, ok := state["steps_sequence"]; !ok {
		state["steps_sequence"] = []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
	}
	if _, ok := state["deliverables"]; !ok {
		state["deliverables"] = map[string]any{}
	}
	payload, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	mustWrite(t, filepath.Join(root, ".furrow", "rows", name, "state.json"), string(payload))
}

func readJSONFile(t *testing.T, path string) map[string]any {
	t.Helper()
	payload, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var out map[string]any
	if err := json.Unmarshal(payload, &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func mustJSONPayload(t *testing.T, payload map[string]any) string {
	t.Helper()
	out, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	return string(out)
}

func jsonContains(payload map[string]any, needle string) bool {
	blob, _ := json.Marshal(payload)
	return bytes.Contains(blob, []byte(needle))
}

func mustMkdirAll(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(path, 0o755); err != nil {
		t.Fatal(err)
	}
}

func mustWrite(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
