/**
 * Furrow Pi Extension — driver/engine lifecycle bridge.
 *
 * Integrates @tintinweb/pi-subagents into the Furrow 3-layer orchestration model
 * (operator → phase driver → engine).
 *
 * ## Recursive-Spawn Verification (0.6.1)
 *
 * VERDICT: FALLBACK_NEEDED
 *
 * Read: node_modules/@tintinweb/pi-subagents/src/agent-runner.ts
 *
 * Finding: `EXCLUDED_TOOL_NAMES = ["Agent", "get_subagent_result", "steer_subagent"]`
 * is applied at session creation time (line ~287):
 *   `if (EXCLUDED_TOOL_NAMES.includes(t)) return false`
 * This strips the `Agent` tool from every spawned subagent's active tool set,
 * preventing recursive spawn via the Agent tool.
 *
 * Additionally, the parent's `tool_call` extension event bus does not reach inside
 * subprocess-spawned subagents — only main-thread tool calls fire extension hooks.
 *
 * Implication for driver→engine path:
 * - Drivers CANNOT dispatch engines by calling the `Agent` tool from within pi-subagents.
 * - Fallback: engines are dispatched as separate `pi` subprocess invocations
 *   (per the pi-mono example pattern), receiving the EngineHandoff markdown as input.
 * - Engine isolation is preserved by D1's EngineHandoff content discipline (no .furrow/ paths)
 *   plus D3's post-hoc boundary leakage test.
 *
 * This limitation is documented here; D3 owns the full capability-gap documentation
 * in docs/architecture/orchestration-delegation-contract.md.
 *
 * ## Architecture
 *
 * This extension hooks two Pi lifecycle events:
 *
 * 1. `before_agent_start` — when Pi starts a subagent named "driver:{step}":
 *    - Reads .furrow/drivers/driver-{step}.yaml for tools_allowlist and model
 *    - Reads skills/{step}.md for the driver brief (system prompt)
 *    - Returns { systemPrompt, tools } to Pi for session configuration
 *
 * 2. `tool_call` — forwards each tool call to `furrow hook layer-guard` (D3) via
 *    stdin JSON matching Claude's PreToolUse hook payload shape. When D3's
 *    `furrow hook layer-guard` is not yet installed (W5), this is a no-op.
 *    Forward-compatible: when D3 ships, the exec just works.
 *
 * ## PiAdapter Interface (internal boundary)
 *
 * The exported `FurrowPiAdapter` class wraps the @tintinweb/pi-subagents API
 * behind a thin interface so the dep is swappable per constraint.
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

// ---------------------------------------------------------------------------
// Internal types (forward-compatible with D3's layer-guard hook)
// ---------------------------------------------------------------------------

/** Payload shape matching Claude's PreToolUse hook input (and Pi's tool_call mirror). */
interface LayerGuardPayload {
  hook_event_name: "PreToolUse";
  tool_name: string;
  tool_input: unknown;
  agent_id: string;
  /** driver:{step} | engine:{id} | operator */
  agent_type: string;
}

/** Response from `furrow hook layer-guard`. */
interface LayerGuardVerdict {
  block: boolean;
  reason: string;
}

// ---------------------------------------------------------------------------
// YAML micro-parser (no external dep — drivers only use simple scalar values)
// ---------------------------------------------------------------------------

interface DriverDef {
  name: string;
  step: string;
  tools_allowlist: string[];
  model: string;
}

/** Minimal YAML parser for driver YAML files (scalar strings + string arrays only). */
function parseDriverYaml(yaml: string): DriverDef {
  const lines = yaml.split("\n");
  const result: Record<string, string | string[]> = {};
  let inList: string | null = null;
  const list: string[] = [];

  for (const line of lines) {
    if (line.trim().startsWith("#") || !line.trim()) continue;
    const listItem = line.match(/^\s+-\s+(.+)$/);
    if (listItem && inList) {
      list.push(listItem[1]!.trim());
      continue;
    }
    if (inList !== null) {
      result[inList] = [...list];
      list.length = 0;
      inList = null;
    }
    const kv = line.match(/^([a-z_]+):\s*(.*)$/);
    if (!kv) continue;
    const key = kv[1]!;
    const val = kv[2]!.trim();
    if (val === "") {
      inList = key;
    } else {
      result[key] = val;
    }
  }
  if (inList !== null) result[inList] = [...list];

  return {
    name: String(result["name"] ?? ""),
    step: String(result["step"] ?? ""),
    tools_allowlist: Array.isArray(result["tools_allowlist"]) ? result["tools_allowlist"] : [],
    model: String(result["model"] ?? "sonnet"),
  };
}

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

function findFurrowRoot(cwd: string): string | undefined {
  let current = resolve(cwd);
  for (;;) {
    if (existsSync(join(current, ".furrow"))) return current;
    const parent = join(current, "..");
    if (parent === current) return undefined;
    current = parent;
  }
}

function readDriverYaml(root: string, agentName: string): DriverDef | undefined {
  // agentName expected: "driver:{step}"
  const match = agentName.match(/^driver:([a-z]+)$/);
  if (!match) return undefined;
  const step = match[1]!;
  const driverPath = join(root, ".furrow", "drivers", `driver-${step}.yaml`);
  if (!existsSync(driverPath)) return undefined;
  return parseDriverYaml(readFileSync(driverPath, "utf-8"));
}

function readSkill(root: string, step: string): string | undefined {
  const skillPath = join(root, "skills", `${step}.md`);
  if (!existsSync(skillPath)) return undefined;
  return readFileSync(skillPath, "utf-8");
}

// ---------------------------------------------------------------------------
// Layer-guard hook integration (forward-compatible stub for D3)
// ---------------------------------------------------------------------------

/** Call `furrow hook layer-guard` with the given payload.
 *
 * Implements D3 boundary enforcement for the Pi adapter. The payload shape
 * is identical to Claude's PreToolUse hook JSON, ensuring cross-adapter parity:
 * both adapters call the same Go binary with the same stdin shape, so verdict
 * logic is never duplicated.
 *
 * Exit-code semantics mirror Claude hook protocol:
 *   - exit 0 (or error from binary not found) → allow
 *   - exit 2 with JSON stdout containing block:true → block
 *
 * Pi capability gap: this hook fires on main-thread tool calls only.
 * Subprocess-spawned subagents are blind to the parent hook bus — see module
 * docstring and docs/architecture/orchestration-delegation-contract.md §7.
 */
function callLayerGuard(payload: LayerGuardPayload): LayerGuardVerdict | undefined {
  const input = JSON.stringify(payload);
  const res = execFileSync("furrow", ["hook", "layer-guard"], {
    input,
    encoding: "utf-8",
    timeout: 2000,
  });
  // furrow hook layer-guard exits 0 and emits nothing on allow.
  // If we reach here (no thrown error), the call succeeded with exit 0 → allow.
  try {
    const verdict = JSON.parse(res) as LayerGuardVerdict;
    return verdict;
  } catch {
    // Exit 0 with empty/non-JSON stdout → allow.
    return { block: false, reason: "" };
  }
}

// ---------------------------------------------------------------------------
// PiAdapter — thin interface wrapping @tintinweb/pi-subagents
// ---------------------------------------------------------------------------

/** Minimal context shape passed by Pi to before_agent_start. */
interface AgentStartContext {
  agentName: string;
  agentId: string;
  cwd: string;
}

/** Return value for before_agent_start hook — overrides system prompt and tools. */
interface AgentStartOverrides {
  systemPrompt?: string;
  tools?: string[];
}

/** Minimal context shape passed by Pi to tool_call hook. */
interface ToolCallContext {
  agentName: string;
  agentId: string;
  cwd: string;
}

/** Tool call event from Pi. */
interface ToolCallEvent {
  tool_name: string;
  tool_input: unknown;
}

/** Deny result — returned to block a tool call. */
interface DenyResult {
  block: true;
  reason: string;
}

/**
 * FurrowPiAdapter — internal interface boundary for Pi adapter functionality.
 * Wraps @tintinweb/pi-subagents so the dep is swappable.
 *
 * NOTE: Recursive-spawn (driver→engine via Agent tool) is NOT supported by
 * @tintinweb/pi-subagents 0.6.1 — see module-level docstring for fallback.
 */
export class FurrowPiAdapter {
  /** Handle before_agent_start for Furrow-managed drivers. */
  async beforeAgentStart(
    ctx: AgentStartContext,
  ): Promise<AgentStartOverrides | undefined> {
    const root = findFurrowRoot(ctx.cwd);
    if (!root) return undefined;

    const driverDef = readDriverYaml(root, ctx.agentName);
    if (!driverDef) return undefined; // not a Furrow driver agent

    const skill = readSkill(root, driverDef.step);
    return {
      systemPrompt: skill ?? `# Phase Driver Brief: ${driverDef.step}\n\nYou are the ${driverDef.step} phase driver.`,
      tools: driverDef.tools_allowlist,
    };
  }

  /**
   * Handle tool_call for layer-guard enforcement (D3).
   *
   * Normalizes Pi's tool_call event into Claude's PreToolUse JSON shape and
   * executes `furrow hook layer-guard` synchronously. Identical payload shape
   * ensures cross-adapter parity: same Go binary, same stdin structure, same
   * verdict logic — no duplication.
   *
   * Enforcement scope: main-thread (operator) tool calls only. Subprocess
   * subagents spawned via pi-subagents are invisible to the parent hook bus.
   * See Pi capability gap documentation in
   * docs/architecture/orchestration-delegation-contract.md §7.
   */
  async onToolCall(
    ctx: ToolCallContext,
    event: ToolCallEvent,
  ): Promise<DenyResult | undefined> {
    const payload: LayerGuardPayload = {
      hook_event_name: "PreToolUse",
      tool_name: event.tool_name,
      tool_input: event.tool_input ?? {},
      agent_id: ctx.agentId,
      agent_type: ctx.agentName,  // "driver:{step}" | "engine:{id}" | "operator"
    };

    try {
      const verdict = callLayerGuard(payload);
      if (verdict?.block) {
        return { block: true, reason: verdict.reason };
      }
    } catch (err: unknown) {
      // execFileSync throws on non-zero exit. Parse stdout from the error for
      // the block reason (furrow hook layer-guard exits 2 + JSON on block).
      const anyErr = err as { stdout?: string; status?: number };
      if (anyErr.status === 2 && anyErr.stdout) {
        try {
          const verdict = JSON.parse(anyErr.stdout) as LayerGuardVerdict;
          if (verdict.block) {
            return { block: true, reason: verdict.reason };
          }
        } catch {
          return { block: true, reason: `layer_tool_violation: layer-guard exited 2` };
        }
      }
      // furrow binary not installed or other error → fail-open (allow).
      // Log but do not block — avoids breaking Pi usage in non-Furrow projects.
    }
    return undefined;
  }

  /**
   * Dispatch an engine as a subprocess (fallback for recursive-spawn limitation).
   *
   * Because @tintinweb/pi-subagents strips the `Agent` tool from subagents,
   * engine dispatch must be done via a separate `pi` process invocation.
   * The engine receives the EngineHandoff markdown as its input prompt.
   *
   * Engine isolation is preserved by D1's EngineHandoff content discipline.
   */
  dispatchEngineAsSubprocess(
    engineHandoffMarkdown: string,
    options: { cwd?: string; timeout?: number } = {},
  ): string {
    try {
      const result = execFileSync("pi", ["--prompt", engineHandoffMarkdown], {
        cwd: options.cwd,
        timeout: options.timeout ?? 120000,
        encoding: "utf-8",
      });
      return result;
    } catch (err: unknown) {
      throw new Error(
        `Engine subprocess dispatch failed: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Pi extension entry point
// ---------------------------------------------------------------------------

// The extension export pattern depends on the pi-subagents version and the Pi
// runtime's extension API. Since @tintinweb/pi-subagents 0.6.1 does not
// export a `defineExtension` factory (the pattern is internal to pi-mono),
// we export a factory function that accepts the Pi extension registration API.
//
// When integrated with the Pi runtime, wire this via the pi-subagents
// before_agent_start and tool_call hooks documented in pi-mono.

/** Factory: create and register the Furrow extension hooks. */
export function createFurrowExtension() {
  const adapter = new FurrowPiAdapter();

  return {
    name: "furrow",

    /** Wire before_agent_start to inject driver system prompt and tool allowlist. */
    before_agent_start: (ctx: AgentStartContext) => adapter.beforeAgentStart(ctx),

    /** Wire tool_call to forward to furrow hook layer-guard (D3 W5 stub). */
    tool_call: (ctx: ToolCallContext, event: ToolCallEvent) =>
      adapter.onToolCall(ctx, event),
  };
}

export default createFurrowExtension;
