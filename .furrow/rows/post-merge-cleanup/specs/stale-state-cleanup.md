# Spec: stale-state-cleanup

`.furrow/.focused` already updated to `post-merge-cleanup` by `rws focus` during row creation.

Verify no references to archived rows remain in active state after all other fixes land.

## AC
- .furrow/.focused set to active row
- No references to archived rows in active state
