package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// handleStopWorkCheck implements the warn-only health check from
// work-check.sh (research/hook-audit.md §2.11). Per shared-contracts §C1,
// each invocation processes a single row (caller iterates active rows).
//
// Multi-emit: returns up to three envelopes per row:
//   - state_validation_failed_warn  if state.json failed schema validation
//   - summary_section_missing_warn  if any required section is absent
//   - summary_section_empty_warn    if any agent-written section has < 2
//     non-empty content lines
//
// All emissions are severity=warn / confirmation_path=silent — the shell
// caller surfaces them as `[furrow:warning] ...` lines and exits 0.
//
// The handler does NOT touch the row's `updated_at` timestamp — that
// side-effect is split into its own follow-up TODO per audit §2.11
// quality finding.
func handleStopWorkCheck(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	row, err := requireString(evt.Payload, "row")
	if err != nil {
		return nil, err
	}

	envelopes := make([]BlockerEnvelope, 0, 3)

	// state.json validation result is decided by the caller (the shim
	// runs the validator and passes the outcome). Default true (no
	// failure) when the key is absent so handlers driven from a minimal
	// payload don't false-positive.
	stateOK := true
	if v, ok := evt.Payload["state_validation_ok"]; ok {
		if b, isBool := v.(bool); isBool {
			stateOK = b
		}
	}
	if !stateOK {
		envelopes = append(envelopes, tx.EmitBlocker("state_validation_failed_warn", map[string]string{
			"row": row,
		}))
	}

	summaryPath := asString(evt.Payload["summary_path"])
	if summaryPath == "" {
		root, rootErr := correctionLimitRoot()
		if rootErr == nil {
			summaryPath = filepath.Join(root, ".furrow", "rows", row, "summary.md")
		}
	}
	if summaryPath != "" {
		if _, err := os.Stat(summaryPath); err == nil {
			required := []string{
				"Task", "Current State", "Artifact Paths",
				"Settled Decisions", "Key Findings", "Open Questions",
			}
			if missing, err := summaryMissingSections(summaryPath, required); err == nil && len(missing) > 0 {
				envelopes = append(envelopes, tx.EmitBlocker("summary_section_missing_warn", map[string]string{
					"row":     row,
					"missing": strings.Join(missing, " "),
				}))
			}
			agentSections := []string{"Key Findings", "Open Questions", "Recommendations"}
			if sparse, err := summarySectionContentSparse(summaryPath, agentSections, 2); err == nil {
				for _, name := range sparse {
					envelopes = append(envelopes, tx.EmitBlocker("summary_section_empty_warn", map[string]string{
						"row":            row,
						"section":        name,
						"required_count": "2",
					}))
				}
			}
		}
	}

	if len(envelopes) == 0 {
		return nil, nil
	}
	return envelopes, nil
}

// _ silences unused-import diagnostics if a future refactor removes the
// only consumer of fmt. Cheap belt-and-braces against drift.
var _ = fmt.Sprintf
