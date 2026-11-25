#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Resolves the truncated Node.js version to the newest matching release.
#
# Environment:
#   COMPUTED_NODE_VERSION: vMAJOR or vMAJOR.MINOR
#   NODE_INDEX_FILE: the Node.js release index; downloaded if absent
#
# Outputs (to $GITHUB_OUTPUT): node-version (without the leading "v")

set -euo pipefail

if [[ ! -s "$NODE_INDEX_FILE" ]]; then
  curl -fsS --retry 3 -o "$NODE_INDEX_FILE" https://nodejs.org/download/release/index.json
fi

# The index is ordered newest first.
resolved_version="$(
  jq -r --arg prefix "$COMPUTED_NODE_VERSION." \
    '[.[].version | select(startswith($prefix))][0] // empty' "$NODE_INDEX_FILE"
)"

if [[ -z "$resolved_version" ]]; then
  echo "::error::Could not find a Node.js release matching $COMPUTED_NODE_VERSION."
  exit 1
fi

echo "node-version=${resolved_version#v}" >>"$GITHUB_OUTPUT"
