# Work Definition Schema

## Overview

A work definition is a YAML file that specifies what to build, what done looks like, and what context is needed. It is the contract between planner, executor, and reviewer.

The work definition is runtime-agnostic — the same file drives Claude Code sessions and Agent SDK programs. Runtime-specific behavior (how gates pause, how specialists are spawned) is an adapter concern.

## Schema

### Required Fields

```yaml
# --- Required ---

objective: string
# What the work should produce. Natural language, 1-3 sentences.
# For human and model understanding. Shapes the planner's decomposition
# and the coordinator's orchestration.

deliverables: list[Deliverable]
# Enumerated concrete outputs. At least one required.
# Prevents one-shotting by making scope explicit.
# See Deliverable schema below.

context_pointers: list[ContextPointer]
# References to specific files, symbols, or sections needed for this work.
# NOT whole directories or codebases. Specific pointers encourage targeted
# retrieval and model progressive loading.
# Can be empty list for work that needs no existing context.

constraints: list[string]
# Boundaries the work must stay within. Tech choices, scope limits,
# standards, compatibility requirements.
# Can be empty list for unconstrained work.

gate_policy: enum[supervised, delegated, autonomous]
# Trust level for this row. Determines how gates behave:
#   supervised  — all gates human-mediated
#   delegated   — human approves work def, execution gates automated
#   autonomous  — all gates automated, human reviews final artifact
```

### Optional Fields

```yaml
# --- Optional ---

review:
  model: enum[cross-model, single-model]
  # Default: cross-model for 2+ deliverables, single-model for 1.
  # Cross-model uses a different model than the specialist for review.

metadata:
  created: datetime
  author: string        # human or agent identifier
  source: string        # e.g., "manual", "planner-agent", "trigger"
```

### Deliverable Schema

Each deliverable is a self-contained unit of work within the work definition.

```yaml
# --- Deliverable ---

name: string
# Short identifier. Used in progress tracking, eval results, and
# execution plan references. Kebab-case recommended.

acceptance_criteria: list[string]
# Natural language statements of what matters for this deliverable.
# These serve dual purpose:
#   1. Guide executor behavior (criteria wording shapes agent output)
#   2. Define what the reviewer checks against
#
# Criteria are PUBLIC — visible to both executor and reviewer.
# Review METHODOLOGY is private (lives in Furrow review infrastructure).
#
# Guidance for writing criteria:
#   - State outcomes, not process ("token rotation is transparent"
#     not "implement token rotation using X pattern")
#   - Be specific enough to verify ("no N+1 queries in the new endpoints"
#     not "good performance")
#   - Include negative criteria where risks exist ("no security regressions",
#     "no backwards-incompatible API changes")
#   - Avoid criteria that prescribe implementation approach

specialist: string (optional)
# Domain specialist type for this deliverable. Hints to the coordinator
# what kind of agent should execute this work. Also signals to the review
# infrastructure what domain-specific review methodology to apply.
#
# Examples: security-specialist, database-architect, frontend-specialist,
#   technical-writer, devops-engineer, api-designer
#
# If omitted, the coordinator selects based on deliverable content.

depends_on: list[string] (optional, default: [])
# Names of deliverables that must complete before this one can start.
# The coordinator uses this to build the execution plan (parallel waves).
# Empty list = no dependencies = can run in first wave.

file_ownership: list[glob_pattern] (optional)
# Glob patterns for files this deliverable's specialist can modify.
# Prevents merge conflicts in parallel execution — each specialist's
# file ownership should be non-overlapping.
#
# Examples: ["src/auth/**"], ["migrations/**", "src/models/session.go"]
#
# If omitted, the coordinator derives ownership from context_pointers
# and deliverable content.

gate: enum[human, automated] (optional)
# Per-deliverable gate escalation. Overrides the work-level gate_policy
# for this specific deliverable. Use sparingly — only for deliverables
# that need different gate treatment than the row default.
#
# Example: a schema migration within a delegated row might need
# human sign-off even though other deliverables are auto-gated.
```

### ContextPointer Schema

```yaml
# --- ContextPointer ---

path: string
# File path relative to project root.

symbols: list[string] (optional)
# Specific symbols (functions, classes, methods) within the file.
# Encourages targeted retrieval — read these symbols, not the whole file.

sections: list[string] (optional)
# Specific sections within the file (for non-code files like specs,
# docs, or OpenAPI definitions).

note: string (optional)
# Why this context matters for the work. Helps the executor understand
# relevance without reading the full file.
```

## Complete Example

```yaml
objective: |
  Add transparent token rotation to the auth middleware so that
  expiring tokens are refreshed without interrupting active sessions.

gate_policy: delegated

review:
  model: cross-model

deliverables:
  - name: token-rotation-logic
    acceptance_criteria:
      - "Tokens are rotated transparently before expiry"
      - "Active sessions are not interrupted during rotation"
      - "Rotation handles concurrent requests safely"
      - "No security regressions in token handling"
    specialist: security-specialist
    depends_on: []
    file_ownership: ["src/auth/**"]

  - name: session-schema-update
    acceptance_criteria:
      - "Schema migration is reversible"
      - "No degradation in session query performance"
      - "Existing session data is preserved during migration"
    specialist: database-architect
    depends_on: []
    file_ownership: ["migrations/**", "src/models/session.go"]

  - name: integration-tests
    acceptance_criteria:
      - "Tests cover token expiry, rotation, and concurrent access"
      - "Tests run in CI without external dependencies"
      - "Edge cases documented in test descriptions"
    specialist: test-engineer
    depends_on: [token-rotation-logic, session-schema-update]
    file_ownership: ["tests/auth/**"]

  - name: api-documentation
    acceptance_criteria:
      - "Token rotation behavior documented for API consumers"
      - "Breaking changes clearly marked (if any)"
      - "Examples updated to reflect new token lifecycle"
    specialist: technical-writer
    depends_on: [token-rotation-logic]
    file_ownership: ["docs/api/**"]
    gate: human

context_pointers:
  - path: src/auth/middleware.go
    symbols: [AuthMiddleware, ValidateToken, RefreshToken]
    note: "Current auth implementation to extend"
  - path: src/models/session.go
    symbols: [Session, SessionStore]
    note: "Session model that needs rotation support"
  - path: docs/api/authentication.md
    sections: ["Token Lifecycle", "Error Codes"]
    note: "Existing docs to update"

constraints:
  - "Must be backwards-compatible with existing API clients"
  - "Use existing Redis session store — no new infrastructure"
  - "Token rotation window must be configurable via environment variable"
```

## Execution Plan (Coordinator-Produced)

The coordinator reads the work definition and produces an execution plan before
spawning any specialists. This plan is a machine-readable artifact that makes
orchestration explicit rather than spontaneous.

```json
{
  "waves": [
    {
      "wave": 1,
      "deliverables": ["token-rotation-logic", "session-schema-update"],
      "parallel": true,
      "specialists": {
        "token-rotation-logic": "security-specialist",
        "session-schema-update": "database-architect"
      }
    },
    {
      "wave": 2,
      "deliverables": ["integration-tests", "api-documentation"],
      "parallel": true,
      "specialists": {
        "integration-tests": "test-engineer",
        "api-documentation": "technical-writer"
      }
    }
  ]
}
```

The execution plan is JSON (machine-authored, machine-read). It lives in the
row directory alongside the work definition and progress state.

## Schema Validation

The work definition schema is validated at Level A (structural enforcement):
- Hook (Claude Code) or callback (Agent SDK) validates against JSON Schema
  before work begins
- Validation checks: required fields present, deliverable names unique,
  depends_on references valid deliverable names, no circular dependencies
- Invalid work definitions block execution — hard gate

## Relationship to Other Concepts

| Concept | Relationship to work definition |
|---------|-------------------------------|
| **Acceptance criteria** | Inline per deliverable — what done looks like (public) |
| **Review methodology** | NOT in work def — lives in Furrow review infrastructure (private to reviewer) |
| **Review config** | Work-level `review` field — how automated review operates |
| **Behavioral evals** | NOT in work def — Furrow-level concern (is the Furrow working?) |
| **Calibration** | NOT in work def — infrastructure concern (is the reviewer accurate?) |
| **Progress state** | Separate JSON file — machine-written, references deliverable names |
| **Execution plan** | Separate JSON file — coordinator-produced from work def |
| **Handoff/summary** | Separate MD file — auto-generated at boundaries from progress state |

## Design Decisions Log

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| Team composition in schema | Optional `specialist` hints + `depends_on`; coordinator produces execution plan | Schema carries domain hints, coordinator derives orchestration |
| Eval criteria location | Renamed to `acceptance_criteria`, always inline per deliverable | One pattern, one location; criteria are part of the deliverable spec |
| Three concepts separated | Acceptance criteria (work def) vs review methodology (infrastructure) vs behavioral evals (harness) vs calibration (infrastructure) | Different authors, lifecycles, and audiences |
| File ownership granularity | Glob patterns | Specific enough to prevent conflicts, flexible enough for file additions |
| Defaults+overrides | No — each field at exactly one level (work or deliverable) | Avoids two patterns for the same operation |
| Review approach per deliverable | Composed by infrastructure from three signals: file_ownership, acceptance_criteria, specialist | No new field needed; specialist is a hint, not a hard key |
| Information boundary | Acceptance criteria public (guide executor + reviewer); review methodology private (reviewer only) | Prevents gaming while maintaining guidance |
| Per-deliverable gate | Optional `gate` field for escalation | Some deliverables have higher risk within a row |
