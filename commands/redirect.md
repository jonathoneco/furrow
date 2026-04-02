# /redirect <reason>

Record a failed approach and redirect work to a new approach within the current step.

## Arguments

- `reason` (required): Why the current approach failed.

## Behavior

1. Find active task via `commands/lib/detect-context.sh`.
2. Read `state.json` for current step.

3. Record redirect as a fail gate entry in `state.json.gates[]`:
   ```json
   {
     "boundary": "{current_step}->{current_step}",
     "outcome": "fail",
     "decided_by": "human",
     "evidence": "Redirect: {reason}",
     "timestamp": "{ISO 8601 now}"
   }
   ```

4. Reset `step_status` to `"not_started"` (same step, fresh start).
5. Append redirect to `summary.md` under a `## Redirects` section:
   ```
   - [{timestamp}] {current_step}: {reason}
   ```
6. Git commit `.work/{name}/` with message: `chore: redirect {name} at {step}`.

## Constraints

- Does NOT rewind to an earlier step. Redirect is within the current step only.
- Does NOT change `state.json.step`. Only resets `step_status`.
- The new approach starts fresh within the same step boundaries.

## Output

Confirmation: step name, redirect reason recorded, step_status reset.
