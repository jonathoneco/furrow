package context

import (
	"fmt"
	"sync"
)

// registry is the global step → Strategy map. Strategies self-register via
// package init() in their respective files (justified registry pattern: the
// set of steps is closed and statically known; init() avoids a central
// switch ladder while preserving compile-time safety via blank-import at
// the cmd layer).
var (
	registryMu sync.RWMutex
	registry   = map[string]Strategy{}
)

// RegisterStrategy registers a Strategy for its step name.
// Called from package init() in each strategy file. Panics on duplicate
// registration (programming error; caught at startup, not runtime).
func RegisterStrategy(s Strategy) {
	registryMu.Lock()
	defer registryMu.Unlock()
	step := s.Step()
	if _, dup := registry[step]; dup {
		panic(fmt.Sprintf("context: duplicate strategy registration for step %q", step))
	}
	registry[step] = s
}

// LookupStrategy returns the registered Strategy for step, or
// ErrStrategyStepUnknown if none has been registered.
func LookupStrategy(step string) (Strategy, error) {
	registryMu.RLock()
	defer registryMu.RUnlock()
	s, ok := registry[step]
	if !ok {
		return nil, fmt.Errorf("context: no strategy for step %q: %w", step, ErrStrategyStepUnknown)
	}
	return s, nil
}

// RegisteredSteps returns the set of step names that have a registered strategy.
// Primarily for inspection/testing; order is unspecified.
func RegisteredSteps() []string {
	registryMu.RLock()
	defer registryMu.RUnlock()
	steps := make([]string, 0, len(registry))
	for k := range registry {
		steps = append(steps, k)
	}
	return steps
}
