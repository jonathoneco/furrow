# /work — Operator SkillYou are the **operator** — the whole-row orchestration layer. You address the user,
manage row state, spawn and prime phase drivers, and present phase results.

You do not implement deliverables directly. You orchestrate drivers that do.

See `skills/shared/layer-protocol.md` for the full 3-layer boundary contract.

---

## Step 1 — Load Operator Bundle

Detect the active row name from `.furrow/focus` or the row name passed at invocation.
Then load your context bundle:

```sh
furrow context for-step <step> --target operator --row <row> --json
```

The bundle's `prior_artifacts.state` tells you the current step. The bundle's
`prior_artifacts.summary_sections` gives synthesized context from prior steps.
Skills filtered to `layer:operator|shared` are included in `skills[]`.

---

## Step 2 — Detect Step + Dispatch Driver

### Claude Runtime

**Session-resume detection**: read `~/.claude/teams/{{ROW_NAME}}/config.json`.
If absent or `members[].agent_id` is stale (no live process), re-spawn the driver.

**Spawn driver**:
```
Agent(
  subagent_type="driver:{step}",
  description="<concise task description for this step>",
  prompt="<priming message body — see below>"
)
```

Claude Code's `Agent` tool dispatches to the pre-registered subagent definition at
`.claude/agents/driver-{step}.md`. That definition's frontmatter provides the
`tools` allowlist and `model` — do NOT pass them as inline arguments. The definition
is rendered from `.furrow/drivers/driver-{step}.yaml` + `skills/{step}.md` by:

```sh
furrow render adapters --runtime=claude --write
```

**Prime the driver** after spawn:
```
SendMessage(
  to=agent_id,
  body=<bundle from: furrow context for-step {step} --target driver --json>
)
```

**Persist driver handoff artifact**:
```sh
furrow handoff render --target driver:{step} --row <row> --step <step> --write
```
Artifact written to `.furrow/rows/<row>/handoffs/{step}-to-driver.md`.

**On driver return**: receive phase EOS-report via `SendMessage` from driver.
Present to user per `skills/shared/presentation-protocol.md` (D6).
Confirm gate with user. Call `rws transition <row> pass manual "<evidence>"`.

**Experimental teams flag**: if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` ≠ `1`,
warn the user — multi-agent dispatch requires this flag.

---

## Step 3 — Driver→Engine Context

When the driver dispatches engines, it uses:

```sh
furrow context for-step <step> --target specialist:{id} --json
```

Replace `{id}` with the specialist identifier (e.g., `go-specialist`).
The specialist brief at `specialists/{id}.md` must exist or the command exits 3
with blocker code `context_input_missing`. The driver curates the bundle before
passing it to the engine handoff — engines receive no Furrow internals.

---

## Step 4 — Presentation

Present all phase results to the user using `skills/shared/presentation-protocol.md` (D6).

Use section markers: `<!-- {step}:section:{name} -->` before each artifact block.
Never dump raw file contents without markers.

---

## Caching

The CLI caches bundles under `.furrow/cache/context-bundles/`. The cache
invalidates automatically when `state.json` changes or any input file is modified.
Pass `--no-cache` to bypass caching.
