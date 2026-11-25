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

# The registry is set on the command line, which takes precedence over any
# configuration file. A scope's registry is a separate setting, which
# --registry doesn't override.
registry=https://registry.npmjs.org
options=(--registry "$registry")
if [[ "$spec" == @*/* ]]; then
  options+=("--${spec%%/*}:registry=$registry")
fi

# --registry pins only the URL: a proxy (HTTPS_PROXY, https_proxy,
# npm_config_https_proxy, ...) still carries the request, and npm reports a
# proxy's 404 as the registry's, which would send an existing package down the
# token path. So npm runs with nothing from the environment but PATH, and with
# empty user and global configuration files. A runner that can reach the
# registry only through a proxy then fails the lookup, which fails the action.
npm_home="$(mktemp -d "${TMPDIR:-/tmp}/npm-publish-view.XXXXXX")"
trap 'rm -rf -- "$npm_home"' EXIT
# npm refuses to load one file as both.
: >"$npm_home/user-npmrc"
: >"$npm_home/global-npmrc"
options+=(--userconfig "$npm_home/user-npmrc" --globalconfig "$npm_home/global-npmrc")

# Run from /tmp so that Corepack does not detect Yarn and no .npmrc in the
# repository applies. `--` so that a spec starting with `-` isn't read as an
# option.
set +e
output="$(cd /tmp && env -i PATH="$PATH" HOME="$npm_home" npm view "${options[@]}" --workspaces false --json -- "$spec" version 2>/dev/null)"
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
