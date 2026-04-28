package project

import (
	"errors"
	"os"
	"path/filepath"
)

// FindFurrowRoot walks up from cwd looking for a .furrow/ directory.
func FindFurrowRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	current := cwd
	for {
		candidate := filepath.Join(current, ".furrow")
		if info, err := os.Stat(candidate); err == nil && info.IsDir() {
			return current, nil
		}
		next := filepath.Dir(current)
		if next == current {
			return "", errors.New(".furrow root not found")
		}
		current = next
	}
}
