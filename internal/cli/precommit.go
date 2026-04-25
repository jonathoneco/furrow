package cli

import (
	"path/filepath"
	"strings"
)

// handlePreCommitBakfiles implements the Go port of pre-commit-bakfiles.sh
// (research/hook-audit.md §2.3). Multi-emit: one envelope per offending
// staged path matching `bin/*.bak` or `.claude/rules/*.bak`.
func handlePreCommitBakfiles(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	paths, err := requireArray(evt.Payload, "staged_paths")
	if err != nil {
		return nil, err
	}
	envelopes := make([]BlockerEnvelope, 0)
	for _, raw := range paths {
		path, ok := raw.(string)
		if !ok || path == "" {
			continue
		}
		if !precommitBakfileMatches(path) {
			continue
		}
		envelopes = append(envelopes, tx.EmitBlocker("precommit_install_artifact_staged", map[string]string{
			"path": path,
		}))
	}
	if len(envelopes) == 0 {
		return nil, nil
	}
	return envelopes, nil
}

// precommitBakfileMatches mirrors the case glob from
// pre-commit-bakfiles.sh:27: `bin/*.bak` (single segment) or
// `.claude/rules/*.bak` (single segment).
func precommitBakfileMatches(path string) bool {
	if !strings.HasSuffix(path, ".bak") {
		return false
	}
	if matched, _ := filepath.Match("bin/*.bak", path); matched {
		return true
	}
	if matched, _ := filepath.Match(".claude/rules/*.bak", path); matched {
		return true
	}
	return false
}

// handlePreCommitTypechange implements the Go port of
// pre-commit-typechange.sh (research/hook-audit.md §2.5). Multi-emit:
// one envelope per typechange-to-symlink on a protected path.
//
// Payload contract: `typechange_entries` is an array of objects with
// at minimum `{path, new_mode, status}` keys. The shim parses
// `git diff --cached --raw` once and emits the structured list, so
// the Go handler is free of git plumbing.
func handlePreCommitTypechange(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	entries, err := requireArray(evt.Payload, "typechange_entries")
	if err != nil {
		return nil, err
	}
	envelopes := make([]BlockerEnvelope, 0)
	for _, raw := range entries {
		entry, ok := raw.(map[string]any)
		if !ok {
			continue
		}
		path := asString(entry["path"])
		newMode := asString(entry["new_mode"])
		status := asString(entry["status"])
		if path == "" || newMode != "120000" || status != "T" {
			continue
		}
		if !precommitTypechangeProtected(path) {
			continue
		}
		envelopes = append(envelopes, tx.EmitBlocker("precommit_typechange_to_symlink", map[string]string{
			"path": path,
		}))
	}
	if len(envelopes) == 0 {
		return nil, nil
	}
	return envelopes, nil
}

// precommitTypechangeProtected mirrors `_is_protected` from
// pre-commit-typechange.sh:25-32.
func precommitTypechangeProtected(path string) bool {
	switch path {
	case "bin/alm", "bin/rws", "bin/sds":
		return true
	}
	if strings.HasPrefix(path, ".claude/rules/") {
		return true
	}
	return false
}

// handlePreCommitScriptModes implements the Go port of
// pre-commit-script-modes.sh (research/hook-audit.md §2.4). Multi-emit:
// one envelope per offending bin/frw.d/scripts/*.sh entry at index
// mode 100644.
//
// Payload contract: `script_modes` is an array of `{path, mode}` objects.
// The shim runs `git ls-files -s` once per staged path and emits the
// structured list, so the Go handler is git-free.
func handlePreCommitScriptModes(tx *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error) {
	entries, err := requireArray(evt.Payload, "script_modes")
	if err != nil {
		return nil, err
	}
	envelopes := make([]BlockerEnvelope, 0)
	for _, raw := range entries {
		entry, ok := raw.(map[string]any)
		if !ok {
			continue
		}
		path := asString(entry["path"])
		mode := asString(entry["mode"])
		if path == "" || mode == "" {
			continue
		}
		if !precommitScriptUnderManagedDir(path) {
			continue
		}
		if mode == "100755" {
			continue
		}
		envelopes = append(envelopes, tx.EmitBlocker("precommit_script_mode_invalid", map[string]string{
			"path": path,
			"mode": mode,
		}))
	}
	if len(envelopes) == 0 {
		return nil, nil
	}
	return envelopes, nil
}

// precommitScriptUnderManagedDir matches `bin/frw.d/scripts/*.sh`
// (single segment) per pre-commit-script-modes.sh:41.
func precommitScriptUnderManagedDir(path string) bool {
	if !strings.HasSuffix(path, ".sh") {
		return false
	}
	matched, _ := filepath.Match("bin/frw.d/scripts/*.sh", path)
	return matched
}
