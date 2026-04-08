# Research: Team Demo Prep

## Deliverable: demo-script

### tmux Integrations (all use `Ctrl+Space` prefix)

| Tool | Keybinding | Notes |
|------|-----------|-------|
| Sessionizer | `Ctrl+Space` + `Ctrl+s` | Fuzzy-finds dirs in `~/src`, creates/switches tmux sessions. Alt+j/k/l launch with pre-configured commands (claude, codex, bv) |
| Lazygit | `Ctrl+Space` + `g` | Opens in 90% popup |
| Ranger | `Ctrl+Space` + `e` | Opens in 90% popup |
| Agent Dashboard | `Ctrl+Space` + `Ctrl+f` | Binary at `~/.local/bin/agent-dashboard`, 90% popup |
| tmux-open (URL/path picker) | `Ctrl+Space` + `u` | Extracts URLs/file paths from scrollback, opens in browser or nvim |

Config lives at `~/.config/tmux/tmux.conf`, keybindings in `~/.config/tmux/config/keybindings.conf`.
Sessionizer config: `~/.config/tmux-sessionizer/tmux-sessionizer.conf`, searches `~/src`.

### Demo narrative for tmux
Show as "here's how I jump between projects and tools without leaving the terminal":
1. Sessionizer to switch to this project
2. Lazygit popup to show git history
3. Ranger popup to browse files
4. Agent dashboard to show running agents
5. (Optional) tmux-open to grab a URL from scrollback

## Deliverable: pre-staged-outputs

### Best row for lifecycle demo: `quality-and-rules`
- **Title**: "PostToolUse hooks, test cases from spec, naming guidance, and rules strategy"
- Full 7-step sequence, 6 deliverables across 3 waves, zero corrections
- Clear gate evidence at every transition
- Shows: wave structure, specialist assignment, rigorous gating

### Best todo for furrow:next: `parallel-agent-orchestration-adoption`
- **Status**: active
- **Title**: "Built-in team orchestration isn't being used — diagnose and fix"
- Medium effort, clear problem statement, touches all layers
- Good narrative: "here's a real problem we're working on next"

### Almanac rationale
- 465 entries in `rationale.yaml`
- Best demo examples: specialist "delete_when" model, hook enforcement layer, two-phase gate execution
- Shows the "why" behind architectural decisions

### Roadmap state
- `roadmap.yaml` (429 lines) and `roadmap.md` (204 lines) already exist and are current
- 7 phases, 36 active TODOs, 19 done
- Includes dependency DAG, conflict zones, worktree commands
- **Ready to show as-is** — no regeneration needed

### furrow:next mechanics
- Skill: `/furrow:next` or CLI: `alm next`
- Reads `roadmap.yaml` + `todos.yaml`, outputs handoff prompts to console
- Supports `--phase N` for specific phase targeting
- Includes tmux launch integration for parallel rows
- **Pre-stage**: Run `alm next` and capture output to file

### furrow:triage mechanics
- Skill: `/furrow:triage` or CLI: `alm triage`
- Reads `todos.yaml`, generates `roadmap.yaml` + `roadmap.md`
- Supports `--full` for complete regeneration
- **Already run** — current state is ready

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| `.furrow/rows/*/state.json` (5+ rows) | Primary | Lifecycle data, gate evidence, deliverable tracking |
| `.furrow/almanac/todos.yaml` | Primary | Todo state, active items for demo |
| `.furrow/almanac/roadmap.yaml` | Primary | Roadmap structure, phase definitions |
| `.furrow/almanac/rationale.yaml` | Primary | Architectural decision records |
| `~/.config/tmux/tmux.conf` + keybindings.conf | Primary | tmux keybindings and integration config |
| `~/.config/tmux-sessionizer/tmux-sessionizer.conf` | Primary | Sessionizer search paths and session commands |
| `commands/next.md`, `commands/triage.md` | Primary | furrow:next and furrow:triage skill specs |
| `bin/alm` | Primary | CLI tool for almanac operations |

## Open Questions Resolved

1. **Which todo for furrow:next?** → `parallel-agent-orchestration-adoption` (active, clear narrative, medium effort)
2. **Which row for lifecycle demo?** → `quality-and-rules` (full 7-step, 3 waves, zero rework)
