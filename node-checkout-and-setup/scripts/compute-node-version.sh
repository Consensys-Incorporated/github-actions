#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Computes the truncated Node.js version (vMAJOR or vMAJOR.MINOR) from the
# node-version input or .nvmrc. The result is the cache key component and the
# prefix used to resolve a concrete release.
#
#   "v24.13.0" -> "v24.13"    "24.13.0" -> "v24.13"    "24" -> "v24"
#   "24.x"     -> "v24"       "lts/*"   -> newest LTS, truncated
#
# Environment:
#   INPUT_NODE_VERSION, NVMRC_FILE
#   NODE_INDEX_FILE: where the Node.js release index is saved for reuse
#
# Outputs (to $GITHUB_OUTPUT): node-version

set -euo pipefail

if [[ -n "$INPUT_NODE_VERSION" ]]; then
  node_version="$INPUT_NODE_VERSION"
elif [[ -n "$NVMRC_FILE" && -s "$NVMRC_FILE" ]]; then
  node_version="$(tr -d '\r\n' <"$NVMRC_FILE")"
else
  node_version=""
fi

if [[ -z "$node_version" ]]; then
  echo "::error::Either provide the node-version input or have a non-empty .nvmrc at the requested ref."
  exit 1
fi

if [[ "$node_version" =~ ^[0-9] ]]; then
  node_version="v$node_version"
fi

# "X.x" ranges become the major version alone.
if [[ "$node_version" =~ ^v([0-9]+)\.x$ ]]; then
  node_version="v${BASH_REMATCH[1]}"
fi

if [[ "$node_version" == "lts/*" ]]; then
  curl -fsS --retry 3 -o "$NODE_INDEX_FILE" https://nodejs.org/download/release/index.json
  node_version="$(jq -r '[.[] | select(.lts != false)][0].version' "$NODE_INDEX_FILE")"
fi

node_version="$(cut -d. -f1-2 <<<"$node_version")"

if [[ ! "$node_version" =~ ^v[0-9]+(\.[0-9]+)?$ ]]; then
  echo "::error::Could not determine a Node.js version from '${INPUT_NODE_VERSION:-.nvmrc}'. Accepted forms: 24, v24, 24.x, 24.13, 24.13.0, lts/*."
  exit 1
fi

echo "node-version=$node_version" >>"$GITHUB_OUTPUT"
