#!/bin/sh
# validate-definition.sh — Thin shim delegating to `furrow validate definition`.
#
# Usage: frw validate-definition <path-to-definition.yaml>
#
# Replaces the previous Python-and-yq pipeline. Validation logic now lives in
# the Go CLI (internal/cli/validate_definition.go) per the pre-write-validation
# row's clean-swap to a Go-first stance. This shim contains zero validation
# logic — it exists only to preserve the existing `frw validate-definition`
# entry point and dispatch.
#
# Exit codes pass through from the Go binary:
#   0 — valid
#   1 — usage error or file not found
#   3 — validation failure (one or more errors)

frw_validate_definition() {
  if [ $# -ne 1 ]; then
    echo "Usage: frw validate-definition <definition.yaml>" >&2
    return 1
  fi

  cd "${PROJECT_ROOT:-$FURROW_ROOT}" || return 1
  exec go run ./cmd/furrow validate definition --path "$1"
}
