# Step Sequence Invariant

Rows traverse a fixed 7-step sequence. No steps are skipped or reordered.

```
ideate → research → plan → spec → decompose → implement → review
```

Pre-step evaluation may determine a step adds no new information (prechecked gate),
advancing automatically — but the step is still recorded in state.json.

## Enforcement

- `furrow row transition <row> --step <next-step>` validates step ordering; out-of-order transitions fail
- `furrow row transition <row> --step <next-step>` blocks when uncompleted user actions exist
- `state.json.step` tracks current position; only Furrow CLI commands may modify it

**Violation**: Attempting to skip or reorder steps results in a blocked transition.
Pending user actions also block transitions — complete them with the temporary
compatibility holdout `rws complete-user-action` until a Go command exists.
