#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Test helper. Copies the fixture into the workspace root and commits it, so
# the action finds a checked-out Yarn workspace (and does not check out
# itself). The caller's checkout of this repository stays in a subdirectory.
#
# Usage: prepare-workspace.sh [--unique-lockfile]
#
#   --unique-lockfile  Rename the fixture's workspace package after this
#                      workflow run, in package.json and yarn.lock, so the
#                      node_modules cache key is unique to the run. Jobs of
#                      one run share the key; "Re-run all jobs" reuses it.

set -euo pipefail

fixture="$(cd "$(dirname "${BASH_SOURCE[0]}")/../test-fixture" && pwd)"
cd "$GITHUB_WORKSPACE"
cp -a "$fixture/." .

if [[ "${1:-}" == "--unique-lockfile" ]]; then
  name="a-run-${GITHUB_RUN_ID}"
  jq --arg name "$name" '.name = $name' packages/a/package.json >packages/a/package.json.tmp
  mv packages/a/package.json.tmp packages/a/package.json
  sed -i "s|\"a@workspace:packages/a\"|\"${name}@workspace:packages/a\"|" yarn.lock
  if [[ "$(grep -c "\"${name}@workspace:packages/a\"" yarn.lock)" -ne 2 ]]; then
    echo "::error::Failed to rename the workspace in yarn.lock."
    exit 1
  fi
fi

git init -q
git config user.name github-actions
git config user.email github-actions@github.com
# Leave out the caller's checkout of this repository.
for entry in *; do
  if [[ -d "$entry/.git" ]]; then
    echo "/$entry/" >>.git/info/exclude
  fi
done
git add -A
git commit -q -m "Test fixture"
