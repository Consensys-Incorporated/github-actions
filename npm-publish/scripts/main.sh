#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Publishes (or packs) every public workspace whose current version is not on
# npm yet. Run after sanitize.sh.
#
# Environment: PUBLISH_NPM_TAG, DRY_RUN, YARN_NPM_AUTH_TOKEN,
# REPOSITORY_VISIBILITY, PACK_DIR, YARN_IGNORE_PATH, and YARN_RC_FILENAME (the
# configuration file written by sanitize.sh).
#
# Outputs (to $GITHUB_OUTPUT): dry-run=true if any package was packed rather
# than published.

set -euo pipefail

# No xtrace with RUNNER_DEBUG: the environment holds the npm token, which
# GitHub masks in the log only if it came from a secret.

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Tarballs go here, not /tmp, so that only this run's packages are reported
# and uploaded.
export PACK_DIR="${PACK_DIR:-${RUNNER_TEMP:-/tmp}/npm-publish-packages}"
rm -rf -- "$PACK_DIR"
mkdir -p "$PACK_DIR"

# shellcheck source=SCRIPTDIR/environment.sh
source "$script_path/environment.sh"

# Without it, Yarn would load the repository's own .yarnrc.yml.
if [[ -z "${YARN_RC_FILENAME:-}" ]]; then
  echo "::error::YARN_RC_FILENAME not set. Run sanitize.sh first."
  exit 1
fi

yarn_version="$(yarn --version)"
IFS='.' read -r yarn_major yarn_minor _ <<<"$yarn_version"
if [[ ! "$yarn_major" =~ ^[0-9]+$ || ! "$yarn_minor" =~ ^[0-9]+$ ]] ||
  ((yarn_major < 4 || (yarn_major == 4 && yarn_minor < 16))); then
  echo "::error::Yarn 4.16.0 or higher is required. Detected version: $yarn_version."
  exit 1
fi

if [[ -z "${PUBLISH_NPM_TAG:-}" ]]; then
  echo "::error::'npm-tag' not set."
  exit 1
fi

publish_monorepo() {
  echo "Workspaces detected. Treating as a monorepo."

  # One line per public workspace, in the order Yarn lists them: location,
  # name and version, tab-separated.
  local workspaces
  workspaces="$(
    yarn workspaces list --json --no-private |
      jq --raw-output '
        .location |
        if test("[[:cntrl:]]") then
          "::error::A workspace location contains a control character.\n" | halt_error(1)
        else . end
      ' |
      while IFS= read -r location; do
        jq --raw-output --arg location "$location" '
          [
            $location,
            (.name // error("Missing .name in " + $location + "/package.json")),
            (.version // error("Missing .version in " + $location + "/package.json"))
          ] | @tsv
        ' "$location/package.json" || exit 1
      done
  )"

  # Determine up front which workspaces need publishing. Workspaces are
  # checked in parallel. Names and versions are passed NUL-separated, so that
  # xargs doesn't split them on spaces or quotes.
  local pending
  pending="$(
    while IFS=$'\t' read -r _location name version; do
      if [[ -n "$name" ]]; then
        printf '%s\0%s\0' "$name" "$version"
      fi
    done <<<"$workspaces" |
      xargs -0 -P 10 -n 2 "$script_path/needs-publish.sh"
  )"

  if [[ -z "$pending" ]]; then
    echo "No packages need publishing."
    return 0
  fi

  local -a names
  mapfile -t names <<<"$pending"
  echo "Publishing ${#names[@]} package(s): ${pending//$'\n'/, }."

  # publish.sh runs in each workspace in the order Yarn lists them, and the
  # first failure stops the rest. Not through `yarn workspaces foreach exec`:
  # that puts the bins of the workspace and its dependencies first on PATH, so
  # a package declaring a `bash`, `jq`, `npm` or `yarn` bin would run in place
  # of the real one, with the token and OIDC in its environment.
  local location name _version
  while IFS=$'\t' read -r -u 3 location name _version; do
    if [[ -n "$name" ]] && grep -qxF -- "$name" <<<"$pending"; then
      echo "Publishing $name from $location."
      (cd -- "$location" && "$script_path/publish.sh")
    fi
  done 3<<<"$workspaces"
}

publish_polyrepo() {
  echo "No workspaces detected. Treating as a polyrepo."

  if [[ "$(jq '.private' package.json)" == "true" ]]; then
    echo "The package is private. Not publishing."
    return 0
  fi

  local manifest name version pending
  # Separate assignments, so that set -e applies to each.
  manifest="$(jq --raw-output '[.name // "", .version // ""] | @tsv' package.json)"
  IFS=$'\t' read -r name version <<<"$manifest"
  pending="$("$script_path/needs-publish.sh" "$name" "$version")"
  if [[ -z "$pending" ]]; then
    echo "No packages need publishing."
    return 0
  fi

  "$script_path/publish.sh"
}

if [[ "$(jq 'has("workspaces")' package.json)" == "true" ]]; then
  publish_monorepo
else
  publish_polyrepo
fi

if compgen -G "$PACK_DIR/*.tgz" >/dev/null; then
  dry_run=true
else
  dry_run=false
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "dry-run=$dry_run" >>"$GITHUB_OUTPUT"
fi
