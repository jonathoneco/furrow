# /furrow doctor

Run health check on Furrow installation.

1. Check `.furrow/almanac/rationale.yaml` for missing entries (every Furrow file must have one).
2. Check for stale `delete_when` conditions that may now be satisfied.
3. Verify skill instruction counts (step skills must be <=50 lines).
4. Verify total injected context (ambient + work + step) <=300 lines.
5. Run `frw doctor` for structural validation.
6. Report findings with severity (error, warning, info).
