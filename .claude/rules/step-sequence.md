# Step Sequence Invariant

Rows traverse a fixed 7-step sequence. No steps are skipped or reordered.

```
ideate → research → plan → spec → decompose → implement → review
```

Pre-step evaluation may determine a step adds no new information (prechecked gate),
advancing automatically — but the step is still recorded in state.json.

## Enforcement

- `rws transition` validates step ordering; out-of-order transitions fail
- `rws transition` blocks (exit 1) when uncompleted user actions exist
- `state.json.step` tracks current position; only `rws` commands may modify it

**Violation**: Attempting to skip or reorder steps results in a blocked transition.
Pending user actions also block transitions — complete them with `rws complete-user-action`.
