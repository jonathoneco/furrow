// Canonical repo-owned Pi adapter for Furrow.
// Keep this file thin and backend-driven: Pi owns runtime UX integration,
// while the Go CLI remains semantic authority over canonical .furrow state.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync } from "node:fs";
import { join, resolve, dirname, sep } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

const execFileAsync = promisify(execFile);
const KNOWN_STEPS = new Set(["ideate", "research", "plan", "spec", "decompose", "implement", "review"]);

const REQUIRED_ROW_ARTIFACTS = [
	{ key: "definition", label: "definition", file: "definition.yaml" },
	{ key: "summary", label: "summary", file: "summary.md" },
] as const;

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
		next_valid_transitions?: Array<{ step: string; kind?: string }>;
	};
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
};

type CliResult<T = any> = {
	exitCode: number;
	stdout: string;
	stderr: string;
	envelope?: Envelope<T>;
};

type ParsedTransitionArgs = {
	row?: string;
	step?: string;
	confirm: boolean;
	error?: string;
};

type RowArtifact = {
	label: string;
	path: string;
	exists: boolean;
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

function buildRequiredRowArtifacts(rowDir?: string | null): RowArtifact[] {
	if (!rowDir) return [];
	return REQUIRED_ROW_ARTIFACTS.map((artifact) => {
		const path = join(rowDir, artifact.file);
		return {
			label: artifact.label,
			path,
			exists: existsSync(path),
		};
	});
}

function doctorProblems(data?: DoctorData): DoctorCheck[] {
	if (!data?.checks) return [];
	return data.checks.filter((check) => check.status !== "pass");
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

function formatRequiredArtifacts(artifacts: RowArtifact[]): string[] {
	if (artifacts.length === 0) return ["- no row_dir available from backend status"];
	return artifacts.map((artifact) => `- [${artifact.exists ? "present" : "missing"}] ${artifact.label}: ${artifact.path}`);
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

function formatTransitionChoices(transitions?: Array<{ step: string; kind?: string }>): string[] {
	if (!transitions || transitions.length === 0) return ["- none"];
	return transitions.map((transition) => `- ${transition.step}${transition.kind ? ` (${transition.kind})` : ""}`);
}

function pickRecommendedAction(
	status: RowStatusData,
	doctorData?: DoctorData,
	requiredArtifacts: RowArtifact[] = [],
): string {
	const row = status.row;
	const missingArtifacts = requiredArtifacts.filter((artifact) => !artifact.exists);
	const backendProblems = doctorProblems(doctorData);
	const rowWarnings = status.warnings ?? [];
	const transitions = row.next_valid_transitions ?? [];

	if (backendProblems.length > 0 || rowWarnings.length > 0) {
		return "Resolve the surfaced Furrow warnings first, then rerun /furrow-next.";
	}
	if (missingArtifacts.length > 0) {
		return `Create or update the missing canonical row artifacts before changing state: ${missingArtifacts.map((artifact) => artifact.path).join(", ")}.`;
	}
	if (transitions.length > 0) {
		return `If ${row.step} work is complete, the backend-advertised next transition is ${transitions[0].step}. Run /furrow-transition${row.name ? ` ${row.name}` : ""} --step ${transitions[0].step} when ready.`;
	}
	if (row.step_status !== "completed") {
		return `No backend-advertised next transition is available. If ${row.step} work is done and only canonical bookkeeping remains, run /furrow-complete${row.name ? ` ${row.name}` : ""}.`;
	}
	return `No backend-advertised next transition is available. Continue work in ${row.step} and keep the row artifacts current.`;
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
	const requiredArtifacts = buildRequiredRowArtifacts(row.artifact_paths?.row_dir);
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
		`Doctor summary: pass=${doctorData?.summary.pass ?? 0} warn=${doctorData?.summary.warn ?? 0} fail=${doctorData?.summary.fail ?? 0}`,
		"Doctor warnings/failures:",
		...formatDoctorProblems(doctorData),
		"",
		"Row warnings:",
		...formatStatusWarnings(status),
		"",
		"Next valid transitions:",
		...formatTransitionChoices(row.next_valid_transitions),
		"",
		"Backend artifact paths:",
		`- row_dir: ${row.artifact_paths?.row_dir ?? "missing"}`,
		`- state: ${row.artifact_paths?.state ?? "missing"}`,
		`- definition: ${row.artifact_paths?.definition ?? "missing"}`,
		`- summary: ${row.artifact_paths?.summary ?? "missing"}`,
		`- plan: ${row.artifact_paths?.plan ?? "n/a"}`,
		`- reviews_dir: ${row.artifact_paths?.reviews_dir ?? "n/a"}`,
		"",
		"Core canonical row artifacts:",
		...formatRequiredArtifacts(requiredArtifacts),
		"",
		`Recommended next action: ${pickRecommendedAction(status, doctorData, requiredArtifacts)}`,
	];
	return lines.join("\n");
}

function formatTransitionResult(
	transition: TransitionData,
	rowDir?: string | null,
	doctorData?: DoctorData,
	statusWarnings: Array<{ code?: string; message?: string; path?: string }> = [],
): string {
	const artifacts = buildRequiredRowArtifacts(rowDir);
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
		"",
		"Update these canonical row artifacts next:",
		...formatRequiredArtifacts(artifacts),
	];
	return lines.join("\n");
}

function formatCompletionResult(complete: CompleteData, rowDir?: string | null): string {
	const artifacts = buildRequiredRowArtifacts(rowDir);
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
		"",
		"Keep these canonical row artifacts current:",
		...formatRequiredArtifacts(artifacts),
	];
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
		const warningCount = result.envelope.data.warnings?.length ?? 0;
		const color = warningCount > 0 ? "warning" : "accent";
		ctx.ui.setStatus("furrow", ctx.ui.theme.fg(color, `furrow:${row.name} ${row.step}/${row.step_status}`));
	} catch {
		ctx.ui.setStatus("furrow", ctx.ui.theme.fg("warning", "furrow:error"));
	}
}

export default function furrowExtension(pi: ExtensionAPI) {
	pi.registerMessageRenderer("furrow", (message, options, theme) => {
		let text = `${theme.fg("accent", theme.bold("[furrow]"))}\n${String(message.content ?? "")}`;
		if (options.expanded && message.details) {
			text += `\n\n${theme.fg("dim", JSON.stringify(message.details, null, 2))}`;
		}
		return new Text(text, 0, 0);
	});

	pi.on("session_start", async (_event, ctx) => {
		await refreshStatus(pi, ctx);
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

			await publish(pi, ctx, formatCompletionResult(completeResult.envelope.data, row.artifact_paths?.row_dir), {
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
					row.artifact_paths?.row_dir,
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
