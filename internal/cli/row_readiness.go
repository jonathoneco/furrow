package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	yaml "gopkg.in/yaml.v3"
)

func truthGateBlockers(state map[string]any, artifacts []map[string]any) []map[string]any {
	if !rowTruthGatesRequired(state) {
		return nil
	}
	blockers := make([]map[string]any, 0)
	for _, artifact := range artifacts {
		id := getStringDefault(artifact, "id", "")
		if id != "completion-check" {
			continue
		}
		path := getStringDefault(artifact, "path", "")
		payload, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		if completionVerdict(string(payload)) == "incomplete" {
			blockers = append(blockers, map[string]any{"reason": "completion-check final verdict is incomplete", "artifact_id": id, "path": path})
		}
	}
	rowDir := filepath.Dir(getStringDefault(findArtifactByID(artifacts, "completion-check"), "path", ""))
	if rowDir == "." || rowDir == "" {
		return blockers
	}
	for _, followUp := range truthBlockingFollowUps(filepath.Join(rowDir, "follow-ups.yaml")) {
		blockers = append(blockers, followUp)
	}
	return blockers
}

func truthBlockingFollowUps(path string) []map[string]any {
	payload, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var doc map[string]any
	if err := yaml.Unmarshal(payload, &doc); err != nil {
		return []map[string]any{{"reason": fmt.Sprintf("follow-ups.yaml is invalid YAML: %v", err), "path": path}}
	}
	rawItems, ok := asSlice(doc["follow_ups"])
	if !ok {
		rawItems, ok = asSlice(doc["follow-ups"])
	}
	if !ok {
		return nil
	}
	blockers := make([]map[string]any, 0)
	for i, raw := range rawItems {
		item, ok := raw.(map[string]any)
		if !ok {
			continue
		}
		deferralClass := strings.TrimSpace(getStringDefault(item, "deferral_class", ""))
		truthImpact := strings.TrimSpace(getStringDefault(item, "truth_impact", ""))
		if deferralClass == "" || truthImpact == "" || strings.TrimSpace(getStringDefault(item, "claim_affected", "")) == "" || strings.TrimSpace(getStringDefault(item, "defer_reason", "")) == "" || strings.TrimSpace(getStringDefault(item, "graduation_trigger", "")) == "" {
			blockers = append(blockers, map[string]any{"reason": "row-local follow-up is missing deferral classification fields", "path": path, "index": i})
			continue
		}
		if deferralClass == "required_for_truth" && truthImpact == "blocks_claim" {
			blockers = append(blockers, map[string]any{
				"reason":             "truth-blocking follow-up deferred; expand work, downgrade claim, or mark row incomplete",
				"path":               path,
				"index":              i,
				"claim_affected":     item["claim_affected"],
				"deferral_class":     deferralClass,
				"truth_impact":       truthImpact,
				"graduation_trigger": item["graduation_trigger"],
			})
		}
	}
	return blockers
}
