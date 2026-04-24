# Core vs Adapter Boundary

## Decision

Furrow should be structured as:

- **core/backend**: Go CLI + schemas + canonical filesystem model
- **adapter/claude-code**: Claude Code-specific commands, hooks, prompt wiring,
  and install integration
- **adapter/pi**: Pi package / extension implementing Pi-native UX on top of the
  same backend contract

The portability research branch is useful as an architectural input, but not as
an implementation baseline.

## Canonical source of truth

The canonical source of truth remains the project filesystem:

- `.furrow/rows/`
- `.furrow/almanac/`
- `.furrow/seeds/`
- `.furrow/.focused`

Adapters may cache, render, or mirror state transiently inside a host session,
but they must not become authoritative.

## Core responsibilities

Core/backend owns:

- row lifecycle rules
- step ordering and transition validation
- state mutation
- summary regeneration
- definition / state / review schema validation
- gate orchestration
- review bookkeeping
- almanac validation and mutation
- seed lifecycle
- merge/archive semantics
- install/doctor checks that are host-agnostic
- JSON contracts consumed by adapters

If a feature mutates `.furrow/` or defines workflow semantics, it belongs in the
core.

## Adapter responsibilities

### Claude Code adapter

Owns:

- `.claude/CLAUDE.md` integration
- `.claude/commands/` registration/discovery
- `.claude/settings.json` hook wiring
- host-specific shell bridges where needed
- Claude-native UX for `/furrow:*` and specialist dispatch

### Pi adapter

Owns:

- Pi package / extension manifest
- Pi command registration
- Pi event/hook registration
- Pi-specific UI/TUI affordances
- Pi subagent composition
- Pi install wiring and host preflights

## Boundary rules

### 1. Adapters call the core; core does not call adapters

Dependency direction is one-way:

`adapter -> core`

The backend must not import or depend on Pi- or Claude-specific runtime code.

### 2. Adapters do not re-implement domain rules

Adapters may validate event payloads and translate host-native data into the
backend contract, but they should not own:

- row transition semantics
- gate rules
- review verdict logic
- almanac semantics
- summary or state file structure

### 3. Host-native UX may differ

Behavioral parity should exist at the workflow level, not at the pixel or
prompt-delivery level.

Acceptable differences:

- command registration mechanism
- hook/event names
- compaction delivery mechanics
- TUI rendering
- subagent wiring details

Unacceptable differences:

- one host bypassing gates
- one host mutating state outside the CLI
- one host using a different row lifecycle
- one host writing incompatible `.furrow/` state

### 4. JSON is the adapter contract

Adapters should prefer structured CLI calls such as:

- `furrow almanac validate --json`
- `furrow row list --json`
- `furrow row status --json`
- `furrow row transition <row> --step implement --json`
- `furrow doctor --host pi --json`

Current implemented backend slice note:

- the minimum shared slice currently makes `almanac validate`, `row list`,
  `row status`, `row transition`, and `doctor` real enough for early adapter
  consumption
- deeper `gate` and `review` command groups remain future backend work and
  should not be reimplemented inside adapters meanwhile

### 5. Shell scripts become migration shims, not long-term core

Existing shell scripts are acceptable transition mechanisms, but the target end
state is:

- Go owns domain semantics
- shell wraps or delegates
- TypeScript adapters stay thin

## Repo-shape target

A practical target structure is:

```text
cmd/
  furrow/
internal/
  row/
  gate/
  review/
  almanac/
  seeds/
  merge/
  doctor/
schemas/
references/
skills/
adapters/
  claude-code/
  pi/
bin/
  furrow
  frw
  rws
  alm
  sds
```

Notes:

- `skills/` and `references/` remain shared content, not adapter-specific copies.
- `adapters/claude-code/` and `adapters/pi/` should contain wiring, not domain
  logic.
- compatibility wrappers in `bin/` remain during migration.

## What to salvage from the portability research

Useful to carry forward:

- the idea of a thin host-adapter surface
- explicit host parity expectations
- normalized tool metadata concepts
- compaction and command-surface analysis
- dual-host validation mindset

Do **not** carry forward unchanged:

- the speculative Pi extension implementation shape
- invented TS interfaces that are not validated against current Pi APIs
- any adapter code that duplicates backend semantics

## Immediate implication for sequencing

1. land hygiene/foundation fixes
2. define the Go CLI contract
3. move domain logic behind that contract
4. preserve Claude through wrappers and existing UX
5. build the real Pi adapter against the stable backend

That order keeps Furrow's durable value in the backend while leaving runtime UX
replaceable.
