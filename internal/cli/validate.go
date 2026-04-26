package cli

import (
	"fmt"
)

// runValidate dispatches `furrow validate <subcommand>`. The dispatcher lives
// in this dedicated file (rather than alongside D1's runValidateDefinition) so
// that D1 and D2 each own their leaf handler files cleanly while the shared
// dispatcher carries joint ownership.
//
// D3 adds: layer-policy, skill-layers, driver-definitions.
func (a *App) runValidate(args []string) int {
	const subcommands = "definition, ownership, layer-policy, skill-layers, driver-definitions"
	if len(args) == 0 {
		_, _ = fmt.Fprintf(a.stdout, "furrow validate\n\nAvailable subcommands: %s\n", subcommands)
		return 0
	}
	switch args[0] {
	case "definition":
		return a.runValidateDefinition(args[1:])
	case "ownership":
		return a.runValidateOwnership(args[1:])
	case "layer-policy":
		return a.runValidateLayerPolicy(args[1:])
	case "skill-layers":
		return a.runValidateSkillLayers(args[1:])
	case "driver-definitions":
		return a.runValidateDriverDefinitions(args[1:])
	case "help", "-h", "--help":
		_, _ = fmt.Fprintf(a.stdout, "furrow validate\n\nAvailable subcommands: %s\n", subcommands)
		return 0
	default:
		return a.fail("furrow validate", &cliError{
			exit:    1,
			code:    "usage",
			message: fmt.Sprintf("unknown validate subcommand %q", args[0]),
		}, false)
	}
}
