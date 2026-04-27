# Decision-Format Parseability (T3)

## Verdict

**Tighten-required — but the tightening is a re-pointing, not a redesign.**

The canonical format defined in `skills/shared/decision-format.md` (the
`## Decision: {name}` block with `**Options**`/`**Lean**`/`**Outcome**`
fields) is **effectively unused** across `.furrow/rows/*/summary.md` (0 of 8
sampled rows contain a single conforming block; only the row that *defined*
the format uses its markers, and only inside research/spec artifacts, never
in summary.md).

What rows DO contain — uniformly, across every sampled row — is a
highly-regular `## Settled Decisions` section whose entries follow a
gate-transition shape: `- **{from_step}->{to_step}**: {outcome} — {rationale}`.
That shape is **strictly parseable** with a one-line regex.

D4 should therefore (a) declare the gate-transition shape the canonical
parseable format for "decisions in summary.md," (b) downgrade the
`decision-format.md` canonical block format to an *optional* in-line annotation
for non-gate decisions, and (c) ship D4 with strict parsing of the
gate-transition shape plus best-effort scraping of `- Decision:` prose
bullets in Key Findings as a backward-compat fallback.

## Format Spec Summary

`skills/shared/decision-format.md` (38 lines) prescribes a markdown block:
`## Decision: {name}` heading preceded by an HTML comment marker
`<!-- decision:{name} -->`, with five labeled bold fields (`**Category**`,
`**Options**` as a 2+ item list, `**Lean**`, `**Uncertainty**`, `**Outcome**`).
Mode behavior (supervised/delegated/autonomous) governs WHEN to record;
loop-exit conditions specify completeness. Integration says "Decisions with
outcomes feed into summary.md Key Findings; Unresolved decisions feed Open
Questions" — note the integration is a *one-way flow* of distilled prose,
not a copy of the canonical block into summary.md.

## Sample Survey

8 rows sampled (all recently archived or in-flight). Conformance assessed
against TWO targets: (a) the canonical `## Decision:` block format from
the spec, and (b) the de-facto `## Settled Decisions` gate-transition shape.

| row | section observed | canonical-block conformance | gate-transition conformance | issue |
|---|---|---|---|---|
| pre-write-validation-go-first | `## Settled Decisions` (7 entries) + 1 `- Decision:` bullet in Key Findings | none | full | canonical-block absent; 1 mid-step decision recorded as prose bullet outside the gate list |
| dual-review-delegation | `## Settled Decisions` (8 entries) | none | full | "decisions locked: …" listed inline within rationale prose; no structured options/lean |
| specialist-overhaul | `## Settled Decisions` (7 entries, incl. 1 `fail` row) | none | full | uses "Gate evaluation PASS — all N dimensions" boilerplate; rationale is meta, not decision content |
| go-backend-slice | `## Settled Decisions` (1 entry) | none | full | minimal — only review-gate row recorded |
| model-routing | `## Settled Decisions` (8 entries) | none | full | duplicates (two `plan->spec`, two `implement->review`) — gate retries appear as siblings |
| parallel-agent-wiring | `## Settled Decisions` (6 entries) | none | full | rationale embeds enumerated decisions ("5 architecture decisions settled: …") as comma-separated prose |
| post-merge-cleanup | `## Settled Decisions` (11 entries) | none | full | several near-duplicate `research->plan: pass` rows from re-runs |
| orchestration-delegation-contract (current) | `## Settled Decisions` (header only, no entries yet) | n/a | n/a | row is in research step |

**Quantitative:** 0/8 rows (0%) contain a canonical `## Decision: {name}`
block in summary.md. 7/8 rows (87.5%) contain a populated `## Settled
Decisions` section with gate-transition entries. 7/7 populated sections
(100%) conform exactly to the `- **{from}->{to}**: {outcome} — {rationale}`
shape — every entry parseable by a single regex
`^- \*\*([a-z_]+)->([a-z_]+)\*\*: (pass|fail) — (.*)$`.

Of the 49 gate-transition entries across the 7 populated rows:
- **49/49 (100%)** match the 4-field regex (from-step, to-step, outcome, rationale)
- **49/49 (100%)** have a non-empty rationale field
- **6/49 (12%)** are gate retries (same from/to pair appears multiple times in one row) — parser must preserve order or de-dup last-wins
- **1/49 (2%)** carries `fail` outcome (specialist-overhaul `review->review`)

Additional decision-bearing prose **outside** `## Settled Decisions`:
- 1/8 rows has a `- Decision: …` bullet in `## Key Findings`
  (pre-write-validation-go-first, line 35) — multi-sentence prose, no
  structured fields. Best-effort regex match `^- Decision:` would catch it
  but yield only a free-text rationale.

## Common Deviations

- **Universal**: nobody emits `<!-- decision:{name} -->` HTML comments in
  summary.md. The marker only appears in `skills/shared/decision-format.md`
  itself and in two design artifacts (research/spec) under the
  `ideation-and-review-ux` row that originally wrote the spec.
- **Universal**: nobody emits `## Decision: {name}` headings in summary.md.
- **Universal**: nobody fills `**Options**`, `**Lean**`, or `**Uncertainty**`
  fields in summary.md. These survive only in transient artifacts (e.g.,
  the ideation skill's working scratch) and are not promoted forward.
- **Common**: gate-rationale prose contains EMBEDDED decisions in
  comma/semicolon-delimited lists ("Design decisions locked: end-of-step
  dual-review, explicit specialist selection from scenarios, all-step
  delegation, two new specialists"). These are not individually parseable
  without NLP.
- **Common**: gate-retries produce duplicate `from->to` entries (post-merge-cleanup
  has 3 `research->plan: pass` rows; model-routing has 2 `plan->spec: pass`
  rows). Parser needs an ordering / de-dup policy.
- **Occasional**: `- Decision:` prose bullets in `## Key Findings` carry
  mid-step pivots that the gate-transition list doesn't capture
  (e.g., the D1 re-scope in pre-write-validation-go-first).
- **Occasional**: the rationale half of a gate entry is metadata about the
  gate itself ("Gate evaluation PASS — all 5 dimensions passed") rather
  than substantive decision content. These parse cleanly but yield empty
  semantic information.

## Parser Strategy Recommendation

**Primary (strict, regex-based, line-oriented):**

```
^## Settled Decisions$            -> open block
^- \*\*([a-z_]+)->([a-z_]+)\*\*: (pass|fail) — (.+)$  -> entry
^## .+$ (non-blank, non-list)     -> close block
```

Yields structured entries `{from_step, to_step, outcome, rationale,
ordinal}`. With ordinal preserved, gate-retries become first-class
(latest-wins or list-all are both well-defined). 100% of the 49 sampled
entries satisfy this regex.

**Secondary (best-effort, scoped to `## Key Findings`):**

```
^- (Decision|DECISION): (.+)$     -> free-text decision bullet
```

Yields `{step: <inferred from current row's step>, rationale: <text>}`. Used
to surface mid-step pivots that don't fit the gate model. Found in 1/8
sampled rows; flagged as best-effort in the bundle so consumers don't treat
absence as evidence.

**Bundle schema for D4's `decisions` array:**

```yaml
decisions:
  - row: pre-write-validation-go-first
    source: settled_decisions          # or "key_findings_prose"
    from_step: implement
    to_step: review
    outcome: pass
    rationale: "Implement gate: 6/6 deliverables complete..."
    ordinal: 7
```

The canonical `## Decision: {name}` block format from
`skills/shared/decision-format.md` should be **kept** in the spec but
relabeled as the format for *transient ideation artifacts* (research notes,
plan scratch) — NOT the format that parsers see in summary.md. Document
that distinction explicitly so future authors don't waste effort hand-rolling
canonical blocks into summary.md that nothing reads.

## Implication for D4

D4's spec step should finalize: (1) the parseable target is
`## Settled Decisions` gate-transition entries, NOT the canonical
`## Decision:` block format; (2) extraction is a strict regex pass, not
markdown-AST; (3) backward-compat covers the 100% of existing rows already
written in this shape — no migration needed because the shape was de-facto
canonical all along; (4) `key_findings_prose` provides best-effort
mid-step decision capture as a secondary source; (5) a follow-up
roadmap todo `align-decision-format-spec` should retire the unused
`<!-- decision: -->` markers + `## Decision:` heading prescription from
`skills/shared/decision-format.md` and replace it with the gate-transition
shape, freeing the canonical block format for transient ideation artifacts
where it's actually useful. D4 ships with strong tests against the regex
on the 49 historical entries; no degradation to "best-effort" needed for
the primary path.

## Sources Consulted

- `/home/jonco/src/furrow-orchestration-delegation-contract/skills/shared/decision-format.md` — primary — the spec under evaluation; 38 lines; defined the canonical block format
- `/home/jonco/src/furrow-orchestration-delegation-contract/.furrow/rows/pre-write-validation-go-first/summary.md` — primary — recently-archived row with 7 gate entries + 1 prose Decision bullet
- `/home/jonco/src/furrow-orchestration-delegation-contract/.furrow/rows/dual-review-delegation/summary.md` — primary — 8 gate entries with embedded enumerated decisions
- `/home/jonco/src/furrow-orchestration-delegation-contract/.furrow/rows/specialist-overhaul/summary.md` — primary — 7 entries including the only sampled `fail` outcome
- `/home/jonco/src/furrow-orchestration-delegation-contract/.furrow/rows/go-backend-slice/summary.md` — primary — minimal 1-entry edge case
- `/home/jonco/src/furrow-orchestration-delegation-contract/.furrow/rows/model-routing/summary.md` — primary — illustrates gate-retry duplicates
- `/home/jonco/src/furrow-orchestration-delegation-contract/.furrow/rows/parallel-agent-wiring/summary.md` — primary — embedded enumerated architecture decisions in rationale
- `/home/jonco/src/furrow-orchestration-delegation-contract/.furrow/rows/post-merge-cleanup/summary.md` — primary — 11 entries, multiple gate-retries
- `/home/jonco/src/furrow-orchestration-delegation-contract/.furrow/rows/orchestration-delegation-contract/summary.md` — primary — current row, confirms section header is present even pre-content
- recursive grep for `<!-- decision:` and `^## Decision:` across all `.furrow/rows/**/*.md` — primary — confirmed canonical-block markers appear ONLY in design artifacts, never in summary.md
