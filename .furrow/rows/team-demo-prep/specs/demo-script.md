# Spec: demo-script

## Interface Contract

- File: `DEMO.md` at project root
- Format: Markdown with sections, subsections, code blocks for commands
- Audience: presenter (you) — not a handout for attendees

## Acceptance Criteria (Refined)

1. `DEMO.md` exists at project root with prep checklist section containing: font size reminder, close notifications, rehearsal with timer
2. tmux section (~3min) contains subsections for sessionizer, lazygit, ranger, agent dashboard — each with exact keybinding and one-sentence talking point
3. furrow section (~7min) contains subsections for: knowledge layer (todos/roadmap/almanac), row lifecycle (quality-and-rules walkthrough), furrow:next (cat pre-staged output), live launch explanation
4. Framed as narrative arc ("I got a task, here's how I work on it"), not a feature list
5. Every command in DEMO.md uses a real path or keybinding verified in research

## Test Scenarios

### Scenario: Prep checklist completeness
- **Verifies**: AC 1
- **WHEN**: Reader opens DEMO.md
- **THEN**: Prep checklist at top includes font size, notifications, rehearsal items
- **Verification**: `grep -c "font\|notification\|rehears" DEMO.md` returns >= 3

### Scenario: tmux keybindings accurate
- **Verifies**: AC 2, AC 5
- **WHEN**: Reader follows tmux section commands
- **THEN**: Each keybinding matches `~/.config/tmux/config/keybindings.conf`
- **Verification**: Manual cross-reference with keybindings.conf

### Scenario: furrow commands executable
- **Verifies**: AC 3, AC 5
- **WHEN**: Reader runs cat commands from furrow section
- **THEN**: Referenced files exist and produce meaningful output
- **Verification**: Run each `cat` command and confirm output is non-empty

## Implementation Notes

- Keep each subsection to 2-4 lines max — talking points, not paragraphs
- Commands as fenced code blocks for easy copy-paste
- Use relative paths from project root where possible
- Narrative transition between tmux and furrow: "now that I'm in the project, let me show you how I track and plan work"

## Dependencies

- Research findings: tmux keybindings, best row, best todo
- No code dependencies
