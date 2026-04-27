package cli

import (
	"fmt"
	"path/filepath"

	"github.com/jonathoneco/furrow/internal/cli/layer"
)

// runValidateLayerPolicy implements `furrow validate layer-policy`.
//
// Exit codes:
//   - 0: policy is valid.
//   - 3: policy fails schema/structural validation (layer_policy_invalid).
func (a *App) runValidateLayerPolicy(args []string) int {
	_, flags, err := parseArgs(args, map[string]bool{"policy": true}, nil)
	if err != nil {
		return a.fail("furrow validate layer-policy", err, false)
	}

	policyPath := flags.values["policy"]
	if policyPath == "" {
		policyPath = filepath.Join(".furrow", "layer-policy.yaml")
	}

	pol, err := layer.Load(policyPath)
	if err != nil {
		if flags.json {
			return a.fail("furrow validate layer-policy", &cliError{
				exit:    3,
				code:    "layer_policy_invalid",
				message: err.Error(),
				details: map[string]any{"path": policyPath},
			}, true)
		}
		_, _ = fmt.Fprintf(a.stderr, "layer_policy_invalid: %s\n", err.Error())
		return 3
	}

	_ = pol // policy loaded and validated successfully

	if flags.json {
		return a.okJSON("furrow validate layer-policy", map[string]any{
			"valid":  true,
			"path":   policyPath,
			"layers": []string{"operator", "driver", "engine"},
		})
	}

	_, _ = fmt.Fprintf(a.stdout, "layer-policy: valid (%s)\n", policyPath)
	return 0
}
