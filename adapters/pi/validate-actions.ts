// validate-actions.ts — Pure verdict→action mappings for D4 (validate-definition)
// and D5 (ownership-warn) tool_call handlers. Extracted into a dependency-free
// module so unit tests under furrow.test.ts can import them without pulling in
// the @mariozechner/pi-tui runtime dependency that furrow.ts itself uses.
//
// Part of pre-write-validation-go-first (D4/D5).

export type Notify = (message: string, level: "error" | "warning" | "info") => void;
export type Confirm = (title: string, body: string) => Promise<boolean>;

export type ValidationErrorEnvelope = {
	code: string;
	category: string;
	severity: string;
	message: string;
	remediation_hint: string;
	confirmation_path: string;
};

export type ValidateDefinitionData = {
	verdict: "valid" | "invalid";
	errors?: ValidationErrorEnvelope[];
};

export type ValidateOwnershipData = {
	verdict: "in_scope" | "out_of_scope" | "not_applicable";
	matched_deliverable?: string;
	matched_glob?: string;
	reason?: string;
	envelope?: ValidationErrorEnvelope;
};

// HandlerAction is the result a tool_call handler returns: undefined (no
// opinion / silent allow), or { block: true, reason } / { block: false } to
// signal the Pi runtime explicitly.
export type HandlerAction = undefined | { block: true; reason: string } | { block: false };

// decideValidateDefinitionAction is the pure verdict→action mapping for D4's
// validate-definition handler. Pure function: maps the Go validator's envelope
// data + an optional notify sink to a Pi handler action.
export function decideValidateDefinitionAction(
	data: ValidateDefinitionData | undefined,
	notify?: Notify,
): HandlerAction {
	if (!data || data.verdict === "valid") return undefined;
	const errors = data.errors ?? [];
	const lines = errors.map((e) => {
		const hint = e.remediation_hint ? ` (hint: ${e.remediation_hint})` : "";
		return `${e.message}${hint}`;
	});
	const message = lines.join("; ") || "definition.yaml validation failed";
	if (notify) notify(message, "error");
	return { block: true, reason: message };
}

// shouldInterceptForDefinitionValidation reports whether D4's handler should
// fire on a given tool event. Mirrors the real handler's path-filter gate
// (toolName ∈ {edit, write} AND target path ends with /definition.yaml) so
// tests can verify the gating behavior independently of the runtime.
export function shouldInterceptForDefinitionValidation(
	toolName: string,
	absolutePath: string | undefined,
): boolean {
	if (toolName !== "edit" && toolName !== "write") return false;
	if (!absolutePath) return false;
	return absolutePath.endsWith("/definition.yaml");
}

// shouldInterceptForOwnershipWarn reports whether D5's handler should fire on
// a given tool event. Mirrors the real handler's path-filter gate (any
// edit/write with a non-empty target path).
export function shouldInterceptForOwnershipWarn(
	toolName: string,
	absolutePath: string | undefined,
): boolean {
	if (toolName !== "edit" && toolName !== "write") return false;
	if (!absolutePath) return false;
	return true;
}

// decideOwnershipAction is the pure verdict→action mapping for D5's
// ownership-warn handler. Pure async function: maps the Go validator's envelope
// data + an optional confirm sink to a Pi handler action. When confirm is
// absent (no UI), out_of_scope degrades to silent allow ({ block: false })
// rather than blocking.
export async function decideOwnershipAction(
	data: ValidateOwnershipData | undefined,
	confirm?: Confirm,
): Promise<HandlerAction> {
	if (!data || data.verdict !== "out_of_scope") return undefined;
	const message = data.envelope?.message ?? "file is outside file_ownership for any deliverable in the active row";
	if (!confirm) return { block: false };
	const proceed = await confirm(
		"This file is outside the deliverable file_ownership. Proceed anyway?",
		message,
	);
	if (proceed) return { block: false };
	return { block: true, reason: message };
}
