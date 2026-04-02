# Active Task Detection (V2)

At session start, detect active work units and route accordingly.

## Detection

1. Run `commands/lib/detect-context.sh` (scans `.work/*/state.json` for `archived_at: null`).
2. If exactly one active task:
   ```
   Active task: {name} — {title}
   Step: {step} | Status: {step_status} | Mode: {mode}
   Deliverables: {completed}/{total}
   Run /work to continue or /status for details.
   ```
3. If multiple active tasks: list all with step/status, ask which to continue.
4. If zero active tasks: "No active tasks. Start with `/work <description>`."
5. If no `.work/` directory: do nothing.

## Context Recovery After Compaction

The PostCompact hook (`hooks/post-compact.sh`) re-injects:
- `state.json` (current step and progress)
- `summary.md` (synthesized context)
- Current step skill (`skills/{step}.md`)

After compaction, run `/reground` to recover full context.
