#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Usage: retry.sh <command> [args...]
#
# Runs the command up to 5 times, waiting 1, 2, 4 and 8 seconds between
# attempts. The command is executed directly, not through a shell.

set -euo pipefail

readonly MAX_ATTEMPTS=5

retry() {
  local attempt delay
  for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    if "$@"; then
      return 0
    fi
    if ((attempt < MAX_ATTEMPTS)); then
      delay=$((2 ** (attempt - 1)))
      echo "Attempt $attempt of $MAX_ATTEMPTS failed, retrying in $delay seconds..."
      sleep "$delay"
    fi
  done
  echo "::error::Command failed after $MAX_ATTEMPTS attempts."
  return 1
}

if (($# == 0)); then
  echo "::error::retry.sh: no command given."
  exit 1
fi

retry "$@"
