# Team Demo: Dev Environment — Live Walkthrough

**Time budget**: ~10 minutes
**Style**: Run everything live. Show don't tell.

## Prep Checklist

- [ ] Increase terminal font size for screen share readability
- [ ] Close Slack, email, notifications (`swaync` — dismiss all)
- [ ] Start in a **different** tmux session (home or another project) — not this repo
- [ ] Make sure `furrow-team-demo-prep` is NOT already open as a tmux session (kill it if so)
- [ ] Archive the `team-demo-prep` row so there's no active row: `rws archive team-demo-prep`
- [ ] Rehearse once with a stopwatch

---

## Part 1: tmux (~3 min)

You're in some other tmux session. You just got a task to work on.

### 1.1 Sessionizer — jump to the project

```
Ctrl+Space, Ctrl+s
```

Type "furrow-team-demo" → select it. New tmux session created, you're in the project.

> Point out: fuzzy search across ~/src, instant session creation. Show `Alt+j` to open Claude Code directly in this session.

### 1.2 Lazygit

```
Ctrl+Space, g
```

Browse commit history. Show a few commits. Press `q`.

### 1.3 Ranger

```
Ctrl+Space, e
```

Navigate into `.furrow/` — show the structure. Navigate into `almanac/`. Press `q`.

### 1.4 Agent Dashboard

```
Ctrl+Space, Ctrl+f
```

Show it. Explain what it displays when agents are running. Press `q`.

**Transition**: "Now let me show you the system that makes AI-assisted development actually structured."

---

## Part 2: Furrow — live (~7 min)

### 2.1 Quick knowledge layer tour (1 min)

Show the accumulated state that already exists:

```bash
head -40 .furrow/almanac/todos.yaml
```

> "Structured backlog — each TODO has full context, effort estimate, dependencies."

```bash
head -30 .furrow/almanac/rationale.yaml
```

> "Every component tracked with 'exists because' and 'delete when'."

### 2.2 Run furrow:next live (1 min)

```bash
alm next
```

> "This reads the roadmap, finds the next unstarted phase, and generates handoff prompts. These are self-contained — I can paste them into a new session."

Point out: branch names, source TODOs, key files. Two parallel rows in Phase 1.

### 2.3 Launch /furrow:work live (5 min)

Pick one of the rows from the furrow:next output. In the Claude Code session:

```
/furrow:work <description from the next output>
```

**What the audience sees live:**

1. **Row initialization** — furrow creates the row directory, state.json, sets focus
2. **Ideation starts** — the agent brainstorms dimensions of the problem, does a premise challenge
3. **Interactive collaboration** — it asks you questions with Option A/B/C and a stated lean. You answer.
4. **Definition building** — it assembles `definition.yaml` section by section, you approve each
5. **Gate transition** — it validates the definition and asks to advance to research

> Let it run through ideation naturally. Answer the questions as they come. This IS the demo — the audience is watching structured AI development happen in real time.

**If time is tight**: After seeing ideation start and one round of questions, you can say "This continues through 7 steps — research, plan, spec, decompose, implement, review — each with gates and accumulated knowledge. Let me show you what a completed one looks like."

Then quickly:
```bash
cat .furrow/rows/quality-and-rules/state.json | python3 -m json.tool
```

> "This one went all 7 steps. 6 deliverables, 3 parallel waves, zero corrections."

---

## Closing

> "tmux for fast movement, furrow for structured AI development where knowledge compounds. Questions?"

## Fallbacks

- **If ideation is slow**: Show the pre-staged output: `cat .furrow/demo/next-prompt.txt`
- **If something breaks**: `cat .furrow/rows/quality-and-rules/state.json | python3 -m json.tool` — show a completed row instead
- **If you run out of time**: Skip 2.1 (knowledge tour) and go straight to furrow:next → /work
