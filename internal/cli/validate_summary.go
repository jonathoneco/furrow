package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// handleStopSummaryValidation implements the Go port of validate-summary.sh
// (research/hook-audit.md §2.9). The hook fires on Stop and emits one or
// more block-severity envelopes per missing/empty required section.
//
// Skip conditions (clean pass — return nil, nil):
//   - summary.md is absent.
//   - last_decided_by == "prechecked" (pre-step evaluation skipped the step).
//
// Required sections per validate-summary.sh:46:
//
//	Task, Current State, Artifact Paths, Settled Decisions,
//	Key Findings, Open Questions, Recommendations
//
// Step-aware content check: the agent-written sections (Key Findings,
// Open Questions, Recommendations) need >= 1 non-empty content line. In
// the ideate step, only Open Questions has content requirements.
//
// Multi-emit: this handler may return more than one envelope (one per
// missing/empty section). Stdout JSON-array shape is the contract.
func handleStopSummaryValidation(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	row, err := requireString(evt.Payload, "row")
	if err != nil {
		return nil, err
	}

	if asString(evt.Payload["last_decided_by"]) == "prechecked" {
		return nil, nil
	}

	summaryPath := asString(evt.Payload["summary_path"])
	if summaryPath == "" {
		root, rootErr := correctionLimitRoot()
		if rootErr != nil {
			return nil, nil
		}
		summaryPath = filepath.Join(root, ".furrow", "rows", row, "summary.md")
	}

	payload, err := os.ReadFile(summaryPath)
	if err != nil {
		// summary.md absent is the clean-pass case (matches the shell hook).
		return nil, nil
	}
	step := asString(evt.Payload["step"])

	required := []string{
		"Task", "Current State", "Artifact Paths", "Settled Decisions",
		"Key Findings", "Open Questions", "Recommendations",
	}
	contentRequired := []string{"Key Findings", "Open Questions", "Recommendations"}

	sections := markdownSections(string(payload))

	envelopes := make([]BlockerEnvelope, 0, len(required))
	for _, name := range required {
		if _, present := sections[name]; !present {
			envelopes = append(envelopes, tx.EmitBlocker("summary_section_missing", map[string]string{
				"section": name,
				"path":    summaryPath,
			}))
		}
	}
	for _, name := range contentRequired {
		if step == "ideate" && name != "Open Questions" {
			continue
		}
		body, present := sections[name]
		if !present {
			// Already reported as missing; skip the empty-content check.
			continue
		}
		if summarySectionContentLineCount(body) < 1 {
			envelopes = append(envelopes, tx.EmitBlocker("summary_section_empty", map[string]string{
				"section":        name,
				"path":           summaryPath,
				"actual_count":   "0",
				"required_count": "1",
			}))
		}
	}
	if len(envelopes) == 0 {
		return nil, nil
	}
	return envelopes, nil
}

// summarySectionContentLineCount counts non-empty content lines in a
// markdown section body. Matches the awk filter at validate-summary.sh:62
// (`found && /[^ ]/ { count++ }` — any line containing a non-space char).
func summarySectionContentLineCount(body string) int {
	count := 0
	for _, line := range strings.Split(body, "\n") {
		if strings.TrimSpace(line) != "" {
			count++
		}
	}
	return count
}

// summaryMissingSections is exported-via-package for handleStopWorkCheck
// (work-check.sh subset). Returned slice is the names of required sections
// absent from the file. Errors reading the file are returned as-is.
func summaryMissingSections(summaryPath string, sections []string) ([]string, error) {
	payload, err := os.ReadFile(summaryPath)
	if err != nil {
		return nil, err
	}
	parsed := markdownSections(string(payload))
	missing := make([]string, 0, len(sections))
	for _, s := range sections {
		if _, ok := parsed[s]; !ok {
			missing = append(missing, s)
		}
	}
	return missing, nil
}

// summarySectionContentSparse reports sections whose content has fewer
// non-empty lines than the threshold. Used by handleStopWorkCheck.
func summarySectionContentSparse(summaryPath string, sections []string, threshold int) ([]string, error) {
	payload, err := os.ReadFile(summaryPath)
	if err != nil {
		return nil, err
	}
	parsed := markdownSections(string(payload))
	sparse := make([]string, 0, len(sections))
	for _, s := range sections {
		body, ok := parsed[s]
		if !ok {
			continue
		}
		if summarySectionContentLineCount(body) < threshold {
			sparse = append(sparse, s)
		}
	}
	return sparse, nil
}

// _ keeps fmt referenced when the package compiles minimally (in case
// future helpers are removed). No runtime cost.
var _ = fmt.Sprintf
