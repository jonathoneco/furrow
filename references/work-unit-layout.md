# Work Unit Directory Layout

Reference document for the per-work-unit directory structure under `.work/{name}/`.

## Core Files (Always Created)

These files are created at work unit initialization or first step boundary.

| File | Created By | Description |
|------|-----------|-------------|
| `definition.yaml` | ideate step | Work contract: objective, deliverables, constraints |
| `state.json` | initialization (pre-ideate) | Lifecycle, progress, gate audit trail |
| `summary.md` | first step boundary | Context recovery document (regenerated at every boundary) |
| `reviews/` | initialization | Directory for structured review results (created empty) |
| `reviews/{deliverable}.json` | review step | One review result per deliverable |

## Conditional Files (Created When Needed)

These files are created by specific steps when their output is substantive.

| File | Created By | Condition |
|------|-----------|-----------|
| `plan.json` | decompose step | `len(deliverables) > 1` OR any `depends_on` present |
| `team-plan.md` | any step using agent teams | When agent teams are used |
| `research.md` | research step | When single-agent research sufficient |
| `research/` | research step | When multi-agent research |
| `research/{topic}.md` | research step | Per-agent research findings |
| `research/synthesis.md` | research step | Lead's synthesis of multi-agent research |
| `spec.md` | spec step | When single spec sufficient |
| `specs/` | spec step | When multiple component specs |
| `specs/{component}.md` | spec step | Per-component specification |
| `gates/` | any gate needing structured evidence | When structured review evidence needed |
| `gates/{from}-to-{to}.json` | gate evaluator | Per gate boundary with detailed evidence |

## Single-Deliverable Pattern

For simple work units with one deliverable, the typical layout is:

```
.work/{name}/
  definition.yaml
  state.json
  summary.md
  reviews/
    {deliverable}.json
  research.md          # single file, no research/ directory
  spec.md              # single file, no specs/ directory
```

No `plan.json` (no parallelism), no `research/` directory, no `specs/` directory,
and `gates/` only if the gate evaluator produces detailed dimensional evidence.

## Naming Conventions

- Work unit directory: kebab-case (e.g., `add-rate-limiting`)
- Deliverable names: kebab-case (e.g., `rate-limiter-middleware`)
- Research topics: kebab-case `.md` (e.g., `research/prior-art.md`)
- Spec components: kebab-case `.md` (e.g., `specs/middleware-design.md`)
- Review results: kebab-case `.json` (e.g., `reviews/rate-limiter-middleware.json`)
- Gate evidence: `{from}-to-{to}.json` (e.g., `gates/plan-to-spec.json`)
