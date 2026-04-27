package context_test

import (
	"testing"

	ctx "github.com/jonathoneco/furrow/internal/cli/context"
)

// TestBundleBuilderConformance runs the D5 conformance harness against the
// concrete BundleBuilder implementation. All 5 sub-tests must pass.
func TestBundleBuilderConformance(t *testing.T) {
	ctx.TestBuilderConformance(t, func() ctx.Builder {
		return ctx.NewBundleBuilder("test-row", "ideate", "driver")
	})
}

// TestBundleBuilder_RowStepTargetPreserved verifies row/step/target are set in Bundle.
func TestBundleBuilder_RowStepTargetPreserved(t *testing.T) {
	b := ctx.NewBundleBuilder("my-row", "plan", "engine")
	bundle, err := b.Build()
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	if bundle.Row != "my-row" {
		t.Errorf("Row: want %q got %q", "my-row", bundle.Row)
	}
	if bundle.Step != "plan" {
		t.Errorf("Step: want %q got %q", "plan", bundle.Step)
	}
	if bundle.Target != "engine" {
		t.Errorf("Target: want %q got %q", "engine", bundle.Target)
	}
}
