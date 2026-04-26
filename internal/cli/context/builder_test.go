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

// TestBundleBuilder_SetMetadata verifies SetMetadata accumulates key/value pairs.
func TestBundleBuilder_SetMetadata(t *testing.T) {
	b := ctx.NewBundleBuilder("r", "ideate", "driver")
	b.SetMetadata("is_first_step", true)
	b.SetMetadata("topic_count", 5)

	bundle, err := b.Build()
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	if v, ok := bundle.StepStrategyMetadata["is_first_step"].(bool); !ok || !v {
		t.Errorf("expected is_first_step=true, got %v", bundle.StepStrategyMetadata["is_first_step"])
	}
	if v, ok := bundle.StepStrategyMetadata["topic_count"].(int); !ok || v != 5 {
		t.Errorf("expected topic_count=5, got %v", bundle.StepStrategyMetadata["topic_count"])
	}
}

// TestBundleBuilder_ResetClearsMetadata verifies metadata is cleared on Reset.
func TestBundleBuilder_ResetClearsMetadata(t *testing.T) {
	b := ctx.NewBundleBuilder("r", "ideate", "driver")
	b.SetMetadata("key", "value")
	b.Reset()
	bundle, err := b.Build()
	if err != nil {
		t.Fatalf("Build after Reset: %v", err)
	}
	if len(bundle.StepStrategyMetadata) != 0 {
		t.Errorf("expected empty metadata after Reset, got %v", bundle.StepStrategyMetadata)
	}
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
