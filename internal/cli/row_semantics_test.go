package cli

import "testing"

func TestSourceTodoIDsFromStateUsesCanonicalArray(t *testing.T) {
	state := map[string]any{
		"source_todo":  "legacy-id",
		"source_todos": []any{"first-id", "second-id", "first-id"},
	}

	got := sourceTodoIDsFromState(state)
	want := []string{"first-id", "second-id"}
	if len(got) != len(want) {
		t.Fatalf("expected %v, got %v", want, got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("expected %v, got %v", want, got)
		}
	}
}

func TestSourceTodoIDsFromStateFallsBackToLegacySingular(t *testing.T) {
	state := map[string]any{
		"source_todo": "legacy-id",
	}

	got := sourceTodoIDsFromState(state)
	if len(got) != 1 || got[0] != "legacy-id" {
		t.Fatalf("expected legacy fallback id, got %v", got)
	}
}
