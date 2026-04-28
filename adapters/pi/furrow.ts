// Canonical repo-owned Pi adapter for Furrow.
// Keep this file thin and backend-driven: Pi owns runtime UX integration,
// while the Go CLI remains semantic authority over canonical .furrow state.
import { execFile, execFileSync } from "node:child_process";
import { promisify } from "node:util";
import { existsSync } from "node:fs";
import { join, resolve, dirname, sep } from "node:path";
import { createRequire } from "node:module";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const execFileAsync = promisify(execFile);
const require = createRequire(import.meta.url);
const KNOWN_STEPS = new Set(["ideate", "research", "plan", "spec", "decompose", "implement", "review"]);


type Envelope<T = any> = {
	ok: boolean;
	command: string;
	version: string;
	data?: T;
	error?: {
		code: string;
		message: string;
		details?: Record<string, any>;
	};
};

type DoctorCheck = {
	id: string;
	status: "pass" | "warn" | "fail";
	severity: string;
	message: string;
	details?: Record<string, any>;
};

type DoctorData = {
	host: string;
	cwd: string;
	root: string;
	summary: { pass: number; warn: number; fail: number };
	checks: DoctorCheck[];
};

type RowListEntry = {
	name: string;
	title: string;
	step: string;
	step_status: string;
	archived: boolean;
	focused: boolean;
	updated_at?: string | null;
	deliverables?: {
		total?: number;
		completed?: number;
		in_progress?: number;
	};
};

type RowListData = {
	filter: string;
	focused_row?: string | null;
	summary: { total: number; active: number; archived: number };
	rows: RowListEntry[];
	warnings?: Array<{ code?: string; message?: string; path?: string }>;
};

type RowStepArtifact = {
	id?: string;
	label: string;
	path: string;
	required?: boolean;
	exists: boolean;
	scaffold_supported?: boolean;
	incomplete?: boolean;
	validation?: {
		status?: string;
		summary?: string;
		finding_count?: number;
		findings?: Array<{ code?: string; severity?: string; message?: string }>;
	};
};

type RowStatusData = {
	resolution: {
		source: string;
		requested_row?: string | null;
		focused_row?: string | null;
	};
	row: {
		name: string;
		title: string;
		description?: string | null;
		focused: boolean;
		archived: boolean;
		step: string;
		step_status: string;
		mode?: string | null;
		branch?: string | null;
		updated_at?: string | null;
		deliverables?: {
			counts?: {
				total?: number;
				completed?: number;
				in_progress?: number;
				blocked?: number;
				not_started?: number;
				unknown?: number;
			};
			items?: Array<Record<string, any>>;
		};
		gates?: {
			count?: number;
			latest?: Record<string, any> | null;
			pending_blockers?: any[];
			transition_history?: any;
		};
		artifact_paths?: {
			row_dir?: string;
			state?: string;
			definition?: string;
			summary?: string;
			plan?: string | null;
			reviews_dir?: string | null;
		};
		current_step?: {
			name?: string;
			note?: string;
			artifacts?: RowStepArtifact[];
		};
		next_valid_transitions?: Array<{ step: string; kind?: string }>;
	};
	seed?: {
		id?: string | null;
		state?: string | null;
		status?: string | null;
		title?: string | null;
		expected_status?: string | null;
		consistent?: boolean;
		error?: string | null;
	};
	checkpoint?: {
		gate_policy?: string | null;
		boundary?: string | null;
		next_step?: string | null;
		action?: string | null;
		approval_required?: boolean;
		ready_to_advance?: boolean;
		evidence?: {
			blocker_count?: number;
			latest_gate?: Record<string, any> | null;
			latest_gate_evidence?: {
				path?: string;
				available?: boolean;
				overall?: string | null;
				reviewer?: string | null;
				timestamp?: string | null;
				phase_a?: Record<string, any>;
				error?: string;
			} | null;
			artifact_validation?: {
				by_status?: Record<string, number>;
				total?: number;
			};
			archive_ceremony?: {
				review?: {
					required?: number;
					by_status?: Record<string, number>;
				};
				follow_ups?: {
					total?: number;
					by_source?: Record<string, number>;
					by_severity?: Record<string, number>;
				};
				source_todo?: {
					id?: string | null;
					present?: boolean;
					title?: string | null;
					status?: string | null;
				};
				learnings?: {
					present?: boolean;
					count?: number;
					path?: string;
				};
			};
		};
	};
	blockers?: Array<{
		code?: string;
		category?: string;
		severity?: string;
		message?: string;
		remediation_hint?: string;
		confirmation_path?: string;
		// Sibling detail map carried alongside the canonical envelope (not part
		// of the six-field envelope contract). May contain caller-specific
		// context (path, seed_id, artifact_id, count, ...). Optional consumers.
		details?: Record<string, unknown>;
	}>;
	warnings?: Array<{ code?: string; message?: string; path?: string }>;
};

type TransitionData = {
	row: {
		name: string;
		previous_step: string;
		step: string;
		step_status: string;
		updated_at?: string | null;
	};
	changed?: string[];
	transition_record_written?: boolean;
	paths?: {
		state?: string;
	};
	limitations?: string[];
};

type CompleteData = {
	row: {
		name: string;
		step: string;
		previous_step_status?: string | null;
		step_status: string;
		updated_at?: string | null;
	};
	deliverables?: {
		before?: Record<string, number>;
		after?: Record<string, number>;
		updated?: number;
	};
	changed?: string[];
	write_performed?: boolean;
	paths?: {
		state?: string;
	};
	limitations?: string[];
	artifact_validation?: {
		by_status?: Record<string, number>;
		total?: number;
	};
};

type RowInitData = {
	row?: RowStatusData["row"];
	seed?: RowStatusData["seed"];
	paths?: {
		row_dir?: string;
		state?: string;
	};
};

type RowFocusData = {
	focused_row?: string | null;
	changed?: boolean;
	path?: string;
	warnings?: Array<{ code?: string; message?: string }>;
};

type RowScaffoldData = {
	row: {
		name: string;
		step: string;
		step_status: string;
	};
	created?: Array<{ id?: string; label?: string; path?: string }>;
	current_step_artifacts?: RowStepArtifact[];
	note?: string;
};

type ArchiveData = {
	row: {
		name: string;
		step: string;
		step_status: string;
		archived: boolean;
		archived_at?: string | null;
		updated_at?: string | null;
	};
	paths?: {
		state?: string;
		checkpoint_evidence?: string;
	};
	review_gate?: Record<string, any> | null;
	archive_ceremony?: RowStatusData["checkpoint"] extends { evidence?: infer E }
		? E extends { archive_ceremony?: infer C }
			? C
			: never
		: never;
};

import {
	decideValidateDefinitionAction,
	decideOwnershipAction,
	shouldInterceptForDefinitionValidation,
	shouldInterceptForOwnershipWarn,
	runDefinitionValidationHandler,
	runOwnershipWarnHandler,
	type ValidateDefinitionData,
	type ValidateOwnershipData,
} from "./validate-actions.ts";

type CliResult<T = any> = {
	exitCode: number;
	stdout: string;
	stderr: string;
	envelope?: Envelope<T>;
};

type ToolEvent = {
	schema_version: "tool_event.v1";
	runtime: "pi";
	event_name: "tool_call";
	tool_name: string;
	tool_input: unknown;
	agent_id?: string;
	agent_type: string;
};

type LayerVerdict = {
	block: boolean;
	reason: string;
};

type PiToolCallEvent = {
	toolName?: string;
	tool_name?: string;
	input?: unknown;
	tool_input?: unknown;
};

class FallbackText {
	constructor(
		public text: string,
		public x: number,
		public y: number,
	) {}
}

type ParsedTransitionArgs = {
	row?: string;
	step?: string;
	confirm: boolean;
	error?: string;
};

type ParsedWorkArgs = {
	row?: string;
	description?: string;
	complete: boolean;
	confirm: boolean;
	error?: string;
};

function findFurrowRoot(startCwd: string): string | undefined {
	let current = resolve(startCwd);
	while (true) {
		const candidate = join(current, ".furrow");
		if (existsSync(candidate)) return current;
		const parent = dirname(current);
		if (parent === current) return undefined;
		current = parent;
	}
}

async function runFurrowJson<T>(root: string, args: string[], signal?: AbortSignal): Promise<CliResult<T>> {
	const fullArgs = [...args];
	if (!fullArgs.includes("--json")) fullArgs.push("--json");

	let stdout = "";
	let stderr = "";
	let exitCode = 0;

	try {
		const result = await execFileAsync("go", ["run", "./cmd/furrow", ...fullArgs], {
			cwd: root,
			signal,
			maxBuffer: 1024 * 1024 * 4,
		});
		stdout = result.stdout ?? "";
		stderr = result.stderr ?? "";
	} catch (error: any) {
		if (error?.name === "AbortError") throw error;
		stdout = String(error?.stdout ?? "");
		stderr = String(error?.stderr ?? error?.message ?? "");
		exitCode = typeof error?.code === "number" ? error.code : 1;
	}

	const trimmed = stdout.trim();
	let envelope: Envelope<T> | undefined;
	if (trimmed) {
		try {
			envelope = JSON.parse(trimmed) as Envelope<T>;
		} catch (error: any) {
			throw new Error(`Failed to parse Furrow JSON from stdout: ${error?.message ?? error}`);
		}
	}

	return { exitCode, stdout, stderr, envelope };
}

function furrowBinary(): string {
	return process.env.FURROW_BIN || "furrow";
}

export function normalizePiToolEvent(event: PiToolCallEvent, ctx: Record<string, any>): ToolEvent {
	return {
		schema_version: "tool_event.v1",
		runtime: "pi",
		event_name: "tool_call",
		tool_name: event.toolName ?? event.tool_name ?? "",
		tool_input: event.input ?? event.tool_input ?? {},
		agent_id: String(ctx.agentId ?? ctx.agent_id ?? ""),
		agent_type: String(ctx.agentName ?? ctx.agent_type ?? ctx.agentType ?? "operator"),
	};
}

export async function runLayerDecisionForPi(event: PiToolCallEvent, ctx: Record<string, any>): Promise<LayerVerdict | undefined> {
	const root = findFurrowRoot(ctx.cwd ?? process.cwd());
	if (!root) return undefined;
	const toolEvent = normalizePiToolEvent(event, ctx);
	const input = JSON.stringify(toolEvent);

	try {
		const stdout = execFileSync(furrowBinary(), ["layer", "decide"], {
			cwd: root,
			input,
			encoding: "utf-8",
			timeout: 2000,
		});
		const trimmed = String(stdout ?? "").trim();
		if (!trimmed) return { block: false, reason: "" };
		return JSON.parse(trimmed) as LayerVerdict;
	} catch (error: any) {
		if (error?.code === 2 || error?.status === 2) {
			const stdout = String(error?.stdout ?? "").trim();
			if (stdout) return JSON.parse(stdout) as LayerVerdict;
			return { block: true, reason: "layer_tool_violation: layer decide exited 2" };
		}
		return undefined;
	}
}

export async function decidePiLayerAction(event: PiToolCallEvent, ctx: Record<string, any>) {
	const verdict = await runLayerDecisionForPi(event, ctx);
	if (verdict?.block) {
		if (ctx.hasUI) ctx.ui?.notify?.(verdict.reason, "warning");
		return { block: true, reason: verdict.reason };
	}
	return undefined;
}

function normalizePathArg(pathArg: unknown, cwd: string): string | undefined {
	if (typeof pathArg !== "string" || pathArg.trim() === "") return undefined;
	const raw = pathArg.startsWith("@") ? pathArg.slice(1) : pathArg;
	return resolve(cwd, raw);
}

function isCanonicalStatePath(root: string, absolutePath: string): boolean {
	const focusedPath = join(root, ".furrow", ".focused");
	if (absolutePath === focusedPath) return true;

	const rowsPrefix = join(root, ".furrow", "rows") + sep;
	return absolutePath.startsWith(rowsPrefix) && absolutePath.endsWith(`${sep}state.json`);
}

function doctorProblems(data?: DoctorData): DoctorCheck[] {
	if (!data?.checks) return [];
	return data.checks.filter((check) => check.status !== "pass");
}

function currentStepArtifacts(status?: RowStatusData): RowStepArtifact[] {
	return status?.row.current_step?.artifacts ?? [];
}

function formatDoctorProblems(data?: DoctorData): string[] {
	const problems = doctorProblems(data);
	if (problems.length === 0) return ["- none"];
	return problems.map((problem) => `- [${problem.status}] ${problem.id}: ${problem.message}`);
}

function formatStatusWarnings(data?: RowStatusData): string[] {
	const warnings = data?.warnings ?? [];
	if (warnings.length === 0) return ["- none"];
	return warnings.map((warning) => `- ${warning.code ?? "warning"}: ${warning.message ?? "unspecified warning"}`);
}

export function formatBlockers(data?: RowStatusData): string[] {
	const blockers = data?.blockers ?? [];
	if (blockers.length === 0) return ["- none"];
	return blockers.map((blocker) => {
		const prefix = [blocker.category, blocker.severity].filter(Boolean).join("/");
		// User-facing remediation prose is sourced verbatim from the canonical
		// taxonomy's `remediation_hint` field (see schemas/blocker-taxonomy.yaml).
		// Pi MUST NOT maintain its own enum→prose dictionary; the registry is
		// the single source of truth. `confirmation_path` is the enum token
		// (block/warn-with-confirm/silent) — useful for UX decoration but
		// NOT a sentence to interpolate as prose.
		const fix = blocker.remediation_hint ? ` :: fix: ${blocker.remediation_hint}` : "";
		return `- ${prefix ? `[${prefix}] ` : ""}${blocker.code ?? "blocked"}: ${blocker.message ?? "unspecified blocker"}${fix}`;
	});
}

function formatCurrentStepArtifacts(artifacts: RowStepArtifact[]): string[] {
	if (artifacts.length === 0) return ["- none defined for this step in the current backend slice"];
	return artifacts.map((artifact) => {
		const state = artifact.exists
			? (artifact.incomplete ? "present, incomplete scaffold" : "present")
			: "missing";
		const validationStatus = artifact.validation?.status ? ` :: validation=${artifact.validation.status}` : "";
		const validationSummary = artifact.validation?.finding_count
			? ` (${artifact.validation.finding_count} finding${artifact.validation.finding_count === 1 ? "" : "s"})`
			: (artifact.validation?.summary ? ` (${artifact.validation.summary})` : "");
		return `- [${state}] ${artifact.label}: ${artifact.path}${validationStatus}${validationSummary}`;
	});
}

function formatSeed(seed?: RowStatusData["seed"]): string[] {
	if (!seed?.id) {
		return ["- missing seed linkage", seed?.expected_status ? `- expected status: ${seed.expected_status}` : "- expected status: unknown"];
	}
	return [
		`- id: ${seed.id}`,
		`- state: ${seed.state ?? "unknown"}`,
		`- status: ${seed.status ?? "unknown"}`,
		`- expected: ${seed.expected_status ?? "unknown"}`,
		`- title: ${seed.title ?? "unknown"}`,
		`- consistent: ${seed.consistent ? "yes" : "no"}`,
	];
}

function formatCheckpoint(checkpoint?: RowStatusData["checkpoint"]): string[] {
	if (!checkpoint?.boundary) return ["- no next stage boundary available"];
	const lines = [
		`- boundary: ${checkpoint.boundary}`,
		`- action: ${checkpoint.action ?? (checkpoint.next_step ? "transition" : "unknown")}`,
		`- gate policy: ${checkpoint.gate_policy ?? "unknown"}`,
		`- approval required: ${checkpoint.approval_required ? "yes" : "no"}`,
		`- ready to advance: ${checkpoint.ready_to_advance ? "yes" : "no"}`,
	];
	if (checkpoint.evidence?.artifact_validation?.by_status) {
		const byStatus = checkpoint.evidence.artifact_validation.by_status;
		lines.push(`- artifact validation: pass=${byStatus.pass ?? 0} warn=${byStatus.warn ?? 0} fail=${byStatus.fail ?? 0} missing=${byStatus.missing ?? 0}`);
	}
	if (checkpoint.evidence?.latest_gate?.boundary) {
		lines.push(`- latest gate: ${checkpoint.evidence.latest_gate.boundary} (${checkpoint.evidence.latest_gate.outcome ?? "unknown"})`);
	}
	if (checkpoint.evidence?.latest_gate_evidence?.path) {
		const gateEvidence = checkpoint.evidence.latest_gate_evidence;
		lines.push(`- latest gate evidence: ${gateEvidence.path}`);
		if (gateEvidence.available) {
			lines.push(`- latest gate evidence summary: overall=${gateEvidence.overall ?? "unknown"} reviewer=${gateEvidence.reviewer ?? "unknown"}`);
		}
	}
	if (checkpoint.evidence?.archive_ceremony?.review?.by_status) {
		const review = checkpoint.evidence.archive_ceremony.review;
		const byStatus = review.by_status ?? {};
		lines.push(`- archive review evidence: required=${review.required ?? 0} pass=${byStatus.pass ?? 0} warn=${byStatus.warn ?? 0} fail=${byStatus.fail ?? 0} missing=${byStatus.missing ?? 0}`);
	}
	if (checkpoint.evidence?.archive_ceremony?.follow_ups) {
		const followUps = checkpoint.evidence.archive_ceremony.follow_ups;
		const bySource = followUps.by_source ?? {};
		lines.push(`- archive follow-ups: total=${followUps.total ?? 0} real_findings=${bySource.real_findings ?? 0} failed_dimensions=${bySource.failed_dimensions ?? 0} conditional_dimensions=${bySource.conditional_dimensions ?? 0}`);
	}
	if (checkpoint.evidence?.archive_ceremony?.source_todo?.id) {
		const sourceTodo = checkpoint.evidence.archive_ceremony.source_todo;
		lines.push(`- source todo: ${sourceTodo.id} (${sourceTodo.present ? sourceTodo.status ?? "present" : "missing"})`);
		if (sourceTodo.title) lines.push(`- source todo title: ${sourceTodo.title}`);
	}
	if (checkpoint.evidence?.archive_ceremony?.learnings) {
		const learnings = checkpoint.evidence.archive_ceremony.learnings;
		lines.push(`- learnings ready for archive review: present=${learnings.present ? "yes" : "no"} count=${learnings.count ?? 0}`);
	}
	return lines;
}

function deliverableProgress(counts?: RowStatusData["row"]["deliverables"]["counts"]): string {
	if (!counts) return "unknown";
	const completed = counts.completed ?? 0;
	const total = counts.total ?? 0;
	const inProgress = counts.in_progress ?? 0;
	return `${completed}/${total} completed, ${inProgress} in progress`;
}

function parseTransitionArgs(input: string): ParsedTransitionArgs {
	const tokens = input
		.trim()
		.split(/\s+/)
		.map((token) => token.trim())
		.filter(Boolean);

	const parsed: ParsedTransitionArgs = { confirm: false };

	for (let i = 0; i < tokens.length; i++) {
		const token = tokens[i];
		if (token === "--confirm") {
			parsed.confirm = true;
			continue;
		}
		if (token === "--step") {
			const next = tokens[i + 1];
			if (!next) {
				parsed.error = "missing value for --step";
				return parsed;
			}
			parsed.step = next;
			i++;
			continue;
		}
		if (token.startsWith("--step=")) {
			parsed.step = token.slice("--step=".length);
			continue;
		}
		if (token.startsWith("--")) {
			parsed.error = `unknown flag ${token}`;
			return parsed;
		}
		if (!parsed.row) {
			parsed.row = token;
			continue;
		}
		if (!parsed.step && KNOWN_STEPS.has(token)) {
			parsed.step = token;
			continue;
		}
		parsed.error = `unexpected argument ${token}`;
		return parsed;
	}

	return parsed;
}

function parseWorkArgs(input: string): ParsedWorkArgs {
	const tokens = input
		.trim()
		.split(/\s+/)
		.map((token) => token.trim())
		.filter(Boolean);
	const parsed: ParsedWorkArgs = { complete: false, confirm: false };
	const descriptionTokens: string[] = [];

	for (let i = 0; i < tokens.length; i++) {
		const token = tokens[i];
		if (token === "--complete") {
			parsed.complete = true;
			continue;
		}
		if (token === "--confirm") {
			parsed.confirm = true;
			continue;
		}
		if (token === "--switch" || token === "--row") {
			const next = tokens[i + 1];
			if (!next) {
				parsed.error = `missing value for ${token}`;
				return parsed;
			}
			parsed.row = next;
			i++;
			continue;
		}
		if (token.startsWith("--switch=") || token.startsWith("--row=")) {
			parsed.row = token.slice(token.indexOf("=") + 1);
			continue;
		}
		if (token.startsWith("--")) {
			parsed.error = `unknown flag ${token}`;
			return parsed;
		}
		descriptionTokens.push(token);
	}

	if (parsed.row && descriptionTokens.length > 0) {
		parsed.error = "cannot combine a row selection flag with a new-row description";
		return parsed;
	}
	if (descriptionTokens.length > 0) {
		parsed.description = descriptionTokens.join(" ");
	}
	return parsed;
}

function formatTransitionChoices(transitions?: Array<{ step: string; kind?: string }>): string[] {
	if (!transitions || transitions.length === 0) return ["- none"];
	return transitions.map((transition) => `- ${transition.step}${transition.kind ? ` (${transition.kind})` : ""}`);
}

function slugifyDescription(description: string): string {
	return description
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, 40)
		.replace(/-+$/g, "") || "work-item";
}

function pickRecommendedAction(status: RowStatusData, doctorData?: DoctorData): string {
	const row = status.row;
	const artifacts = currentStepArtifacts(status);
	const missingArtifacts = artifacts.filter((artifact) => !artifact.exists && artifact.scaffold_supported);
	const blockers = status.blockers ?? [];
	const backendProblems = doctorProblems(doctorData);

	if (backendProblems.length > 0 || blockers.length > 0) {
		return "Resolve the surfaced blockers or warnings, then rerun /work.";
	}
	if (missingArtifacts.length > 0) {
		return `Run /work to scaffold the active step artifact(s): ${missingArtifacts.map((artifact) => artifact.label).join(", ")}.`;
	}
	if (status.checkpoint?.approval_required && row.step_status === "completed" && status.checkpoint.boundary) {
		if (status.checkpoint.action === "archive") {
			return `This supervised review boundary is ready. Run /work --confirm to archive ${row.name}.`;
		}
		if (status.checkpoint.next_step) {
			return `This supervised boundary is ready. Run /work --confirm to advance from ${row.step} to ${status.checkpoint.next_step}.`;
		}
	}
	if (row.step_status !== "completed") {
		return `Continue the ${row.step} step. When the current step is done enough, run /work --complete to record completion and surface the checkpoint.`;
	}
	if (row.archived) {
		return `${row.name} is archived. Start a new row with /work <description> when you are ready for the next slice.`;
	}
	return `Stay in ${row.step} until blockers are clear or a valid next step is advertised.`;
}

function formatOverview(data: RowListData): string {
	const activeRows = data.rows.filter((row) => !row.archived);
	const archivedRows = data.rows.filter((row) => row.archived);

	const lines = [
		"Furrow overview",
		"",
		`Focused row: ${data.focused_row ?? "none"}`,
		`Summary: total=${data.summary.total} active=${data.summary.active} archived=${data.summary.archived}`,
		"",
		"Active rows:",
	];

	if (activeRows.length === 0) {
		lines.push("- none");
	} else {
		for (const row of activeRows) {
			const marker = row.focused ? "*" : "-";
			const deliverables = row.deliverables ?? {};
			lines.push(
				`${marker} ${row.name} :: ${row.step}/${row.step_status} :: deliverables ${deliverables.completed ?? 0}/${deliverables.total ?? 0} completed :: updated ${row.updated_at ?? "unknown"}`,
			);
		}
	}

	lines.push("", `Archived rows: ${archivedRows.length}`);
	if (archivedRows.length > 0) {
		lines.push("Recent archived rows:");
		for (const row of archivedRows.slice(0, 5)) {
			lines.push(`- ${row.name} :: ${row.step}/${row.step_status} :: updated ${row.updated_at ?? "unknown"}`);
		}
		if (archivedRows.length > 5) {
			lines.push(`- ... ${archivedRows.length - 5} more archived rows omitted`);
		}
	}

	if ((data.warnings?.length ?? 0) > 0) {
		lines.push("", "Warnings:");
		for (const warning of data.warnings ?? []) {
			lines.push(`- ${warning.code ?? "warning"}: ${warning.message ?? "unspecified warning"}`);
		}
	}

	return lines.join("\n");
}

function formatNextGuidance(status: RowStatusData, doctorData?: DoctorData): string {
	const row = status.row;
	const lines = [
		"Furrow next",
		"",
		`Row: ${row.name}`,
		`Title: ${row.title}`,
		`Resolution: ${status.resolution.source}`,
		`Step: ${row.step}`,
		`Step status: ${row.step_status}`,
		`Deliverables: ${deliverableProgress(row.deliverables?.counts)}`,
		"",
		"Blockers:",
		...formatBlockers(status),
		"",
		"Seed:",
		...formatSeed(status.seed),
		"",
		"Current-step artifacts:",
		...formatCurrentStepArtifacts(currentStepArtifacts(status)),
		"",
		"Checkpoint:",
		...formatCheckpoint(status.checkpoint),
		"",
		`Doctor summary: pass=${doctorData?.summary.pass ?? 0} warn=${doctorData?.summary.warn ?? 0} fail=${doctorData?.summary.fail ?? 0}`,
		"Doctor warnings/failures:",
		...formatDoctorProblems(doctorData),
		"",
		"Row warnings:",
		...formatStatusWarnings(status),
		"",
		`Recommended next action: ${pickRecommendedAction(status, doctorData)}`,
	];
	return lines.join("\n");
}

function formatTransitionResult(
	transition: TransitionData,
	status?: RowStatusData,
	doctorData?: DoctorData,
	statusWarnings: Array<{ code?: string; message?: string; path?: string }> = [],
): string {
	const lines = [
		"Furrow transition",
		"",
		`Row: ${transition.row.name}`,
		`Transition: ${transition.row.previous_step} -> ${transition.row.step}`,
		`New step status: ${transition.row.step_status}`,
		`Updated at: ${transition.row.updated_at ?? "unknown"}`,
		`State path: ${transition.paths?.state ?? "unknown"}`,
		"",
		`Doctor summary before transition: pass=${doctorData?.summary.pass ?? 0} warn=${doctorData?.summary.warn ?? 0} fail=${doctorData?.summary.fail ?? 0}`,
		"Pre-transition warnings:",
		...formatDoctorProblems(doctorData),
		...((statusWarnings.length > 0)
			? statusWarnings.map((warning) => `- [row] ${warning.code ?? "warning"}: ${warning.message ?? "unspecified warning"}`)
			: ["- [row] none"]),
		"",
		"Backend limitations:",
		...((transition.limitations ?? []).length > 0
			? (transition.limitations ?? []).map((limitation) => `- ${limitation}`)
			: ["- none reported"]),
	];
	if (status) {
		lines.push("", "Current-step artifacts after transition:", ...formatCurrentStepArtifacts(currentStepArtifacts(status)));
	}
	return lines.join("\n");
}

function formatCompletionResult(complete: CompleteData, status?: RowStatusData): string {
	const before = complete.deliverables?.before ?? {};
	const after = complete.deliverables?.after ?? {};
	const lines = [
		"Furrow complete",
		"",
		`Row: ${complete.row.name}`,
		`Step: ${complete.row.step}`,
		`Step status: ${complete.row.previous_step_status ?? "unknown"} -> ${complete.row.step_status}`,
		`Updated at: ${complete.row.updated_at ?? "unknown"}`,
		`State path: ${complete.paths?.state ?? "unknown"}`,
		"",
		`Deliverables before: ${before.completed ?? 0}/${before.total ?? 0} completed`,
		`Deliverables after: ${after.completed ?? 0}/${after.total ?? 0} completed`,
		`Deliverables updated: ${complete.deliverables?.updated ?? 0}`,
		`Write performed: ${complete.write_performed ? "yes" : "no"}`,
		"",
		"Backend limitations:",
		...((complete.limitations ?? []).length > 0
			? (complete.limitations ?? []).map((limitation) => `- ${limitation}`)
			: ["- none reported"]),
	];
	if (status) {
		lines.push("", "Current-step artifacts:", ...formatCurrentStepArtifacts(currentStepArtifacts(status)));
	}
	return lines.join("\n");
}

function formatWorkView(
	status: RowStatusData,
	options: {
		doctor?: DoctorData;
		resolvedBy?: string;
		scaffolded?: Array<{ label?: string; path?: string }>;
		completed?: boolean;
		transitionedTo?: string;
		archived?: boolean;
	}
): string {
	const row = status.row;
	const scaffolded = options.scaffolded ?? [];
	const lines = [
		"Furrow work",
		"",
		`Row: ${row.name}`,
		`Title: ${row.title}`,
		`Resolution: ${options.resolvedBy ?? status.resolution.source}`,
		`Step: ${row.step}`,
		`Step status: ${row.step_status}`,
		`Deliverables: ${deliverableProgress(row.deliverables?.counts)}`,
		"",
		"Blockers:",
		...formatBlockers(status),
		"",
		"Seed:",
		...formatSeed(status.seed),
		"",
		"Current-step artifacts:",
		...formatCurrentStepArtifacts(currentStepArtifacts(status)),
		"",
		"Checkpoint:",
		...formatCheckpoint(status.checkpoint),
		"",
		"Warnings:",
		...formatStatusWarnings(status),
	];
	if (options.doctor) {
		lines.push("", `Doctor: pass=${options.doctor.summary.pass} warn=${options.doctor.summary.warn} fail=${options.doctor.summary.fail}`);
	}
	if (scaffolded.length > 0) {
		lines.push("", "Scaffolded on entry:");
		for (const artifact of scaffolded) lines.push(`- ${artifact.label ?? "artifact"}: ${artifact.path ?? "unknown"}`);
	}
	if (options.completed) {
		lines.push("", "Current step bookkeeping was marked completed in this turn.");
	}
	if (options.transitionedTo) {
		lines.push("", `Advanced to ${options.transitionedTo} after explicit confirmation.`);
	}
	if (options.archived) {
		lines.push("", "Archived the row after explicit confirmation.");
	}
	lines.push("", `Recommended next action: ${pickRecommendedAction(status, options.doctor)}`);
	return lines.join("\n");
}

async function publish(pi: ExtensionAPI, ctx: ExtensionContext, text: string, details?: Record<string, any>) {
	if (ctx.hasUI) {
		pi.sendMessage(
			{
				customType: "furrow",
				content: text,
				display: true,
				details,
			},
			{ triggerTurn: false },
		);
		return;
	}
	process.stdout.write(text.endsWith("\n") ? text : `${text}\n`);
}

async function publishError(pi: ExtensionAPI, ctx: ExtensionContext, title: string, message: string, details?: Record<string, any>) {
	await publish(pi, ctx, `${title}\n\n${message}`, details);
}

function formatCliError<T>(result: CliResult<T>, fallback: string): string {
	if (result.envelope?.error?.message) {
		return `${result.envelope.error.message}${result.stderr ? `\n\nStderr:\n${result.stderr.trim()}` : ""}`;
	}
	if (result.stderr.trim()) return `${fallback}\n\nStderr:\n${result.stderr.trim()}`;
	if (result.stdout.trim()) return `${fallback}\n\nStdout:\n${result.stdout.trim()}`;
	return fallback;
}

async function refreshStatus(pi: ExtensionAPI, ctx: ExtensionContext) {
	if (!ctx.hasUI) return;
	const root = findFurrowRoot(ctx.cwd);
	if (!root) {
		ctx.ui.setStatus("furrow", undefined);
		return;
	}

	try {
		const result = await runFurrowJson<RowStatusData>(root, ["row", "status"]);
		if (!result.envelope?.data?.row) {
			ctx.ui.setStatus("furrow", ctx.ui.theme.fg("warning", "furrow:no-row"));
			return;
		}
		const row = result.envelope.data.row;
		const warningCount = (result.envelope.data.warnings?.length ?? 0) + (result.envelope.data.blockers?.length ?? 0);
		const color = warningCount > 0 ? "warning" : "accent";
		ctx.ui.setStatus("furrow", ctx.ui.theme.fg(color, `furrow:${row.name} ${row.step}/${row.step_status}`));
	} catch {
		ctx.ui.setStatus("furrow", ctx.ui.theme.fg("warning", "furrow:error"));
	}
}

export default function furrowExtension(pi: ExtensionAPI) {
	pi.registerMessageRenderer("furrow", (message, options, theme) => {
		let TextCtor: typeof FallbackText = FallbackText;
		try {
			TextCtor = require("@mariozechner/pi-tui").Text ?? FallbackText;
		} catch {
			TextCtor = FallbackText;
		}
		let text = `${theme.fg("accent", theme.bold("[furrow]"))}\n${String(message.content ?? "")}`;
		if (options.expanded && message.details) {
			text += `\n\n${theme.fg("dim", JSON.stringify(message.details, null, 2))}`;
		}
		return new TextCtor(text, 0, 0);
	});

	pi.on("session_start", async (_event, ctx) => {
		await refreshStatus(pi, ctx);
	});

	pi.on("tool_call", async (event, ctx) => {
		return decidePiLayerAction(event, ctx as unknown as Record<string, any>);
	});

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "edit" && event.toolName !== "write") return undefined;
		const root = findFurrowRoot(ctx.cwd);
		if (!root) return undefined;
		const absolutePath = normalizePathArg((event.input as any)?.path, ctx.cwd);
		if (!absolutePath) return undefined;
		if (!isCanonicalStatePath(root, absolutePath)) return undefined;

		if (ctx.hasUI) {
			ctx.ui.notify("Blocked direct mutation of canonical Furrow state; use the backend CLI/commands instead.", "warning");
		}
		return {
			block: true,
			reason:
				"Canonical Furrow state is backend-mediated. Use /furrow-transition, /furrow-complete, or the Furrow CLI instead of editing .furrow/.focused or row state.json directly.",
		};
	});

	// Pre-write validation handler — D4 of pre-write-validation-go-first.
	// Intercepts Write/Edit on `*/definition.yaml` and validates against the
	// canonical schema before the write proceeds. Handler logic lives in
	// runDefinitionValidationHandler (validate-actions.ts) for direct unit testing.
	pi.on("tool_call", async (event, ctx) => {
		const root = findFurrowRoot(ctx.cwd);
		if (!root) return undefined;
		const absolutePath = normalizePathArg((event.input as any)?.path, ctx.cwd);
		return runDefinitionValidationHandler(
			event.toolName,
			absolutePath,
			async (args) => {
				const result = await runFurrowJson<ValidateDefinitionData>(root, args, ctx.signal);
				return { data: result.envelope?.data };
			},
			ctx.hasUI ? ctx.ui.notify.bind(ctx.ui) : undefined,
		);
	});

	// Ownership warn handler — D5 of pre-write-validation-go-first.
	// Handler logic lives in runOwnershipWarnHandler (validate-actions.ts) for
	// direct unit testing. Step-agnostic by design (verdict comes from the Go
	// validator which never reads state.json.step).
	pi.on("tool_call", async (event, ctx) => {
		const root = findFurrowRoot(ctx.cwd);
		if (!root) return undefined;
		const absolutePath = normalizePathArg((event.input as any)?.path, ctx.cwd);
		return runOwnershipWarnHandler(
			event.toolName,
			absolutePath,
			async (args) => {
				const result = await runFurrowJson<ValidateOwnershipData>(root, args, ctx.signal);
				return { data: result.envelope?.data };
			},
			ctx.hasUI ? ctx.ui.confirm.bind(ctx.ui) : undefined,
		);
	});

	pi.registerCommand("work", {
		description: "Primary Furrow work loop: resolve or create a row, scaffold the active step artifact, and pause at supervised checkpoints",
		handler: async (args, ctx) => {
			const rawArgs = args ?? "";
			const root = findFurrowRoot(ctx.cwd);
			if (!root) {
				await publishError(pi, ctx, "Furrow work", `No .furrow root found from ${ctx.cwd}.`);
				return;
			}

			const parsed = parseWorkArgs(rawArgs);
			if (parsed.error) {
				await publishError(
					pi,
					ctx,
					"Furrow work",
					`${parsed.error}\n\nUsage: /work [description] [--switch <row>] [--complete] [--confirm]`,
				);
				return;
			}

			const doctorResult = await runFurrowJson<DoctorData>(root, ["doctor", "--host", "pi"], ctx.signal);
			const doctorData = doctorResult.envelope?.data;
			if (!doctorResult.envelope) {
				await publishError(pi, ctx, "Furrow work", formatCliError(doctorResult, "Failed to run furrow doctor."));
				return;
			}

			let resolvedBy = "status";
			let status: RowStatusData | undefined;
			let completeResult: CompleteData | undefined;
			const scaffolded: Array<{ label?: string; path?: string }> = [];
			let transitionedTo: string | undefined;
			let archived = false;
			let completed = false;

			if (parsed.description) {
				const rowName = slugifyDescription(parsed.description);
				const initResult = await runFurrowJson<RowInitData>(
					root,
					["row", "init", rowName, "--title", parsed.description],
					ctx.signal,
				);
				if (!initResult.envelope?.data) {
					await publishError(pi, ctx, "Furrow work", formatCliError(initResult, "Failed to initialize a new Furrow row."), {
						doctor: doctorResult.envelope,
					});
					return;
				}
				const focusResult = await runFurrowJson<RowFocusData>(root, ["row", "focus", rowName], ctx.signal);
				if (!focusResult.envelope?.data) {
					await publishError(pi, ctx, "Furrow work", formatCliError(focusResult, "Initialized the row but failed to focus it."), {
						init: initResult.envelope,
					});
					return;
				}
				const statusResult = await runFurrowJson<RowStatusData>(root, ["row", "status", rowName], ctx.signal);
				if (!statusResult.envelope?.data) {
					await publishError(pi, ctx, "Furrow work", formatCliError(statusResult, "Failed to read the initialized row status."), {
						init: initResult.envelope,
						focus: focusResult.envelope,
					});
					return;
				}
				status = statusResult.envelope.data;
				resolvedBy = `initialized:${rowName}`;
			} else {
				let targetRow = parsed.row;
				if (targetRow) {
					const focusResult = await runFurrowJson<RowFocusData>(root, ["row", "focus", targetRow], ctx.signal);
					if (!focusResult.envelope?.data) {
						await publishError(pi, ctx, "Furrow work", formatCliError(focusResult, `Failed to focus row ${targetRow}.`), {
							doctor: doctorResult.envelope,
						});
						return;
					}
					resolvedBy = `explicit:${targetRow}`;
				} else {
					const focusResult = await runFurrowJson<RowFocusData>(root, ["row", "focus"], ctx.signal);
					const focusedRow = focusResult.envelope?.data?.focused_row ?? undefined;
					if (focusedRow) {
						targetRow = focusedRow;
						resolvedBy = "focused";
					} else {
						const listResult = await runFurrowJson<RowListData>(root, ["row", "list", "--active"], ctx.signal);
						if (!listResult.envelope?.data) {
							await publishError(pi, ctx, "Furrow work", formatCliError(listResult, "Failed to list active Furrow rows."), {
								doctor: doctorResult.envelope,
							});
							return;
						}
						const activeRows = listResult.envelope.data.rows.filter((row) => !row.archived);
						if (activeRows.length === 0) {
							await publishError(
								pi,
								ctx,
								"Furrow work",
								"No active row is available. Start one with `/work <description>`.",
								{ doctor: doctorResult.envelope },
							);
							return;
						}
						if (activeRows.length === 1) {
							targetRow = activeRows[0]!.name;
							const setFocus = await runFurrowJson<RowFocusData>(root, ["row", "focus", targetRow], ctx.signal);
							if (!setFocus.envelope?.data) {
								await publishError(pi, ctx, "Furrow work", formatCliError(setFocus, `Failed to focus row ${targetRow}.`), {
									list: listResult.envelope,
								});
								return;
							}
							resolvedBy = "single-active";
						} else {
							if (!ctx.hasUI) {
								await publishError(
									pi,
									ctx,
									"Furrow work",
									`Multiple active rows exist. Re-run with --switch <row> in headless mode.\n\nChoices:\n${activeRows.map((row) => `- ${row.name}: ${row.step}/${row.step_status}`).join("\n")}`,
									{ list: listResult.envelope },
								);
								return;
							}
							targetRow = await ctx.ui.select(
								"Select the Furrow row to continue",
								activeRows.map((row) => row.name),
							);
							if (!targetRow) {
								await publish(pi, ctx, "Furrow work\n\nCancelled before choosing an active row.", {
									kind: "work-cancelled",
									list: listResult.envelope,
								});
								return;
							}
							const setFocus = await runFurrowJson<RowFocusData>(root, ["row", "focus", targetRow], ctx.signal);
							if (!setFocus.envelope?.data) {
								await publishError(pi, ctx, "Furrow work", formatCliError(setFocus, `Failed to focus row ${targetRow}.`), {
									list: listResult.envelope,
								});
								return;
							}
							resolvedBy = "selected-active";
						}
					}
				}

				if (!targetRow) {
					await publishError(pi, ctx, "Furrow work", "No row could be resolved.");
					return;
				}
				const statusResult = await runFurrowJson<RowStatusData>(root, ["row", "status", targetRow], ctx.signal);
				if (!statusResult.envelope?.data) {
					await publishError(pi, ctx, "Furrow work", formatCliError(statusResult, "Failed to resolve the current Furrow row."), {
						doctor: doctorResult.envelope,
					});
					return;
				}
				status = statusResult.envelope.data;
			}

			if (!status) {
				await publishError(pi, ctx, "Furrow work", "No Furrow row status could be resolved.");
				return;
			}

			let artifacts = currentStepArtifacts(status);
			if (artifacts.some((artifact) => !artifact.exists && artifact.scaffold_supported)) {
				const scaffoldResult = await runFurrowJson<RowScaffoldData>(root, ["row", "scaffold", status.row.name], ctx.signal);
				if (!scaffoldResult.envelope?.data) {
					await publishError(pi, ctx, "Furrow work", formatCliError(scaffoldResult, "Failed to scaffold the active step artifact."), {
						status,
					});
					return;
				}
				scaffolded.push(...(scaffoldResult.envelope.data.created ?? []));
				const refreshedStatus = await runFurrowJson<RowStatusData>(root, ["row", "status", status.row.name], ctx.signal);
				if (refreshedStatus.envelope?.data) status = refreshedStatus.envelope.data;
				artifacts = currentStepArtifacts(status);
			}

			if (parsed.complete) {
				const completeEnvelope = await runFurrowJson<CompleteData>(root, ["row", "complete", status.row.name], ctx.signal);
				if (!completeEnvelope.envelope?.data) {
					await publishError(pi, ctx, "Furrow work", formatCliError(completeEnvelope, "Failed to complete current-step bookkeeping."), {
						status,
					});
					return;
				}
				completeResult = completeEnvelope.envelope.data;
				completed = true;
				const refreshedStatus = await runFurrowJson<RowStatusData>(root, ["row", "status", status.row.name], ctx.signal);
				if (refreshedStatus.envelope?.data) status = refreshedStatus.envelope.data;
			}

			if (status.row.step_status === "completed" && status.checkpoint?.boundary && (status.blockers?.length ?? 0) === 0) {
				let confirmed = parsed.confirm;
				const checkpointTarget = status.checkpoint.action === "archive"
					? `archive ${status.row.name}`
					: `advance to ${status.checkpoint.next_step}`;
				const checkpointText = [
					`Boundary: ${status.checkpoint.boundary ?? `${status.row.step}->${status.checkpoint.next_step ?? "archive"}`}`,
					`Action: ${status.checkpoint.action ?? "transition"}`,
					`Gate policy: ${status.checkpoint.gate_policy ?? "unknown"}`,
					"",
					"Seed:",
					...formatSeed(status.seed),
					"",
					"Current-step artifacts:",
					...formatCurrentStepArtifacts(currentStepArtifacts(status)),
				].join("\n");
				if (!confirmed) {
					if (ctx.hasUI) {
						confirmed = await ctx.ui.confirm("Confirm supervised Furrow checkpoint", checkpointText);
					} else {
						await publish(
							pi,
							ctx,
							`${formatWorkView(status, { doctor: doctorData, resolvedBy, scaffolded, completed })}\n\nSupervised checkpoint requires explicit confirmation. Re-run with --confirm to ${checkpointTarget}.`,
							{ kind: "work-pending-confirmation", status },
						);
						await refreshStatus(pi, ctx);
						return;
					}
				}
				if (confirmed) {
					if (status.checkpoint.action === "archive") {
						const archiveResult = await runFurrowJson<ArchiveData>(
							root,
							["row", "archive", status.row.name],
							ctx.signal,
						);
						if (!archiveResult.envelope?.data) {
							await publishError(pi, ctx, "Furrow work", formatCliError(archiveResult, "Failed to archive at the supervised checkpoint."), {
								status,
							});
							return;
						}
						archived = true;
						const refreshedStatus = await runFurrowJson<RowStatusData>(root, ["row", "status", status.row.name], ctx.signal);
						if (refreshedStatus.envelope?.data) status = refreshedStatus.envelope.data;
					} else if (status.checkpoint.next_step) {
						const transitionResult = await runFurrowJson<TransitionData>(
							root,
							["row", "transition", status.row.name, "--step", status.checkpoint.next_step],
							ctx.signal,
						);
						if (!transitionResult.envelope?.data) {
							await publishError(pi, ctx, "Furrow work", formatCliError(transitionResult, "Failed to advance at the supervised checkpoint."), {
								status,
							});
							return;
						}
						transitionedTo = status.checkpoint.next_step;
						const refreshedStatus = await runFurrowJson<RowStatusData>(root, ["row", "status", status.row.name], ctx.signal);
						if (refreshedStatus.envelope?.data) status = refreshedStatus.envelope.data;
						if (currentStepArtifacts(status).some((artifact) => !artifact.exists && artifact.scaffold_supported)) {
							const scaffoldResult = await runFurrowJson<RowScaffoldData>(root, ["row", "scaffold", status.row.name], ctx.signal);
							if (scaffoldResult.envelope?.data) {
								scaffolded.push(...(scaffoldResult.envelope.data.created ?? []));
								const refreshedAfterScaffold = await runFurrowJson<RowStatusData>(root, ["row", "status", status.row.name], ctx.signal);
								if (refreshedAfterScaffold.envelope?.data) status = refreshedAfterScaffold.envelope.data;
							}
						}
					}
				}
			}

			await publish(
				pi,
				ctx,
				formatWorkView(status, { doctor: doctorData, resolvedBy, scaffolded, completed, transitionedTo, archived }),
				{
					kind: "work",
					doctor: doctorResult.envelope,
					status,
					complete: completeResult,
					resolvedBy,
					scaffolded,
					transitionedTo,
					archived,
				},
			);
			await refreshStatus(pi, ctx);
		},
	});

	pi.registerCommand("furrow-overview", {
		description: "Show a compact Furrow overview from the backend row list",
		handler: async (args, ctx) => {
			const rawArgs = args ?? "";
			const root = findFurrowRoot(ctx.cwd);
			if (!root) {
				await publishError(pi, ctx, "Furrow overview", `No .furrow root found from ${ctx.cwd}.`);
				return;
			}

			const tokens = rawArgs
				.trim()
				.split(/\s+/)
				.map((token) => token.trim())
				.filter(Boolean);
			const validFlags = new Set(["--active", "--archived", "--all"]);
			const flags = tokens.filter((token) => validFlags.has(token));
			const invalid = tokens.filter((token) => !validFlags.has(token));
			if (invalid.length > 0) {
				await publishError(
					pi,
					ctx,
					"Furrow overview",
					`Unknown arguments: ${invalid.join(", ")}\n\nUsage: /furrow-overview [--active|--archived|--all]`,
				);
				return;
			}

			const result = await runFurrowJson<RowListData>(root, ["row", "list", ...flags], ctx.signal);
			if (!result.envelope?.data) {
				await publishError(pi, ctx, "Furrow overview", formatCliError(result, "Failed to read Furrow row list."));
				return;
			}

			await publish(pi, ctx, formatOverview(result.envelope.data), { kind: "overview", data: result.envelope.data });
			await refreshStatus(pi, ctx);
		},
	});

	pi.registerCommand("furrow-next", {
		description: "Show current row guidance, warnings, next transitions, and canonical row artifacts",
		handler: async (args, ctx) => {
			const rawArgs = args ?? "";
			const root = findFurrowRoot(ctx.cwd);
			if (!root) {
				await publishError(pi, ctx, "Furrow next", `No .furrow root found from ${ctx.cwd}.`);
				return;
			}

			const explicitRow = rawArgs.trim() || undefined;
			const doctorResult = await runFurrowJson<DoctorData>(root, ["doctor", "--host", "pi"], ctx.signal);
			const doctorData = doctorResult.envelope?.data;
			if (!doctorResult.envelope) {
				await publishError(pi, ctx, "Furrow next", formatCliError(doctorResult, "Failed to run furrow doctor."));
				return;
			}

			const statusArgs = explicitRow ? ["row", "status", explicitRow] : ["row", "status"];
			const statusResult = await runFurrowJson<RowStatusData>(root, statusArgs, ctx.signal);
			if (!statusResult.envelope?.data) {
				await publishError(pi, ctx, "Furrow next", formatCliError(statusResult, "Failed to read Furrow row status."), {
					doctor: doctorResult.envelope,
				});
				return;
			}

			await publish(pi, ctx, formatNextGuidance(statusResult.envelope.data, doctorData), {
				kind: "next",
				doctor: doctorResult.envelope,
				status: statusResult.envelope,
			});
			await refreshStatus(pi, ctx);
		},
	});

	pi.registerCommand("furrow-complete", {
		description: "Complete current row bookkeeping through the backend without editing state files directly",
		handler: async (args, ctx) => {
			const rawArgs = args ?? "";
			const root = findFurrowRoot(ctx.cwd);
			if (!root) {
				await publishError(pi, ctx, "Furrow complete", `No .furrow root found from ${ctx.cwd}.`);
				return;
			}

			const tokens = rawArgs
				.trim()
				.split(/\s+/)
				.map((token) => token.trim())
				.filter(Boolean);
			if (tokens.length > 1 || tokens.some((token) => token.startsWith("--"))) {
				await publishError(pi, ctx, "Furrow complete", "Usage: /furrow-complete [row-name]");
				return;
			}

			const explicitRow = tokens[0] || undefined;
			const statusArgs = explicitRow ? ["row", "status", explicitRow] : ["row", "status"];
			const statusResult = await runFurrowJson<RowStatusData>(root, statusArgs, ctx.signal);
			if (!statusResult.envelope?.data) {
				await publishError(pi, ctx, "Furrow complete", formatCliError(statusResult, "Failed to resolve the current Furrow row."));
				return;
			}

			const status = statusResult.envelope.data;
			const row = status.row;
			const completeResult = await runFurrowJson<CompleteData>(root, ["row", "complete", row.name], ctx.signal);
			if (!completeResult.envelope?.data) {
				await publishError(
					pi,
					ctx,
					"Furrow complete",
					formatCliError(completeResult, "Backend bookkeeping update failed."),
					{ status: statusResult.envelope },
				);
				return;
			}

			await publish(pi, ctx, formatCompletionResult(completeResult.envelope.data, statusResult.envelope.data), {
				kind: "complete",
				status: statusResult.envelope,
				complete: completeResult.envelope,
			});
			await refreshStatus(pi, ctx);
		},
	});

	pi.registerCommand("furrow-transition", {
		description: "Run a backend-mediated Furrow row transition with explicit confirmation",
		handler: async (args, ctx) => {
			const rawArgs = args ?? "";
			const root = findFurrowRoot(ctx.cwd);
			if (!root) {
				await publishError(pi, ctx, "Furrow transition", `No .furrow root found from ${ctx.cwd}.`);
				return;
			}

			const parsed = parseTransitionArgs(rawArgs);
			if (parsed.error) {
				await publishError(
					pi,
					ctx,
					"Furrow transition",
					`${parsed.error}\n\nUsage: /furrow-transition [row-name] [--step <step>] [--confirm]`,
				);
				return;
			}

			const doctorResult = await runFurrowJson<DoctorData>(root, ["doctor", "--host", "pi"], ctx.signal);
			if (!doctorResult.envelope) {
				await publishError(pi, ctx, "Furrow transition", formatCliError(doctorResult, "Failed to run furrow doctor."));
				return;
			}
			const doctorData = doctorResult.envelope.data;

			const statusArgs = parsed.row ? ["row", "status", parsed.row] : ["row", "status"];
			const statusResult = await runFurrowJson<RowStatusData>(root, statusArgs, ctx.signal);
			if (!statusResult.envelope?.data) {
				await publishError(pi, ctx, "Furrow transition", formatCliError(statusResult, "Failed to resolve the current Furrow row."), {
					doctor: doctorResult.envelope,
				});
				return;
			}

			const status = statusResult.envelope.data;
			const row = status.row;
			const transitions = row.next_valid_transitions ?? [];
			if (transitions.length === 0) {
				await publishError(
					pi,
					ctx,
					"Furrow transition",
					`Row ${row.name} has no backend-advertised next valid transition.\n\nCurrent step: ${row.step}/${row.step_status}`,
					{ doctor: doctorResult.envelope, status: statusResult.envelope },
				);
				return;
			}

			let targetStep = parsed.step;
			if (!targetStep && transitions.length === 1) {
				targetStep = transitions[0].step;
			}
			if (!targetStep && transitions.length > 1) {
				if (!ctx.hasUI) {
					await publishError(
						pi,
						ctx,
						"Furrow transition",
						`Multiple backend-advertised transitions are available. Re-run with --step <step> in headless mode.\n\nChoices:\n${formatTransitionChoices(transitions).join("\n")}`,
					);
					return;
				}
				targetStep = await ctx.ui.select(
					`Select next step for ${row.name}`,
					transitions.map((transition) => transition.step),
				);
				if (!targetStep) {
					await publish(pi, ctx, "Furrow transition\n\nCancelled before selecting a target step.", {
						kind: "transition-cancelled",
						status: statusResult.envelope,
					});
					return;
				}
			}

			if (!targetStep) {
				await publishError(pi, ctx, "Furrow transition", "No target step could be resolved.");
				return;
			}

			if (!transitions.some((transition) => transition.step === targetStep)) {
				await publishError(
					pi,
					ctx,
					"Furrow transition",
					`Step ${targetStep} is not in the backend-advertised next valid transitions for ${row.name}.\n\nChoices:\n${formatTransitionChoices(transitions).join("\n")}`,
				);
				return;
			}

			let confirmed = parsed.confirm;
			if (!confirmed) {
				const confirmationText = [
					`Transition row ${row.name}?`,
					"",
					`Current: ${row.step}/${row.step_status}`,
					`Next: ${targetStep}`,
					`Doctor: pass=${doctorData?.summary.pass ?? 0} warn=${doctorData?.summary.warn ?? 0} fail=${doctorData?.summary.fail ?? 0}`,
					"",
					"Doctor warnings/failures:",
					...formatDoctorProblems(doctorData),
					"",
					"Row warnings:",
					...formatStatusWarnings(status),
				].join("\n");

				if (ctx.hasUI) {
					confirmed = await ctx.ui.confirm("Confirm Furrow transition", confirmationText);
				} else {
					await publishError(
						pi,
						ctx,
						"Furrow transition",
						`${confirmationText}\n\nHeadless mode requires explicit confirmation. Re-run with --confirm to perform the backend transition.`,
						{ kind: "transition-pending-confirmation", doctor: doctorResult.envelope, status: statusResult.envelope },
					);
					return;
				}
			}

			if (!confirmed) {
				await publish(pi, ctx, "Furrow transition\n\nTransition cancelled. No backend mutation was performed.", {
					kind: "transition-cancelled",
					doctor: doctorResult.envelope,
					status: statusResult.envelope,
				});
				return;
			}

			const transitionResult = await runFurrowJson<TransitionData>(
				root,
				["row", "transition", row.name, "--step", targetStep],
				ctx.signal,
			);
			if (!transitionResult.envelope?.data) {
				await publishError(
					pi,
					ctx,
					"Furrow transition",
					formatCliError(transitionResult, "Backend transition failed."),
					{ doctor: doctorResult.envelope, status: statusResult.envelope },
				);
				return;
			}

			await publish(
				pi,
				ctx,
				formatTransitionResult(
					transitionResult.envelope.data,
					statusResult.envelope.data,
					doctorData,
					status.warnings ?? [],
				),
				{
					kind: "transition",
					doctor: doctorResult.envelope,
					status: statusResult.envelope,
					transition: transitionResult.envelope,
				},
			);
			await refreshStatus(pi, ctx);
		},
	});
}
