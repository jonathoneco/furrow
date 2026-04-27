package main

import (
	"os"

	"github.com/jonathoneco/furrow/internal/cli"
)

func main() {
	app := cli.NewWithStdin(os.Stdout, os.Stderr, os.Stdin)
	os.Exit(app.Run(os.Args[1:]))
}
