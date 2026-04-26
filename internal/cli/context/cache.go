package context

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// Cache provides content-addressed caching for context bundles.
// Cache key = sha256(row || step || target || sorted content-hashes of inputs).
// Invalidation: any input mtime > cache mtime, OR state.json mtime > cache mtime.
// Atomic writes via temp-file rename (concurrent-writer safe).
type Cache struct {
	root string // furrow root (parent of .furrow/)
}

// NewCache constructs a Cache rooted at the given furrow root.
func NewCache(root string) *Cache {
	return &Cache{root: root}
}

func (c *Cache) cacheDir(row string) string {
	return filepath.Join(c.root, ".furrow", "cache", "context-bundles", row)
}

func (c *Cache) cachePath(key string) string {
	// 8-hex prefix fanout for filesystem performance.
	prefix := key[:8]
	return filepath.Join(c.cacheDir(key[:8]), prefix+"-"+key+".json")
}

// Key computes the cache key for the given (row, step, target) + input file paths.
// Input paths are sorted before hashing for determinism.
func Key(row, step, target string, inputPaths []string) (string, error) {
	h := sha256.New()
	_, _ = fmt.Fprintf(h, "%s\x00%s\x00%s\x00", row, step, target)

	sorted := make([]string, len(inputPaths))
	copy(sorted, inputPaths)
	sort.Strings(sorted)

	for _, p := range sorted {
		contentHash, err := hashFile(p)
		if err != nil {
			if os.IsNotExist(err) {
				// Missing input: record a sentinel so key differs from "empty".
				_, _ = fmt.Fprintf(h, "MISSING:%s\x00", p)
				continue
			}
			return "", fmt.Errorf("cache key: hash %s: %w", p, err)
		}
		_, _ = fmt.Fprintf(h, "%s:%s\x00", p, contentHash)
	}

	return hex.EncodeToString(h.Sum(nil)), nil
}

// hashFile returns the sha256 hex digest of the file at path.
func hashFile(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// Load attempts to load a cached Bundle for the given key.
// Returns (nil, nil) on cache miss; (nil, err) on a read error worth surfacing.
// Validates cache freshness against stateJSONPath mtime.
func (c *Cache) Load(key, row string, inputPaths []string) (*Bundle, error) {
	path := c.cachePath(key)
	cacheInfo, err := os.Stat(path)
	if err != nil {
		// Cache miss (file does not exist or unreadable).
		return nil, nil //nolint:nilerr
	}
	cacheMtime := cacheInfo.ModTime()

	// Coarse invalidation: if state.json is newer than the cache, bust.
	statePath := filepath.Join(c.root, ".furrow", "rows", row, "state.json")
	if stateInfo, err := os.Stat(statePath); err == nil {
		if stateInfo.ModTime().After(cacheMtime) {
			return nil, nil // cache miss: state changed
		}
	}

	// Fine-grained: check each input file mtime.
	for _, p := range inputPaths {
		info, err := os.Stat(p)
		if err != nil {
			continue // missing input → recompute
		}
		if info.ModTime().After(cacheMtime) {
			return nil, nil // cache miss: input changed
		}
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, nil //nolint:nilerr // unreadable → recompute
	}
	var b Bundle
	if err := json.Unmarshal(data, &b); err != nil {
		return nil, nil //nolint:nilerr // unparseable → recompute
	}
	return &b, nil
}

// Store writes the Bundle to the cache at the path for key.
// Write is atomic via temp-file rename. Errors are non-fatal (cache is advisory).
func (c *Cache) Store(key, row string, b *Bundle) error {
	dir := c.cacheDir(key[:8])
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("cache: mkdir: %w", err)
	}

	data, err := json.Marshal(b)
	if err != nil {
		return fmt.Errorf("cache: marshal: %w", err)
	}

	path := c.cachePath(key)
	tmp, err := os.CreateTemp(dir, ".ctx-bundle-*.json.tmp")
	if err != nil {
		return fmt.Errorf("cache: create temp: %w", err)
	}
	tmpPath := tmp.Name()
	cleanup := func() { _ = os.Remove(tmpPath) }

	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		cleanup()
		return fmt.Errorf("cache: write temp: %w", err)
	}
	if err := tmp.Close(); err != nil {
		cleanup()
		return fmt.Errorf("cache: close temp: %w", err)
	}
	if err := os.Rename(tmpPath, path); err != nil {
		cleanup()
		return fmt.Errorf("cache: rename: %w", err)
	}
	return nil
}

// staleAfter is a small helper for test injection; production uses time.Now().
var staleAfter = func() time.Time { return time.Now() }
