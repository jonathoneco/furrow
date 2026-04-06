# Agent Tool Isolation Findings

## Test Methodology
Spawned a subagent via Agent tool mid-conversation and asked it to report what context it could access.

## What Subagents CAN Access
- Full file system (read any file on disk)
- CLAUDE.md instructions (global + project)
- Memory files (MEMORY.md + individual memory files)
- MCP server config and tools (Serena, context7)
- Available skills list
- Git status snapshot

## What Subagents CANNOT Access
- Conversation history between user and assistant
- Prior tool call results from parent session
- Implicit framing or decisions made during conversation
- Any context beyond the explicit prompt + system injections

## Isolation Hierarchy

| Mechanism | Conversation | System Context | File Access |
|-----------|-------------|----------------|-------------|
| Agent tool subagent | Isolated | Inherited (CLAUDE.md, memory, MCP) | Full |
| `claude -p` | Isolated | Inherited | Full |
| `claude -p --bare` | Isolated | Stripped (no CLAUDE.md, no memory, no MCP) | Full |
| `claude -p --bare --mcp-config X` | Isolated | Stripped + specific MCP only | Full |

## Implications for Furrow

### Gate Evaluations (mid-step gates)
Agent tool subagents are **sufficient** for gate evaluation. The gate-evaluator contract's
isolation claims are correct — subagents don't see conversation history, only what's
explicitly passed in the prompt. The system context (CLAUDE.md) is acceptable since it
contains project instructions, not conversation-specific bias.

### Final Review (Phase B)
`claude -p --bare` is recommended for Phase B review. It provides:
1. No conversation history (same as Agent tool)
2. No system context that could bias evaluation (CLAUDE.md contains Furrow instructions
   that might influence how the reviewer interprets artifacts)
3. Explicit control over MCP tools via `--mcp-config`
4. Cost capping via `--max-budget-usd`

### Recommendation
- **Gate evaluations**: Continue using Agent tool subagents (sufficient isolation)
- **Final review Phase B**: Use `claude -p --bare` (maximum isolation)
- **Update gate-evaluator.md**: Clarify that "fresh context" means no conversation history
  but system context is inherited. This is adequate for gate evaluation.

## Sources Consulted
- Primary: Empirical test (spawned Agent tool subagent, verified context access)
- Primary: `claude --help` output (CLI flags and behavior)
- Primary: gate-evaluator.md (existing isolation contract)
