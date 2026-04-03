# Reference Index

Reference documents are NOT injected into context. They are read on demand when
a step skill or agent needs detailed protocol information.

## Topic Index

| Topic | File | Used By |
|-------|------|---------|
| Definition complexity mapping | `references/definition-shape.md` | ideate, plan |
| Gate evaluation procedures | `references/gate-protocol.md` | All step transitions |
| Phase A/B review methodology | `references/review-methodology.md` | review step |
| Eval dimension definitions | `references/eval-dimensions.md` | review step, gate checks |
| Specialist agent template | `references/specialist-template.md` | decompose, implement |
| Context deduplication rules | `references/deduplication-strategy.md` | Harness maintenance |
| Work unit directory layout | `references/work-unit-layout.md` | All steps |
| Research mode conventions | `references/research-mode.md` | research, decompose, implement, review |
| Work unit meta annotations | `references/work-unit-meta.yaml` | furrow-doctor, archive |

## Usage Pattern

Step skills reference specific docs by path:
```
Read `references/gate-protocol.md` before evaluating gates.
```

Do NOT read all references preemptively. Read only what the current task requires.
