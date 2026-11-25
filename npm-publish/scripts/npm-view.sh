#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Usage: npm-view.sh <spec>
#
# Prints the version npm reports for <spec>: the latest version for a package
# name, or the version itself for <name>@<version>. Prints nothing if npm has
# no match (E404). Fails on any other error, so that a registry outage or rate
# limit can't read as "not on npm".

set -euo pipefail

spec="$1"

# The registry is set on the command line, which takes precedence over the
# npm_config_* variables the caller's job may set (e.g. npm_config_registry)
# and over .npmrc files. A scope's registry is a separate setting, which
# --registry doesn't override.
registry=https://registry.npmjs.org
options=(--registry "$registry")
if [[ "$spec" == @*/* ]]; then
  options+=("--${spec%%/*}:registry=$registry")
fi

# Run from /tmp so that Corepack does not detect Yarn and no .npmrc in the
# repository applies. `--` so that a spec starting with `-` isn't read as an
# option.
set +e
output="$(cd /tmp && npm view "${options[@]}" --workspaces false --json -- "$spec" version 2>/dev/null)"
status=$?
set -e

if ((status == 0)); then
  jq --raw-output 'if type == "array" then .[-1] else . end // empty' <<<"$output"
  exit 0
fi

if [[ "$(jq --raw-output '.error.code? // empty' <<<"$output" 2>/dev/null)" == "E404" ]]; then
  exit 0
fi

echo "::error::'npm view $spec' failed with exit code $status: $output" >&2
exit 1
