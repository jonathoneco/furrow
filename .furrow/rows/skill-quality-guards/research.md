# Research: skill-quality-guards

## vertical-slice-guardrails

### Current State of Target Files

**red-flags.md** — Cross-step anti-pattern table with 7 step sections. The Decompose section (lines 31-35) has 2 entries in `| Signal | Risk | Action |` format. The new horizontal-slice entry slots in as a third row in this table. No structural changes needed.

**decompose.yaml** — Binary eval dimensions with 4 entries: `granularity`, `parallelism`, `coverage`, `ownership-clarity`. Each has: `name`, `definition`, `pass_criteria`, `fail_criteria`, `evidence_format`. The new `vertical-slicing` dimension follows this exact schema. No schema changes needed.

**decompose.md** — Step skill with Shared References section (lines 16-21) listing 5 references. The vertical-slice concept should be mentioned in Step-Specific Rules (lines 10-14) as a fifth rule, not in Shared References (it's inline guidance, not a separate file).

### Insertion Strategy

1. **red-flags.md line 35**: Append new row after "Specialist types are generic" row
2. **decompose.yaml**: Append 5th dimension after `ownership-clarity`
3. **decompose.md line 14**: Add rule after "Read `summary.md` for spec context"

### Vertical-Slice Mechanical Definition

The eval pass condition anchors to testability: "Each deliverable, when completed, produces at least one testable behavior change or verifiable artifact. A deliverable that only modifies one architectural layer (e.g., only database, only API, only UI) without a corresponding consumer or test in the same or earlier wave fails — unless the plan explicitly justifies horizontal decomposition for this row."

This maps cleanly to the existing binary PASS/FAIL schema. The "unless justified" clause means the evaluator checks for either (a) vertical slicing or (b) explicit justification — both are evidence-based.

## research-source-hierarchy

### Current State of Target Files

**research.md** — Step skill with output spec at lines 6-8: produces `research.md` or `research/` directory. The "Sources Consulted" section needs to be added to the output format. Best insertion: after "What This Step Produces" as a sub-requirement of the output.

Research Mode section (lines 51-54) already says "Every finding requires source citation. Multi-source triangulation for claims." The source hierarchy guidance extends this with precedence rules.

**research-sources.md** — Template with 3 sections: Source Types (table), Sources (inventory table), Citation Format. The hierarchy guidance should be inserted as a new section between the title and Source Types — it sets the priority before listing the formats.

### Source Hierarchy Design

Three tiers with clear decision rules:

| Tier | Sources | When to use |
|------|---------|-------------|
| Primary | Official docs, source code, changelogs, `--help` output, API responses | Always for version/behavior/config claims. First resort. |
| Secondary | Blog posts, tutorials, StackOverflow, conference talks | When primary sources are ambiguous or insufficient. Cross-reference with primary. |
| Tertiary | Training data (model knowledge) | Acceptable for well-established facts (language syntax, stdlib APIs, general patterns). Never for version-specific claims. |

Key rule: If a claim about external software can't be verified against a primary source, it must be flagged as unverified.

### Insertion Strategy

1. **research.md**: Add `## Sources Consulted` requirement after output spec (line 8). Add hierarchy guidance in Step-Specific Rules.
2. **research-sources.md**: Add `## Source Hierarchy` section after the title/description (line 3), before Source Types.

## Sources Consulted

| # | Source | Type | Relevance | Contribution |
|---|--------|------|-----------|--------------|
| 1 | `skills/shared/red-flags.md` | codebase | high | Verified table format and Decompose section structure |
| 2 | `evals/dimensions/decompose.yaml` | codebase | high | Verified dimension schema (name/definition/pass_criteria/fail_criteria/evidence_format) |
| 3 | `skills/decompose.md` | codebase | high | Identified insertion point for vertical-slice rule |
| 4 | `skills/research.md` | codebase | high | Identified output spec location and existing source citation rules |
| 5 | `templates/research-sources.md` | codebase | high | Verified template structure and identified hierarchy insertion point |
