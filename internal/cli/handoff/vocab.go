package handoff

import "regexp"

// FurrowVocabPattern is the canonical Furrow-vocab rejection regex for
// EngineHandoff fields. This is the single source of truth referenced by
// both Go validation logic and the engine JSON Schema not.pattern constraints.
//
// Design note (post dual-review tightening):
//   - bare \bstep\b and \brow\b DROPPED — false-positive on benign English
//     ("step through the function", "row of items").
//   - Tokens retained are either compound (gate_policy), unambiguously Furrow
//     (almanac, blocker), command-prefixed (furrow row, rws ), or path-anchored
//     (\.furrow/, rationale\.yaml).
//
// The 50-string corpus test in vocab_test.go (25 must-pass benign +
// 25 must-fail Furrow-laden) verifies this pattern before enforcement turns on.
const FurrowVocabPatternStr = `(?i)\b(gate_policy|deliverable|blocker|almanac|rationale\.yaml)\b|\.furrow/|\bfurrow (row|context|handoff|hook|validate|gate)\b|\b(rws|alm|sds)\s`

// FurrowVocabPattern is the compiled form of FurrowVocabPatternStr.
var FurrowVocabPattern = regexp.MustCompile(FurrowVocabPatternStr)

// ContainsFurrowVocab reports whether s contains any Furrow-specific token
// that would make it unsuitable for an EngineHandoff field.
func ContainsFurrowVocab(s string) bool {
	return FurrowVocabPattern.MatchString(s)
}
