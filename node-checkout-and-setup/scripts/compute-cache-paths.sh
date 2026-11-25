#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Computes the node_modules cache paths: Yarn's install state, the root
# node_modules, and <pattern>/node_modules for each workspace pattern in
# package.json. Falls back to **/node_modules without a package.json.
#
# Environment:
#   PACKAGE_JSON_FILE: path to package.json, or empty
#
# Outputs (to $GITHUB_OUTPUT): paths (newline-separated)

set -euo pipefail

if [[ -n "$PACKAGE_JSON_FILE" && -s "$PACKAGE_JSON_FILE" ]]; then
  paths="$(
    {
      echo ".yarn/install-state.gz"
      echo "node_modules"
      jq -r '
        (.workspaces // [])
        | if type == "array" then .
          elif type == "object" then (.packages // [])
          elif type == "string" then [.]
          else []
          end
        | .[]
        | "\(.)/node_modules"
      ' "$PACKAGE_JSON_FILE"
    } | awk 'NF && !seen[$0]++'
  )"
else
  paths="$(printf '%s\n' ".yarn/install-state.gz" "**/node_modules")"
fi

delimiter="EOF_$(openssl rand -hex 16)"
{
  echo "paths<<$delimiter"
  echo "$paths"
  echo "$delimiter"
} >>"$GITHUB_OUTPUT"
