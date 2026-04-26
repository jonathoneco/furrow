// Package handoff defines forked DriverHandoff and EngineHandoff schemas.
// NO shared base struct: divergence is intentional. DriverHandoff is
// Furrow-aware (knows row/step). EngineHandoff is Furrow-unaware
// (drivers curate context per the architecture contract).
package handoff

// DriverHandoff is the priming payload from operator -> driver. 7 fields.
type DriverHandoff struct {
	Target       string   `json:"target"`        // ^driver:{step}$
	Step         string   `json:"step"`          // 7-step enum
	Row          string   `json:"row"`           // kebab-case row name
	Objective    string   `json:"objective"`     // step-scoped
	Grounding    string   `json:"grounding"`     // single path -> D4 bundle
	Constraints  []string `json:"constraints"`   // row-level
	ReturnFormat string   `json:"return_format"` // ID -> return-formats/{id}.json
}

// EngineHandoff is the dispatch payload from driver -> engine. 6 fields.
// FURROW-UNAWARE BY CONSTRUCTION: schema validation rejects any
// .furrow/ path or Furrow vocab token in objective, constraints, or grounding.
type EngineHandoff struct {
	Target       string                `json:"target"`       // ^engine:{specialist}|engine:freeform$
	Objective    string                `json:"objective"`    // task-scoped, no Furrow framing
	Deliverables []EngineDeliverable   `json:"deliverables"` // {name, ac, file_ownership}
	Constraints  []string              `json:"constraints"`  // engine-scoped
	Grounding    []EngineGroundingItem `json:"grounding"`    // curated source-file refs
	ReturnFormat string                `json:"return_format"`
}

// EngineDeliverable is one deliverable assigned to an engine target.
type EngineDeliverable struct {
	Name               string   `json:"name"`
	AcceptanceCriteria []string `json:"acceptance_criteria"`
	FileOwnership      []string `json:"file_ownership"`
}

// EngineGroundingItem is one source-file reference in an EngineHandoff.
type EngineGroundingItem struct {
	Path        string `json:"path"`
	WhyRelevant string `json:"why_relevant"`
}
