package cli

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
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

func TestHelpLabelsReservedStubSurfaces(t *testing.T) {
	tests := []struct {
		name    string
		args    []string
		want    []string
		mustNot []string
	}{
		{
			name: "root",
			args: nil,
			want: []string{
				"Reserved command names:",
				"gate      Reserved for future gate orchestration; unimplemented",
				"seeds     Reserved for future seed/task primitives; unimplemented",
				"merge     Reserved for future merge pipeline; unimplemented",
			},
			mustNot: []string{
				"gate      Gate orchestration contract surface",
				"seeds     Seed/task primitive contract surface",
				"merge     Merge pipeline contract surface",
			},
		},
		{
			name: "stub group",
			args: []string{"gate"},
			want: []string{
				"Reserved command group: unimplemented in the Go CLI",
				"Reserved subcommand names: run, evaluate, status, list",
			},
		},
		{
			name: "row",
			args: []string{"row", "help"},
			want: []string{
				"Reserved row subcommands:",
				"checkpoint, summary, validate are compatibility names only",
			},
			mustNot: []string{
				"furrow row checkpoint ...",
				"furrow row summary ...",
				"furrow row validate ...",
			},
		},
		{
			name: "review",
			args: []string{"review", "help"},
			want: []string{
				"Reserved review subcommands:",
				"run, cross-model are compatibility names only",
			},
			mustNot: []string{
				"furrow review run ...",
				"furrow review cross-model ...",
			},
		},
		{
			name: "almanac",
			args: []string{"almanac", "help"},
			want: []string{
				"Available subcommands: validate",
				"Reserved almanac subcommands:",
				"todos, roadmap, rationale are compatibility names only",
			},
			mustNot: []string{
				"Available subcommands: validate, todos, roadmap, rationale",
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			app := New(&stdout, &stderr)
			code := app.Run(tc.args)
			if code != 0 {
				t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr.String())
			}
			for _, want := range tc.want {
				if !bytes.Contains(stdout.Bytes(), []byte(want)) {
					t.Fatalf("expected help to contain %q, got:\n%s", want, stdout.String())
				}
			}
			for _, forbidden := range tc.mustNot {
				if bytes.Contains(stdout.Bytes(), []byte(forbidden)) {
					t.Fatalf("help advertises stub as live with %q:\n%s", forbidden, stdout.String())
				}
			}
		})
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
		writeImplementationPlan(t, root, "transition-row", "# Implementation Plan\n\n## Objective\n- Keep the backend authoritative.\n\n## Planned work\n1. Harden validation.\n2. Emit checkpoint evidence.\n")

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
		if _, err := os.Stat(filepath.Join(root, ".furrow", "rows", "transition-row", "gates", "plan-to-spec.json")); err != nil {
			t.Fatalf("expected checkpoint evidence file, got err=%v", err)
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
			"step":        "plan",
			"step_status": "not_started",
			"updated_at":  "2026-04-24T15:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"one": map[string]any{"status": "in_progress", "wave": 1, "corrections": 0, "assigned_to": "pi"},
				"two": map[string]any{"status": "not_started", "wave": 1, "corrections": 0},
			},
			"unknown_field": "keep-me",
		})

		writeImplementationPlan(t, root, "complete-row", "# Implementation Plan\n\n## Objective\n- Ship the change\n\n## Planned work\n1. Complete the deliverables\n")

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
			"step":        "plan",
			"step_status": "completed",
			"updated_at":  "2026-04-24T15:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"one": map[string]any{"status": "completed", "wave": 1},
			},
		})

		writeImplementationPlan(t, root, "already-complete", "# Implementation Plan\n\n## Objective\n- Already complete\n\n## Planned work\n1. No changes needed\n")

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
			"step":        "plan",
			"step_status": "in_progress",
			"updated_at":  "2026-04-24T15:00:00Z",
			"archived_at": nil,
		})
		writeImplementationPlan(t, root, "step-only", "# Implementation Plan\n\n## Objective\n- Step-only bookkeeping\n\n## Planned work\n1. Mark the step complete\n")
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
			"step":         "plan",
			"step_status":  "in_progress",
			"updated_at":   "2026-04-24T15:00:00Z",
			"archived_at":  nil,
			"deliverables": []any{"bad"},
		})
		writeImplementationPlan(t, root, "bad-deliverables", "# Implementation Plan\n\n## Objective\n- Validate bad deliverables handling\n\n## Planned work\n1. Trigger invalid state\n")
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
		if _, ok := state["source_todo"]; ok {
			t.Fatalf("did not expect legacy source_todo write, got %#v", state["source_todo"])
		}
		sourceTodos, ok := state["source_todos"].([]any)
		if !ok || len(sourceTodos) != 1 || sourceTodos[0] != "go-cli-contract" {
			t.Fatalf("expected canonical source_todos write, got %#v", state["source_todos"])
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

	t.Run("plan artifact validation failure blocks completion", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "plan-validation-row", map[string]any{
			"name":             "plan-validation-row",
			"title":            "Plan Validation Row",
			"step":             "plan",
			"step_status":      "in_progress",
			"updated_at":       "2026-04-24T18:00:00Z",
			"archived_at":      nil,
			"deliverables":     map[string]any{},
			"gates":            []any{},
			"gate_policy_init": "supervised",
		})
		writeImplementationPlan(t, root, "plan-validation-row", "# Implementation Plan\n\n## Objective\n- TODO\n\n## Planned work\n1. TODO\n")

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "status", "plan-validation-row", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s", code, stderr)
		}
		if !jsonContains(payload, "artifact_validation_failed") {
			t.Fatalf("expected artifact validation blocker, got %s", mustJSONPayload(t, payload))
		}

		code, _, _ = runJSONCommand(t, root, []string{"row", "complete", "plan-validation-row", "--json"})
		if code != 2 {
			t.Fatalf("expected completion blocked with exit 2, got %d", code)
		}
	})

	t.Run("archive succeeds with review gate evidence", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "archive-row", map[string]any{
			"name":        "archive-row",
			"title":       "Archive Row",
			"step":        "review",
			"step_status": "completed",
			"updated_at":  "2026-04-24T18:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"one": map[string]any{"status": "completed"},
			},
			"gates": []any{
				map[string]any{"boundary": "implement->review", "outcome": "pass", "decided_by": "manual", "timestamp": "2026-04-24T17:59:00Z"},
			},
			"source_todos": []any{"go-cli-contract"},
		})
		writeReviewArtifact(t, root, "archive-row", "one", `{"deliverable":"one","phase_a":{"verdict":"pass"},"phase_b":{"verdict":"pass"},"overall":"pass","timestamp":"2026-04-24T18:01:00Z"}`)

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "archive", "archive-row", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		data := payload["data"].(map[string]any)
		row := data["row"].(map[string]any)
		if row["archived"] != true {
			t.Fatalf("expected archived=true, got %#v", row)
		}
		archiveCeremony, ok := data["archive_ceremony"].(map[string]any)
		if !ok {
			t.Fatalf("expected archive_ceremony in response, got %s", mustJSONPayload(t, payload))
		}
		review := archiveCeremony["review"].(map[string]any)
		if required, _ := review["required"].(float64); required != 1 {
			t.Fatalf("expected one review artifact, got %#v", review)
		}
		sourceTodos := archiveCeremony["source_todos"].(map[string]any)
		if present, _ := sourceTodos["present"].(bool); !present {
			t.Fatalf("expected source_todos evidence to be present, got %#v", sourceTodos)
		}
		state := readJSONFile(t, filepath.Join(root, ".furrow", "rows", "archive-row", "state.json"))
		if archivedAt, _ := state["archived_at"].(string); archivedAt == "" {
			t.Fatalf("expected archived_at set, got %#v", state["archived_at"])
		}
		if _, err := os.Stat(filepath.Join(root, ".furrow", "rows", "archive-row", "gates", "review-to-archive.json")); err != nil {
			t.Fatalf("expected archive checkpoint evidence file, got err=%v", err)
		}
	})

	t.Run("completion-evidence archive blocks missing evidence artifacts", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "evidence-missing", completionEvidenceReviewState("evidence-missing"))
		writeReviewArtifact(t, root, "evidence-missing", "one", passingCompletionEvidenceReviewJSON())

		code, payload, _ := runJSONCommand(t, root, []string{"row", "archive", "evidence-missing", "--json"})
		if code != 2 {
			t.Fatalf("expected archive blocked with exit 2, got %d", code)
		}
		if !jsonContains(payload, "missing_required_artifact") || !jsonContains(payload, "ask-analysis") || !jsonContains(payload, "completion-check") {
			t.Fatalf("expected missing completion evidence artifact blockers, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("completion-evidence scaffold creates claim surfaces and follow-ups artifacts", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "truth-scaffold", completionEvidenceReviewState("truth-scaffold"))
		writeReviewArtifact(t, root, "truth-scaffold", "one", passingCompletionEvidenceReviewJSON())

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "scaffold", "truth-scaffold", "--json"})
		if code != 0 {
			t.Fatalf("expected scaffold success, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		if !jsonContains(payload, "claim-surfaces") || !jsonContains(payload, "follow-ups") {
			t.Fatalf("expected claim-surfaces and follow-ups scaffolds, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("completion-evidence archive blocks claim-blocking follow-up", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "claim-blocked", completionEvidenceReviewState("claim-blocked"))
		writeReviewArtifact(t, root, "claim-blocked", "one", passingCompletionEvidenceReviewJSON())
		writeCompletionEvidenceArtifacts(t, root, "claim-blocked", "complete")
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "claim-blocked", "follow-ups.yaml"), `
follow_ups:
  - claim_affected: "archive honestly represents the real ask"
    deferral_class: required_for_truth
    truth_impact: blocks_claim
    defer_reason: "critical behavior remains unimplemented"
    graduation_trigger: "implement the missing runtime path"
`)

		code, payload, _ := runJSONCommand(t, root, []string{"row", "archive", "claim-blocked", "--json"})
		if code != 2 {
			t.Fatalf("expected archive blocked with exit 2, got %d", code)
		}
		if !jsonContains(payload, "truth_gate_blocked") || !jsonContains(payload, "expand work, downgrade claim, or mark row incomplete") {
			t.Fatalf("expected claim-blocking deferral blocker, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("completion-evidence archive blocks claim-surface skip counted as pass", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "claim-surface-skip", completionEvidenceReviewState("claim-surface-skip"))
		writeReviewArtifact(t, root, "claim-surface-skip", "one", passingCompletionEvidenceReviewJSON())
		writeCompletionEvidenceArtifacts(t, root, "claim-surface-skip", "complete")
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "claim-surface-skip", "test-plan.md"), validCompletionEvidenceTestPlan("Skipped adapter parity test counts as pass."))

		code, payload, _ := runJSONCommand(t, root, []string{"row", "archive", "claim-surface-skip", "--json"})
		if code != 2 {
			t.Fatalf("expected archive blocked with exit 2, got %d", code)
		}
		if !jsonContains(payload, "claim_surface_parity_skip_as_pass") {
			t.Fatalf("expected claim-surface parity blocker, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("completion-evidence archive blocks structured claim surface bypass", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "claim-surface-structured", completionEvidenceReviewState("claim-surface-structured"))
		writeReviewArtifact(t, root, "claim-surface-structured", "one", passingCompletionEvidenceReviewJSON())
		writeCompletionEvidenceArtifacts(t, root, "claim-surface-structured", "complete")
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "claim-surface-structured", "claim-surfaces.yaml"), `
claim_surfaces:
  - name: adapter parity
    claim: Claude and Pi expose equivalent archive behavior.
    equivalence_claim: true
    surfaces:
      - name: Claude command
        status: passed
        evidence_type: integration
        evidence_path: tests/integration/claude-archive.sh
      - name: Pi command
        status: missing
        evidence_type: runtime-loaded-entrypoint
        evidence_path: adapters/pi/furrow.test.ts
`)

		code, payload, _ := runJSONCommand(t, root, []string{"row", "archive", "claim-surface-structured", "--json"})
		if code != 2 {
			t.Fatalf("expected archive blocked with exit 2, got %d", code)
		}
		if !jsonContains(payload, "claim_surface_not_evidence") || !jsonContains(payload, "claim_surface_equivalence_not_proven") {
			t.Fatalf("expected structured claim-surface blockers, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("completion-evidence archive blocks invalid row-local follow-ups artifact", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "follow-ups-invalid", completionEvidenceReviewState("follow-ups-invalid"))
		writeReviewArtifact(t, root, "follow-ups-invalid", "one", passingCompletionEvidenceReviewJSON())
		writeCompletionEvidenceArtifacts(t, root, "follow-ups-invalid", "complete")
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "follow-ups-invalid", "follow-ups.yaml"), `
follow_ups:
  - claim_affected: "archive honestly represents the real ask"
`)

		code, payload, _ := runJSONCommand(t, root, []string{"row", "archive", "follow-ups-invalid", "--json"})
		if code != 2 {
			t.Fatalf("expected archive blocked with exit 2, got %d", code)
		}
		if !jsonContains(payload, "follow_up_classification_incomplete") {
			t.Fatalf("expected follow-up classification blocker, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("completion-evidence archive blocks downgraded claim without wording change", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "downgrade-no-wording", completionEvidenceReviewState("downgrade-no-wording"))
		writeReviewArtifact(t, root, "downgrade-no-wording", "one", passingCompletionEvidenceReviewJSON())
		writeCompletionEvidenceArtifacts(t, root, "downgrade-no-wording", "complete-with-downgraded-claim")
		initGitRepo(t, root)

		code, payload, _ := runJSONCommand(t, root, []string{"row", "archive", "downgrade-no-wording", "--json"})
		if code != 2 {
			t.Fatalf("expected archive blocked with exit 2, got %d", code)
		}
		if !jsonContains(payload, "requires summary, roadmap, or docs wording changes") {
			t.Fatalf("expected downgraded wording-change blocker, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("completion-evidence archive allows downgraded claim with summary wording change", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "downgrade-with-summary", completionEvidenceReviewState("downgrade-with-summary"))
		writeReviewArtifact(t, root, "downgrade-with-summary", "one", passingCompletionEvidenceReviewJSON())
		writeCompletionEvidenceArtifacts(t, root, "downgrade-with-summary", "complete-with-downgraded-claim")
		initGitRepo(t, root)
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "downgrade-with-summary", "summary.md"), "Claim downgraded: runtime parity is not claimed.\n")

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "archive", "downgrade-with-summary", "--json"})
		if code != 0 {
			t.Fatalf("expected archive success, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
	})

	t.Run("completion-evidence archive allows outside-scope follow-up and surfaces PR prep", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "evidence-allowed", completionEvidenceReviewState("evidence-allowed"))
		writeReviewArtifact(t, root, "evidence-allowed", "one", passingCompletionEvidenceReviewJSON())
		writeCompletionEvidenceArtifacts(t, root, "evidence-allowed", "complete")
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "evidence-allowed", "follow-ups.yaml"), `
follow_ups:
  - claim_affected: "future polish"
    deferral_class: outside_scope
    truth_impact: none
    defer_reason: "not part of the real ask"
    graduation_trigger: "user requests polish"
`)

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "archive", "evidence-allowed", "--json"})
		if code != 0 {
			t.Fatalf("expected archive success, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		data := payload["data"].(map[string]any)
		archiveCeremony := data["archive_ceremony"].(map[string]any)
		if _, ok := archiveCeremony["pr_prep"].(map[string]any); !ok {
			t.Fatalf("expected pr_prep in archive ceremony, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("archive blocked without passing review gate", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "archive-blocked", map[string]any{
			"name":         "archive-blocked",
			"title":        "Archive Blocked",
			"step":         "review",
			"step_status":  "completed",
			"updated_at":   "2026-04-24T18:00:00Z",
			"archived_at":  nil,
			"deliverables": map[string]any{},
			"gates":        []any{},
		})

		code, payload, _ := runJSONCommand(t, root, []string{"row", "status", "archive-blocked", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d", code)
		}
		if !jsonContains(payload, "archive_requires_review_gate") {
			t.Fatalf("expected archive blocker in status, got %s", mustJSONPayload(t, payload))
		}

		code, _, _ = runJSONCommand(t, root, []string{"row", "archive", "archive-blocked", "--json"})
		if code != 2 {
			t.Fatalf("expected archive blocked with exit 2, got %d", code)
		}
	})

	t.Run("row init tolerates historical duplicate todo keys", func(t *testing.T) {
		root := setupFurrowRoot(t)
		mustWrite(t, filepath.Join(root, ".furrow", "almanac", "todos.yaml"), `
- id: work-loop-boundary-hardening
  title: Work loop boundary hardening
  context: active todo
  work_needed: keep hardening boundaries
  created_at: "2026-04-24T00:00:00Z"
  updated_at: "2026-04-24T00:00:00Z"
  status: active
  updated_at: "2026-04-24T01:00:00Z"
`)
		mustWrite(t, filepath.Join(root, ".furrow", "almanac", "observations.yaml"), "[]\n")
		mustWrite(t, filepath.Join(root, ".furrow", "almanac", "roadmap.yaml"), "schema_version: \"1.0\"\nmetadata:\n  project: furrow\n")

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "init", "review-archive-boundary-hardening", "--title", "Review archive boundary hardening", "--source-todo", "work-loop-boundary-hardening", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		state := readJSONFile(t, filepath.Join(root, ".furrow", "rows", "review-archive-boundary-hardening", "state.json"))
		if _, ok := state["source_todo"]; ok {
			t.Fatalf("did not expect legacy source_todo write, got %#v", state["source_todo"])
		}
		sourceTodos, ok := state["source_todos"].([]any)
		if !ok || len(sourceTodos) != 1 || sourceTodos[0] != "work-loop-boundary-hardening" {
			t.Fatalf("expected persisted source_todos, got %#v", state["source_todos"])
		}
	})

	t.Run("implement status validates carried plan artifact", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "implement-validation", map[string]any{
			"name":        "implement-validation",
			"title":       "Implement Validation",
			"step":        "implement",
			"step_status": "in_progress",
			"updated_at":  "2026-04-24T18:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"backend": map[string]any{"status": "in_progress"},
				"adapter": map[string]any{"status": "not_started"},
			},
			"gates": []any{},
		})
		mustWrite(t, filepath.Join(root, ".furrow", "rows", "implement-validation", "plan.json"), `{"waves":[],"assignments":{}}`)

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "status", "implement-validation", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		if jsonContains(payload, "missing_required_artifact") {
			t.Fatalf("did not expect retired team-plan missing blocker, got %s", mustJSONPayload(t, payload))
		}
		if !jsonContains(payload, "artifact_validation_failed") {
			t.Fatalf("expected carried plan artifact blocker, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("review status blocks archive on failing review artifact", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "review-validation", map[string]any{
			"name":        "review-validation",
			"title":       "Review Validation",
			"step":        "review",
			"step_status": "completed",
			"updated_at":  "2026-04-24T18:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"backend": map[string]any{"status": "completed"},
			},
			"gates": []any{
				map[string]any{"boundary": "implement->review", "outcome": "pass", "decided_by": "manual", "timestamp": "2026-04-24T17:59:00Z"},
			},
		})
		writeReviewArtifact(t, root, "review-validation", "backend", `{"deliverable":"backend","phase_a":{"verdict":"pass"},"phase_b":{"verdict":"fail"},"overall":"fail","timestamp":"2026-04-24T18:01:00Z"}`)

		code, payload, stderr := runJSONCommand(t, root, []string{"row", "status", "review-validation", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		if !jsonContains(payload, "review_verdict_not_passing") || !jsonContains(payload, "archive_ceremony") {
			t.Fatalf("expected review validation surfaced in checkpoint, got %s", mustJSONPayload(t, payload))
		}

		code, _, _ = runJSONCommand(t, root, []string{"row", "archive", "review-validation", "--json"})
		if code != 2 {
			t.Fatalf("expected archive blocked with exit 2, got %d", code)
		}
	})

	t.Run("review status summarizes synthesized overrides and follow ups", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "review-summary", map[string]any{
			"name":        "review-summary",
			"title":       "Review Summary",
			"step":        "review",
			"step_status": "completed",
			"updated_at":  "2026-04-24T18:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"backend": map[string]any{"status": "completed"},
			},
			"gates": []any{
				map[string]any{"boundary": "implement->review", "outcome": "pass", "decided_by": "manual", "timestamp": "2026-04-24T17:59:00Z"},
			},
		})
		writeReviewArtifact(t, root, "review-summary", "backend", `{"deliverable":"backend","phase_a_verdict":"pass","phase_b_cross_verdict":"fail","synthesized_verdict":"pass","synthesized_reason":"Fresh reviewer pass outweighs a known cross-model false positive.","real_findings":[{"severity":"low","dim":"code-quality","note":"Polish a response label."}],"timestamp":"2026-04-24T18:01:00Z"}`)

		code, payload, stderr := runJSONCommand(t, root, []string{"review", "status", "review-summary", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		if !jsonContains(payload, "synthesized_overrides") || !jsonContains(payload, "follow_ups") || !jsonContains(payload, "overall_verdicts") {
			t.Fatalf("expected normalized review summary, got %s", mustJSONPayload(t, payload))
		}

		code, payload, stderr = runJSONCommand(t, root, []string{"row", "status", "review-summary", "--json"})
		if code != 0 {
			t.Fatalf("expected exit 0, got %d stderr=%s payload=%s", code, stderr, mustJSONPayload(t, payload))
		}
		if !jsonContains(payload, "follow_ups") || !jsonContains(payload, "real_finding") {
			t.Fatalf("expected archive follow-up signals in row status, got %s", mustJSONPayload(t, payload))
		}
	})

	t.Run("review validate rejects inconsistent passing semantics", func(t *testing.T) {
		root := setupFurrowRoot(t)
		writeValidAlmanac(t, root)
		writeRowState(t, root, "review-inconsistent", map[string]any{
			"name":        "review-inconsistent",
			"title":       "Review Inconsistent",
			"step":        "review",
			"step_status": "completed",
			"updated_at":  "2026-04-24T18:00:00Z",
			"archived_at": nil,
			"deliverables": map[string]any{
				"backend": map[string]any{"status": "completed"},
			},
			"gates": []any{
				map[string]any{"boundary": "implement->review", "outcome": "pass", "decided_by": "manual", "timestamp": "2026-04-24T17:59:00Z"},
			},
		})
		writeReviewArtifact(t, root, "review-inconsistent", "backend", `{"deliverable":"backend","phase_a":{"verdict":"pass"},"phase_b":{"verdict":"pass","dimensions":[{"name":"correctness","verdict":"fail","evidence":"Critical path still broken."}]},"overall":"pass","timestamp":"2026-04-24T18:01:00Z"}`)

		code, payload, _ := runJSONCommand(t, root, []string{"review", "validate", "review-inconsistent", "--json"})
		if code != 3 {
			t.Fatalf("expected exit 3, got %d payload=%s", code, mustJSONPayload(t, payload))
		}
		if !jsonContains(payload, "review_phase_b_verdict_inconsistent") {
			t.Fatalf("expected semantic review inconsistency, got %s", mustJSONPayload(t, payload))
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

func initGitRepo(t *testing.T, root string) {
	t.Helper()
	for _, args := range [][]string{
		{"init"},
		{"config", "user.email", "furrow@example.invalid"},
		{"config", "user.name", "Furrow Test"},
		{"add", "."},
		{"commit", "-m", "baseline"},
	} {
		cmd := exec.Command("git", args...)
		cmd.Dir = root
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v failed: %v\n%s", args, err, string(output))
		}
	}
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

func writeImplementationPlan(t *testing.T, root, rowName, content string) {
	t.Helper()
	mustWrite(t, filepath.Join(root, ".furrow", "rows", rowName, "implementation-plan.md"), content)
}

func writeReviewArtifact(t *testing.T, root, rowName, deliverable, content string) {
	t.Helper()
	mustMkdirAll(t, filepath.Join(root, ".furrow", "rows", rowName, "reviews"))
	mustWrite(t, filepath.Join(root, ".furrow", "rows", rowName, "reviews", deliverable+".json"), content)
}

func completionEvidenceReviewState(rowName string) map[string]any {
	return map[string]any{
		"name":                rowName,
		"title":               "Completion Evidence",
		"step":                "review",
		"step_status":         "completed",
		"updated_at":          "2026-04-24T18:00:00Z",
		"archived_at":         nil,
		"truth_gates_version": float64(1),
		"deliverables": map[string]any{
			"one": map[string]any{"status": "completed"},
		},
		"gates": []any{
			map[string]any{"boundary": "implement->review", "outcome": "pass", "decided_by": "manual", "timestamp": "2026-04-24T17:59:00Z"},
		},
	}
}

func passingCompletionEvidenceReviewJSON() string {
	return `{"deliverable":"one","phase_a":{"verdict":"pass"},"phase_b":{"verdict":"pass"},"overall":"pass","timestamp":"2026-04-24T18:01:00Z","harness_process_risks":["modularization drift checked","duplicate algorithms checked","optionality spread checked","runtime-loaded entrypoint mismatch checked","specialists are skills, not registered agent types"]}`
}

func writeCompletionEvidenceArtifacts(t *testing.T, root, rowName, verdict string) {
	t.Helper()
	rowDir := filepath.Join(root, ".furrow", "rows", rowName)
	mustWrite(t, filepath.Join(rowDir, "ask-analysis.md"), `# Ask Analysis

## Literal Ask
Add customer-facing export support.

## Real Ask
Users can export the claimed dataset through the real CLI path.

## Implied Obligations
Completion evidence and archive blockers must cover the real ask.

## Non-Deferrable Work
Claim-blocking work cannot be hidden in follow-up items.

## Deferrable Work
Outside-scope polish can remain deferred.

## Runtime Surfaces Affected
CLI export command and generated file contents.

## Spirit-Of-Law Completion Statement
Archive is honest only when required-for-truth work is complete or claims are downgraded.
`)
	mustWrite(t, filepath.Join(rowDir, "test-plan.md"), validCompletionEvidenceTestPlan("Claim surfaces with equivalent behavior must execute claimed paths."))
	mustWrite(t, filepath.Join(rowDir, "claim-surfaces.yaml"), `
claim_surfaces:
  - name: cli export behavior
    claim: Users can export the claimed dataset through the real CLI path.
    equivalence_claim: false
    surfaces:
      - name: Go CLI
        status: passed
        evidence_type: unit
        evidence_path: internal/cli/app_test.go
`)
	mustWrite(t, filepath.Join(rowDir, "completion-check.md"), `# Completion Check

## Original Real Ask
Users can export the claimed dataset through the real CLI path.

## What Is Now True
go test ./internal/cli/... verifies completion evidence archive gates.

## What Is Only Structurally Present
No structural-only claim is treated as complete.

## Deferred Work
No known residual risks for this fixture.

## Does Any Deferral Block The Real Ask?
No.

## Adapter/Backend Boundary Check
Backend owns archive blockers.

## Help/Docs/Reference Truth Check
Prompt guidance references the rule.

## Final Verdict
`+verdict+`
`)
}

func validCompletionEvidenceTestPlan(parityLine string) string {
	return `# Test Plan

## Claims Under Test
CLI archive readiness blocks completion claims without evidence.

## Unit Tests
go test ./internal/cli/...

## Integration Tests
row archive fixture coverage.

## Runtime-Loaded Entrypoint Tests
CLI archive command against loaded row files.

## Negative Tests
Claim-blocking deferrals fail archive.

## Parity Tests
` + parityLine + `

## Skips And Why They Do Not Weaken The Claim
No skips.

## Manual Dogfood Path
Run row status then archive.
`
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

// TestRunHook_LayerGuard_PolicyResolvesFromSubdirectory is a regression test
// for the cwd-relative policy lookup brick. Before the walk-up fix, running
// `furrow hook layer-guard` from any subdirectory failed-closed because
// os.ReadFile(".furrow/layer-policy.yaml") errored. Once a single hook
// invocation failed, every subsequent PreToolUse hook (Edit included) also
// failed, leaving the agent unable to patch the bug. The fix resolves the
// policy via findFurrowRoot() walk-up.
func TestRunHook_LayerGuard_PolicyResolvesFromSubdirectory(t *testing.T) {
	root := t.TempDir()
	furrowDir := filepath.Join(root, ".furrow")
	if err := os.MkdirAll(furrowDir, 0o755); err != nil {
		t.Fatalf("mkdir .furrow: %v", err)
	}
	policy := `
version: "1"
agent_type_map:
  operator: operator
  engine:freeform: engine
layers:
  operator:
    tools_allow: ["*"]
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
  driver:
    tools_allow: ["Read"]
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
  engine:
    tools_allow: ["Read", "Bash"]
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
`
	if err := os.WriteFile(filepath.Join(furrowDir, "layer-policy.yaml"), []byte(policy), 0o600); err != nil {
		t.Fatalf("write policy: %v", err)
	}

	// Subdirectory of the Furrow root — mirrors the real-world brick condition
	// (agent had cd'd into adapters/pi before the hook ran).
	subdir := filepath.Join(root, "deep", "nested", "subdir")
	if err := os.MkdirAll(subdir, 0o755); err != nil {
		t.Fatalf("mkdir subdir: %v", err)
	}

	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(subdir); err != nil {
		t.Fatalf("chdir subdir: %v", err)
	}

	// Make sure no env override is leaking from the host environment.
	t.Setenv("FURROW_LAYER_POLICY_PATH", "")

	// Operator + Read of an arbitrary path should be allowed by the policy
	// above. With cwd-relative lookup this fails-closed before the verdict
	// even gets evaluated.
	stdin := bytes.NewBufferString(`{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/anything"},"agent_id":"a","agent_type":"operator"}`)
	var stdout, stderr bytes.Buffer
	app := NewWithStdin(&stdout, &stderr, stdin)
	code := app.Run([]string{"hook", "layer-guard"})

	if code != 0 {
		t.Fatalf("expected exit 0 (allow), got %d. stdout=%q stderr=%q", code, stdout.String(), stderr.String())
	}
	if bytes.Contains(stdout.Bytes(), []byte("layer_policy_invalid")) {
		t.Fatalf("policy load failed despite walk-up; stdout=%q", stdout.String())
	}
}

// TestRunHook_LayerGuard_PolicyPathEnvOverride confirms the env-var override
// still wins over walk-up — useful for CI fixtures and explicit pinning.
func TestRunHook_LayerGuard_PolicyPathEnvOverride(t *testing.T) {
	tmp := t.TempDir()
	overridePath := filepath.Join(tmp, "custom-policy.yaml")
	policy := `
version: "1"
agent_type_map:
  operator: operator
layers:
  operator:
    tools_allow: ["*"]
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
  driver:
    tools_allow: []
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
  engine:
    tools_allow: []
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []
`
	if err := os.WriteFile(overridePath, []byte(policy), 0o600); err != nil {
		t.Fatalf("write override: %v", err)
	}

	// Run from a directory with no .furrow/ anywhere upstream, to prove the
	// env var bypasses walk-up entirely.
	isolated := t.TempDir()
	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(isolated); err != nil {
		t.Fatalf("chdir isolated: %v", err)
	}

	t.Setenv("FURROW_LAYER_POLICY_PATH", overridePath)

	stdin := bytes.NewBufferString(`{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/x"},"agent_id":"a","agent_type":"operator"}`)
	var stdout, stderr bytes.Buffer
	app := NewWithStdin(&stdout, &stderr, stdin)
	code := app.Run([]string{"hook", "layer-guard"})

	if code != 0 {
		t.Fatalf("expected exit 0, got %d. stdout=%q stderr=%q", code, stdout.String(), stderr.String())
	}
}
