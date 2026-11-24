#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Publishes (or packs) every public workspace whose current version is not on
# npm yet. Run after sanitize.sh.
#
# Environment: PUBLISH_NPM_TAG, DRY_RUN, YARN_NPM_AUTH_TOKEN,
# REPOSITORY_VISIBILITY, GH_TOKEN, GITHUB_SHA, GITHUB_REPOSITORY, PACK_DIR, and
# YARN_RC_FILENAME / YARN_IGNORE_PATH from sanitize.sh.

set -euo pipefail

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Tarballs go here, not /tmp, so that only this run's packages are reported
# and uploaded.
export PACK_DIR="${PACK_DIR:-${RUNNER_TEMP:-/tmp}/npm-publish-packages}"
rm -rf -- "$PACK_DIR"
mkdir -p "$PACK_DIR"

# shellcheck source=SCRIPTDIR/environment.sh
source "$script_path/environment.sh"

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

if [[ -n "${GITHUB_SHA:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  pr_url="$(gh api "/repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls" \
    --jq '.[0].html_url // empty' 2>/dev/null || true)"
  if [[ -n "$pr_url" ]]; then
    echo "Releasing via pull request: $pr_url"
  fi
fi

publish_monorepo() {
  echo "Workspaces detected. Treating as a monorepo."

  # Determine up front which workspaces need publishing, so that
  # `yarn workspaces foreach` only runs for those. Workspaces are checked in
  # parallel.
  local pending
  pending="$(
    yarn workspaces list --json --no-private |
      jq --raw-output '.location' |
      while IFS= read -r location; do
        jq --raw-output --arg location "$location" '
          [
            (.name // error("Missing .name in " + $location + "/package.json")),
            (.version // error("Missing .version in " + $location + "/package.json"))
          ] | @tsv
        ' "$location/package.json" || exit 1
      done |
      xargs -P 10 -n 2 "$script_path/needs-publish.sh"
  )"

  if [[ -z "$pending" ]]; then
    echo "No packages need publishing."
    return 0
  fi

  local -a names include_args=()
  mapfile -t names <<<"$pending"
  for name in "${names[@]}"; do
    include_args+=(--include "$name")
  done

  echo "Publishing ${#names[@]} package(s): ${pending//$'\n'/, }."

  yarn workspaces foreach --all "${include_args[@]}" --no-private --verbose \
    exec "$script_path/publish.sh"
}

if [[ "$(jq 'has("workspaces")' package.json)" == "true" ]]; then
  publish_monorepo
  exit 0
fi

echo "No workspaces detected. Treating as a polyrepo."
"$script_path/publish.sh"
