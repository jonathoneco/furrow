# Implementation Plan

## Objective
- Land the next in-scope `work-loop-boundary-hardening` slice by fixing the supported row-init mismatch, hardening implement and review artifact validation in the backend, and expanding archive-readiness evidence while keeping `adapters/pi/furrow.ts` thin.

## Planned work
1. Align row init with live almanac truth.
   - Change the `source_todo` read path to use the same tolerant YAML loader as almanac validation.
   - Add regression coverage proving a new row can be initialized against the live duplicate-key TODO shape.
2. Deepen backend artifact validation at the work-loop boundary.
   - Treat carried decompose artifacts as required implementation inputs when coordinated implementation is implied.
   - Treat `reviews/{deliverable}.json` or `reviews/all-deliverables.json` as first-class review-step artifacts.
   - Validate review artifacts for recognizable Phase A, Phase B, timestamp, and pass/fail verdict surfaces.
3. Expand checkpoint and archive evidence.
   - Surface latest gate evidence payload summary in `furrow row status`.
   - Surface archive-readiness evidence including review-artifact summary, source-link context, and learnings presence or count.
   - Record the richer archive ceremony data in the backend archive evidence file and response payload.
4. Keep the Pi adapter thin.
   - Update `adapters/pi/furrow.ts` only to render the richer backend checkpoint fields.
   - Do not re-derive blockers, review rules, or archive semantics in TypeScript.
5. Validate the landed behavior and sync durable row artifacts.
   - Run backend tests and live backend commands.
   - Run headless Pi `/work` commands against this row.
   - Update row-local execution, validation, and handoff artifacts to reflect what actually landed.
