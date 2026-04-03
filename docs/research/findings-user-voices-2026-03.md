# User Voices: Claude Code Workflow Tools (March 2026)

Real user experiences sourced from Hacker News comments, Reddit discussions,
and developer blogs. Focus on ground truth from people building real things.

---

## Tool Landscape (What People Actually Use)

### Tier 1: Dominant Plugins

**Superpowers** (obra/superpowers) -- 107K GitHub stars
- Brainstorm -> Plan -> Implement pipeline with TDD
- The original "structured workflow" plugin for Claude Code
- Created by Jesse Vincent (fsck.com)

**gstack** (garrytan/gstack) -- 39K stars in 11 days (March 2026)
- 15 role-based skills: CEO reviewer, staff engineer, QA lead, security officer
- 28 slash commands, persistent Chromium daemon for visual QA
- Created by Garry Tan (Y Combinator CEO)

**Get Shit Done (GSD)** (gsd-build/get-shit-done)
- Meta-prompting, context engineering, spec-driven development
- 473 points on HN, 254 comments (March 17 2026)

### Tier 2: Alternatives Gaining Traction

**OpenSpec** (Fission-AI/OpenSpec) -- lightweight spec-driven development
- Markdown-based, less opinionated than Superpowers/GSD
- Users praise its tunability and reduced verbosity

**Ralph Loops** (ralph-wiggum technique) -- autonomous iteration loops
- While-loop that re-feeds prompts until completion
- Now an official Claude Code plugin
- Often combined with other tools (Superpowers planning + Ralph execution)

**HumanLayer** -- context engineering for large codebases
- 4-phase: Research -> Plan -> Implement -> Validate
- Key discipline: never exceed 60% context, clear between phases

**PI Agent** (formerly Ampcode) -- open-source Claude Code alternative
- "Aggressively extensible" philosophy, 20+ extension hooks
- Appeals to engineers who want control over Furrow itself

**OpenCode** / **Codex CLI** -- alternative CLI agents
- Some users switching to these for cost reasons or model flexibility

### Tier 3: Niche / Emerging

- **LaneConductor** -- unified Kanban board for multi-agent coordination
- **DevArch** (devarch.ai) -- Claude Code guardrail workflow with hooks/agents/skills
- **K9 Audit** -- deterministic non-LLM audit layer for autonomous agents
- **Conductor.build** -- automated multi-version builds with gstack
- **Mysti** -- multi-model debate (Claude + Codex + Gemini)

---

## What Real Users Say (Direct Quotes & Experiences)

### The Superpowers Experience

**Positive:**

> "The superpowers plugin took my Claude Code experience from mostly
> frustrating to nearly-magical. I'm not a software engineer by training
> nor trade, so caveats apply, but I found that the brainstorming -> plan
> writing -> plan execution flow helps immensely with extracting assumptions
> and unsaid preferences into a comprehensive plan."
> -- i_am_a_bad_llm, HN (Feb 2026), non-engineer

> "I've been playing around with the Superpowers plugin on a new small
> project and really like it. Simple enough to understand quickly by reading
> the GitHub repo and seems to improve the output quality."
> -- rob, HN (Jan 2026)

> "I import skills or groups of skills like Superpowers when I want to try
> out someone else's approach to claude code for a while."
> -- solidasparagus, HN (Mar 2026)

**Negative / Mixed:**

> "gsd is a highly overengineered piece of software that unfortunately does
> not get shit done, burns limits and takes ages. Superpowers looks like a
> good middleground."
> -- yolonir, HN (Mar 2026) -- used both, prefers Superpowers

> "Not highly overengineered but definitely somewhat. I ended up stripping
> it back to get something useful. Kept maybe 30%. There's a kernel of a
> good idea in there."
> -- esperent, HN (Mar 2026) -- on Superpowers specifically

> "Two things I don't like about superpowers: it writes all the codes into
> the implementation plan at the plan step, then the subagents basically
> just rewrite these codes back to the files."
> -- huydotnet, HN (Mar 2026) -- used both GSD and Superpowers

> "For coding especially I don't like seeing a comprehensive design spec
> written (good) and then turning that into effectively the same doc but
> macro expanded to become a complete implementation with the literal code
> for the entire thing in a second doc (bad). Even for trivial changes I'd
> end up with a good and succinct -design.md, then an -implementation.md,
> then end with a swarm of sub agents getting into races."
> -- whalesalad, HN (Mar 2026)

> "Then one of my juniors goes and loads up things like 'superpowers' and
> all sorts of stuff..."
> -- pdantix, HN (Mar 2026) -- skeptical senior engineer at work

### The gstack Experience

**Positive:**

> "This thing is absolutely wild. You essentially get an agent in
> conductor.build who drafts multiple choice replies to your product and
> engineering questions from claude. Dramatically improved code quality
> and speed of development for me."
> -- josh2600, HN (Mar 2026)

> "I've been using gstack for the last few days, and will probably keep it
> in my skill toolkit. There's a lot of things I like. It maps closely to
> skills I've made for myself."
> -- madrox, HN (Mar 2026)

> "I found that gstack's /office_hours to be good about encouraging, while
> being firm."
> -- iamwil, HN (Mar 2026)

**Negative / Mixed:**

> "GStack is a brilliant setup for maximizing Claude Code's velocity. But
> if you are letting an agent run autonomously across your repos, velocity
> without constraints is terrifying. We recently had Case #001: a Claude
> Code agent got stuck in a 70-minute loop, repeatedly injecting a staging
> URL into a production config file."
> -- zippolyon, HN (Mar 2026)

> "Noone seems to have mentioned that Gstack has 'Telemetry' on your usage
> data. Is this not a backdoor way for YC to get signal on what people are
> building and find more ideas?"
> -- lasky, HN (Mar 2026)

### The GSD Experience

**Positive:**

> "I've been using GSD extensively over the past 3 months. GSD consistently
> gets me 95% of the way there on complex tasks. That's amazing. The last
> 5% is mostly 'manual' testing. We've used GSD to build and launch a SaaS
> product."
> -- yoaviram, HN (Mar 2026)

> "Have had great results with it. I got sick of paying FreshBooks monthly
> for basic income/expense tracking and used GSD to build a macOS Swift
> app with Codex 5.4 and Opus 4.6."
> -- unstatusthequo, HN (Mar 2026) -- built and considering App Store release

**Negative:**

> "I've tried it, and I'm not convinced I got measurably better results
> than just prompting claude code directly. It absolutely tore through
> tokens though. I don't normally hit my session limits, but hit the
> 5-hour limits in ~30 minutes and my weekly limits by Tuesday with GSD."
> -- MeetingsBrowser, HN (Mar 2026)

> "I burned literally a weeks worth of the $20 claude subscription and
> then $20 worth of API credits on gsdv2. To get like 500 LOC."
> -- sigbottle, HN (Mar 2026)

### The "Just Use Plan Mode" Camp

> "I was using this and superpowers but eventually, Plan mode became enough
> and I prefer to steer Claude Code myself. These frameworks burn 10x more
> tokens, in my experience. I was always hitting the Max plan limits for
> no discernable benefit in the outcomes."
> -- gtirloni, HN (Mar 2026) -- tried both, went back to vanilla

> "I've played around a bit with the plugins and plan mode really handles
> things fine for the most part. Having CC create custom skills/agents
> created for [my workflows] gets me 80% of the way there."
> -- SayThatSh, HN (Mar 2026)

> "at work I've spent some time setting up our claude.md files and curated
> the .claude directory with relevant tools such as linear, figma, sentry,
> LSP, browser testing. sensible stuff. I outline what I want in linear,
> have claude synthesize into a plan and we iterate until we're both happy,
> then I let it rip. works great."
> -- pdantix, HN (Mar 2026) -- senior engineer, minimal tooling

### The OpenSpec / Composable Camp

> "I like openspec, it lets you tune the workflow to your liking and doesn't
> get in the way. I started with all the standard spec flow and as I got
> more confident and opinionated I simplified it to my liking."
> -- gbrindisi, HN (Mar 2026)

> "I think these type of systems (gsd/superpowers) are way too opinionated.
> The best way to truly stay on top of the crazy pace of changes is to not
> attach yourself to super opinionated workflows."
> -- alasano, HN (Mar 2026)

> "I use openspec to create context and a sequential task list that I feed
> to ralph loops, so that I'm involved for the planning and the
> verification step but completely hands off the wheel during code
> generation."
> -- gbrindisi, HN (Mar 2026) -- composing OpenSpec + Ralph

### The Hybrid / Custom Camp

> "I ended up grafting the brainstorm, design, and implementation planning
> skills from Superpowers onto a Ralph-based implementation layer that
> doesn't ask for my input once the implementation plan is complete. I have
> to run it in a Docker sandbox because of the dangerously set permissions
> but that is probably a good idea anyway."
> -- marcus_holmes, HN (Mar 2026)

> "I find simple Ralph loops with an implementer and a reviewer that repeat
> until everything passes review and unit tests is 90% of the job."
> -- LogicFailsMe, HN (Mar 2026)

### Switching Stories

**Cursor -> Claude Code:**

> "I switched to Claude Code because I don't particularly enjoy VScode (or
> forks thereof). I got used to a two window workflow - Claude Code for
> AI-driven development, and Goland for making manual edits to the codebase."
> -- ch_123, HN (Jan 2026) -- 6-month CC user

> "Switched from Intellij to Cursor because of AI integration, only using
> Claude Code CLI, switched to VS because Cursor became so annoying every
> release, pushing their agents down my throat, recently thought 'Why do I
> even use that slow bloated thing?' and switched to Zed."
> -- KingOfCoders, HN (Feb 2026)

**Claude Code -> Alternatives:**

> "I've switched from Claude Code w/ Opus 4.5 to OpenCode w/ Kimi K2.5
> provided by Fireworks AI. I never run into time-based limits. And I'm
> paying a fraction of what Anthropic was charging."
> -- vuldin, HN (Feb 2026)

> "I just switched from claude code to codex and have found it to be
> incredibly impressive."
> -- sebzim4500, HN (Dec 2025)

> "Since I've just switched from buggy Claude Code to pi, I created an
> extension for it."
> -- mavam, HN (Mar 2026)

**Claude Code -> Disappointed:**

> "I recently switched from $10 Github Copilot to $20 Claude Code and so
> far haven't seen any benefits. I told it to research a subsystem and
> plan changes, but that caused it to spawn 3 subagents and consume the
> entire 4-hour token limit."
> -- arowthway, HN (Jan 2026)

---

## Pain Points (Recurring Themes)

### 1. Token Burn / Cost (THE dominant complaint)

- Workflow plugins dramatically increase token consumption
- GSD and Superpowers described as "10x token burn" vs vanilla
- Users on $20/mo plans hit limits in 30 minutes with structured workflows
- Even $200/mo Max users report concerns about drain rate
- MCP servers alone can consume 55K tokens on initialization
- Quote: "One complex prompt to Claude and you've burned 50-70% of your
  5-hour limit. Two prompts and you're done for the week."

### 2. Over-Engineering / Unnecessary Complexity

- Multiple users independently arrived at "I stripped it back to 30%"
- Superpowers criticized for writing full code in the plan, then rewriting
  it into files (double work)
- GSD called "highly overengineered" by users who tried it
- "Superpowers looks more like PM-in-a-box with AI paint"
- Counter: "thin scripts plus sane CLI tools and Git hooks will get you
  further in an afternoon"

### 3. Autonomous Agent Safety

- 70-minute loop injecting staging URLs into production config
- Agents "look busy" refactoring the same code with no real progress
- Context drift in long-running sessions
- "velocity without constraints is terrifying"

### 4. Context Window / Compaction

- Multi-agent sessions burn through 200K context in 20-30 minutes
- After 10 turns, sending 40K+ tokens per request for 200-word questions
- Compaction events lose important context
- 1M context window (March 2026) helps but doesn't solve fundamentally

### 5. Planning vs Execution Disconnect

- Plans generated by plugins often too verbose and vague
- Implementation plans that contain the actual code (defeating the purpose)
- "Ad-hoc, imprecise, and incomplete specs" from plan mode
- Gap between plan quality and execution quality

### 6. Lock-in to Opinionated Workflows

- "The best way to stay on top of changes is to not attach yourself to
  super opinionated workflows"
- Plugin updates can break custom configurations
- Telemetry concerns (gstack)
- Skills designed for one person's workflow don't generalize well

---

## Emergent Patterns

### The Convergence Point

Most experienced users are converging on the same basic structure, regardless
of which tool they use:

1. **Brainstorm/Research** -- explore the problem space
2. **Spec/Plan** -- write it down before touching code
3. **Implement** -- let the agent execute against the plan
4. **Review/Validate** -- automated checks + human review

The disagreement is about HOW MUCH structure to impose and WHERE to impose it.

### The Composition Pattern

Power users are mixing and matching rather than using monolithic plugins:
- Superpowers brainstorming + Ralph execution loops
- OpenSpec planning + Ralph implementation
- Custom CLAUDE.md + native Plan Mode + manual review
- gstack planning skills + custom QA hooks

### The Shrinkage Pattern

Repeated observation: users start with a full plugin, then strip it back:
- Install Superpowers/GSD with all features
- Hit token limits and frustration
- Strip to 30-50% of the original
- Often end up with ~3-5 custom skills + good CLAUDE.md

### The Minimum Viable Harness

What the "just use plan mode" camp actually does:
- Well-crafted CLAUDE.md with project conventions
- Native Plan Mode for scoping
- Custom skills for repeated workflows
- Hooks for safety (pre-commit, dangerous file protection)
- Manual git workflow for review checkpoints

### The Professional / Hobbyist Split

- **Professionals ($100-200/mo)**: Want maximum agent autonomy, willing to
  burn tokens, care about code quality and review processes
- **Hobbyists ($20/mo)**: Want conservative token usage, hit limits
  constantly, frustrated by plugins that "waste" their budget
- Same tool, radically different optimal configurations

---

## Implications for Harness Design

1. **Token efficiency is a first-class design constraint**, not an afterthought.
   Every layer of structure costs tokens. Users will abandon tools that burn
   limits without proportional value.

2. **Composability beats monolithic plugins.** Power users want to mix
   planning from one tool with execution from another. The tools that let
   you swap components win.

3. **The plan-implement separation is real but the implementation varies.**
   Everyone agrees on separating planning from execution. Nobody agrees on
   how heavy the planning phase should be.

4. **Skills should be opt-in and lazy-loaded.** Superpowers' approach of
   letting the agent decide what to load is praised; MCP servers that
   consume 55K tokens on init are despised.

5. **Safety/audit layers are undersupplied.** K9 Audit and similar tools
   exist because the mainstream plugins don't address autonomous agent
   safety well. This is a gap.

6. **Furrow should shrink, not grow.** Users consistently strip tools
   back. Design for the 30% that survives contact with reality, not the
   100% that looks good in a README.

7. **Platform primitives are catching up.** Plan Mode, native skills,
   channels, sub-agents, 1M context -- each platform release obsoletes
   something a plugin used to do. Design to be absorbed.

---

## Sources

### Hacker News Threads
- [Get Shit Done: Meta-prompting, context engineering, spec-driven dev](https://news.ycombinator.com/item?id=47417804) (473 pts, 254 comments)
- [gstack: Garry Tan's Claude Code Setup](https://news.ycombinator.com/item?id=47355173)
- [I was a top 0.01% Cursor user, then switched to Claude Code 2.0](https://news.ycombinator.com/item?id=46676554)
- [Ask HN: Why is my Claude experience so bad?](https://news.ycombinator.com/item?id=47000206) (84 pts, 118 comments)
- [Excessive token usage in Claude Code](https://news.ycombinator.com/item?id=47096937)
- [Anatomy of the .claude/ folder](https://news.ycombinator.com/item?id=47549393)
- [A few random notes from Claude coding](https://news.ycombinator.com/item?id=46787799)
- [Breaking the spell of vibe coding](https://news.ycombinator.com/item?id=47019317)

### Web Sources
- [Superpowers vs GStack comparison](https://particula.tech/blog/superpowers-vs-gstack-ai-coding-skill-packs)
- [Why gstack has gotten love and hate (TechCrunch)](https://techcrunch.com/2026/03/17/why-garry-tans-claude-code-setup-has-gotten-so-much-love-and-hate/)
- [Superpowers: How I'm using coding agents (Oct 2025)](https://blog.fsck.com/2025/10/09/superpowers/)
- [Why Claude Code Burns Through Tokens](https://vexp.dev/blog/claude-code-expensive-too-many-tokens)
- [HumanLayer: Skill Issue -- Harness Engineering](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- [PI Agent vs Claude Code comparison](https://github.com/disler/pi-vs-claude-code)
- [Ralph Wiggum technique](https://awesomeclaude.ai/ralph-wiggum)
- [OpenSpec workflow](https://github.com/Fission-AI/OpenSpec)
- [Boris Tane: How I use Claude Code](https://boristane.com/blog/how-i-use-claude-code/)
- [Claude Code setup guide (okhlopkov)](https://okhlopkov.com/claude-code-setup-mcp-hooks-skills-2026/)
