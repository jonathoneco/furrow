package main

import (
	"os"

	"github.com/jonathoneco/furrow/internal/cli"
)

func main() {
	app := cli.NewWithStdin(os.Stdin, os.Stdout, os.Stderr)
	os.Exit(app.Run(os.Args[1:]))
}
