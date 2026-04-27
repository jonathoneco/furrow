package handoff

import (
	"embed"
	"errors"
	"fmt"
)

// ErrUnknownReturnFormat is returned by ResolveReturnFormat when the given
// return-format ID does not correspond to a known schema file.
var ErrUnknownReturnFormat = errors.New("unknown return format")

// returnFormatFS holds the compiled-in return-format schema files.
// Schemas are embedded from internal/cli/handoff/return-formats/, which mirrors
// the canonical templates/handoffs/return-formats/ directory at the repo root.
// Using embed.FS matches the //go:embed pattern used in render.go for templates,
// ensuring the validator works without a filesystem layout at runtime.
//
// Parity between this embedded set and the repo-root schemas is enforced by
// TestReturnFormatEmbedParity in return_format_test.go.
//
//go:embed return-formats/*.json
var returnFormatFS embed.FS

// returnFormatDir is the directory path within returnFormatFS where schemas live.
const returnFormatDir = "return-formats"

// ResolveReturnFormat checks whether the given return-format ID resolves to a
// known schema file in the embedded return-formats/{id}.json set.
//
// Returns nil if the schema exists, or an error wrapping ErrUnknownReturnFormat
// if it does not. Callers should emit a handoff_schema_invalid envelope on error.
func ResolveReturnFormat(id string) error {
	path := fmt.Sprintf("%s/%s.json", returnFormatDir, id)
	_, err := returnFormatFS.Open(path)
	if err != nil {
		return fmt.Errorf("return_format %q: schema not found at %s: %w", id, path, ErrUnknownReturnFormat)
	}
	return nil
}
