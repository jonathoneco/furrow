# Host Strategy Matrix

## Purpose

Define what Furrow must share across Pi and Claude Code, what may diverge, and
what can be Pi-advantaged without harming teammate compatibility.

This document intentionally distinguishes:

- **semantic parity**: required
- **artifact parity**: required
- **UX parity**: not required

## Host strategy in one sentence

Furrow should be **backend-canonical, artifact-canonical, Pi-advantaged,
Claude-compatible**.

## Matrix

| Category | Must be shared? | Pi may be better? | Claude must retain? | Notes |
|---|---:|---:|---:|---|
| `.furrow/` state model | yes | no | yes | Canonical source of truth |
| Row lifecycle semantics | yes | no | yes | Same step ordering and transition rules |
| Gate semantics | yes | no | yes | Same pass/fail/blocking meaning |
| Review artifact formats | yes | no | yes | Same files and schema contracts |
| Almanac/TODO semantics | yes | no | yes | Same roadmap/todo model |
| Seeds/task graph semantics | yes | no | yes | Same backend graph model |
| JSON CLI contracts | yes | no | yes | Shared adapter boundary |
| Exit-code meanings | yes | no | yes | Adapters need stable machine behavior |
| Install post-conditions | yes | no | yes | Mechanics may differ, outcomes should not |
| Command registration UX | no | yes | enough | Host-native registration is fine |
| Hook/event mechanism | no | yes | enough | Host event models may differ |
| Compaction delivery | no | yes | enough | Same payload, different delivery is acceptable |
| TUI/footer/status/widgets | no | yes | no | Pi can be richer |
| Subagent orchestration UX | no | yes | enough | Shared semantics, different runtime mechanics |
| Personal productivity helpers | no | yes | no | Can be Pi-only if they do not alter semantics |

## What Claude must be able to do

For teammate viability, Claude Code must remain able to:

- read and write the same `.furrow/` project state through the backend
- run or trigger the same row lifecycle operations
- preserve gate/review semantics
- participate in the same project without artifact loss or divergence
- install and operate with a stable, documented compatibility path

Claude Code does **not** need to:

- match Pi's UI richness
- match Pi's event model
- match Pi's command ergonomics exactly
- receive Pi-native features at the same time

## What Pi is allowed to do better

Pi is free to have stronger support for:

- status and footer displays
- runtime presets and modes
- richer compaction integration
- extension-driven workflows
- custom subagent orchestration surfaces
- more ergonomic command or planning flows

So long as those improvements:

1. do not change shared backend semantics
2. do not create Pi-only artifact formats
3. do not bypass the Go CLI as the semantic authority

## Design tests

### Test 1: shared-semantics test

If a feature changes:

- row behavior
- gate behavior
- review behavior
- `.furrow/` state shape
- schema or backend contract

then it belongs in the backend and must be shared.

### Test 2: Pi-advantage test

If a feature only improves:

- display
- runtime ergonomics
- command affordance
- host-native UX

then it may be Pi-only.

### Test 3: Claude-compatibility-cost test

Keep Claude compatibility if:

1. it is adapter-thin
2. it does not distort backend design
3. it does not block Pi-native improvements
4. it does not require duplicate domain logic

If one of those fails, the feature should be deferred, weakened, or dropped on
Claude rather than bending the architecture.

## Examples

### Example A — `furrow row transition --json`

- shared? yes
- backend-owned? yes
- must Claude retain it? yes
- can Pi make it nicer? yes, via better command UX

### Example B — custom Pi planning widget

- shared? no
- backend-owned? no
- must Claude retain it? no
- acceptable? yes, if it still calls the same backend commands

### Example C — compaction recovery payload

- shared payload? yes
- shared delivery mechanism? no
- acceptable? yes

### Example D — Pi-only shortcut that mutates `.furrow/` directly

- acceptable? no
- reason: it bypasses the backend and breaks the shared contract

## Practical consequence for the migration

- build the backend first
- move onto Pi early once backend calls are viable
- preserve Claude as a compatibility frontend for teammates
- do not require equal UX before leveraging Pi strengths

That is the lowest-cost way to support both people and both runtimes without
repeating the old migration spike.
