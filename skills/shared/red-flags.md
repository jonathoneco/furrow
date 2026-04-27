---
layer: shared
---
# Red Flags — Cross-Step Anti-Pattern Detection

Read before any file write or step transition. Each flag has a signal, risk, and corrective action.

## Ideate
| Signal | Risk | Action |
|--------|------|--------|
| Jumping to solution before exploring problem space | Premature commitment | Return to brainstorm phase |
| No questions asked before research planning | Missing alignment | Run questions-before-research |
| Accepting first framing without challenge | Confirmation bias | Run premise challenge |

## Research
| Signal | Risk | Action |
|--------|------|--------|
| Citing only one source or approach | Insufficient coverage | Search for alternative approaches |
| No prior art search in codebase | Missing context | Grep for related patterns before external research |

## Plan
| Signal | Risk | Action |
|--------|------|--------|
| Plan has no dependency ordering rationale | Ungrounded sequencing | Justify each wave boundary |
| File ownership globs overlap between agents | Merge conflicts | Resolve overlaps before proceeding |
| CC plan mode produced artifacts spanning spec+decompose+implement | Pipeline bypass — steps exist to produce distinct gated artifacts | Feed plan mode output into current step only; advance through remaining steps on rails |

## Spec
| Signal | Risk | Action |
|--------|------|--------|
| Acceptance criteria not testable | Unverifiable spec | Rewrite with concrete pass/fail conditions |
| Spec references research findings without citation | Traceability gap | Add specific file/section references |

## Decompose
| Signal | Risk | Action |
|--------|------|--------|
| All deliverables in a single wave | No parallelism | Check if dependencies actually prevent parallelism |
| Deliverables named by architectural layer ("database", "API", "UI") instead of behavior | Horizontal slicing — delays testable functionality, concentrates integration risk | Reframe as vertical slices; if horizontal is justified, document why in the plan |
| Specialist types are generic ("implementer") | Weak domain framing | Rename to domain experts |

## Implement
| Signal | Risk | Action |
|--------|------|--------|
| Writing outside file_ownership without justification | Scope creep | Document why in commit message or flag for review |
| No tests for new code paths | Coverage gap | Add tests before completing |

## Review
| Signal | Risk | Action |
|--------|------|--------|
| Marking dimension as PASS without evidence | Empty eval | Re-run verification, cite output |
| Skipping Phase A artifact check | Incomplete review | Run artifact validation first |
