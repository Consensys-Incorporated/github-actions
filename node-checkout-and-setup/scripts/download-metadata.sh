#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Downloads the repository metadata that the action needs before checkout:
# .nvmrc (to pick a Node.js version), yarn.lock (for the lookup-only cache
# check) and package.json (for the cache paths). Files that already exist in
# the workspace are used as they are. Nothing is downloaded into a workspace
# that is already checked out (has .git): the files there belong to the
# checked-out commit, which may differ from `ref` or github.sha.
#
# Environment:
#   IS_HIGH_RISK_ENVIRONMENT, CACHE_NODE_MODULES, SKIP_INSTALL, INPUT_NODE_VERSION
#   OWNER_AND_REPO, COMMIT_HASH, REPO_VISIBILITY, GH_TOKEN
#   METADATA_DIR: where to put .nvmrc and package.json
#
# Outputs (to $GITHUB_OUTPUT): checked-out, nvmrc-path, yarn-lock-available,
#   package-json-path

set -euo pipefail

# Clear files left by an earlier call in the same job, which may have used a
# different ref.
rm -rf -- "$METADATA_DIR"
mkdir -p "$METADATA_DIR"

download_file() {
  local file_path="$1"
  local destination="$2"

  if [[ -s "$destination" ]]; then
    return 0
  fi

  # Public repositories: the raw URL is served from a CDN and is not subject to
  # the REST API rate limit. Private repositories need an authenticated call.
  if [[ "$REPO_VISIBILITY" == "public" ]]; then
    curl -sSf -o "$destination" \
      "https://raw.githubusercontent.com/${OWNER_AND_REPO}/${COMMIT_HASH}/${file_path}"
  else
    gh api "repos/${OWNER_AND_REPO}/contents/${file_path}?ref=${COMMIT_HASH}" \
      --header "Accept: application/vnd.github.raw+json" >"$destination"
  fi
}

write_output() {
  echo "$1=$2" >>"$GITHUB_OUTPUT"
}

# The action's checkout steps use this output too, so that they and this
# script agree on whether the workspace is checked out.
checked_out="false"
if [[ -e .git ]]; then
  checked_out="true"
fi
write_output "checked-out" "$checked_out"

low_risk_cache_lookup="false"
if [[ "$IS_HIGH_RISK_ENVIRONMENT" == "false" && "$CACHE_NODE_MODULES" == "true" && "$SKIP_INSTALL" != "true" ]]; then
  low_risk_cache_lookup="true"
fi

# .nvmrc is required only when node-version is not given; without either, the
# Node.js version cannot be determined, so a missing .nvmrc in a checkout or a
# failed download is fatal.
nvmrc_path=""
if [[ -s .nvmrc ]]; then
  nvmrc_path=".nvmrc"
elif [[ -z "$INPUT_NODE_VERSION" && "$checked_out" == "true" ]]; then
  echo "::error::No non-empty .nvmrc in the checked-out workspace. Add one or set the node-version input."
  exit 1
elif [[ -z "$INPUT_NODE_VERSION" ]]; then
  nvmrc_path="$METADATA_DIR/.nvmrc"
  if ! download_file ".nvmrc" "$nvmrc_path"; then
    rm -f "$nvmrc_path"
    echo "::error::Either provide the node-version input or have a .nvmrc at the requested ref. Failed to download .nvmrc from ${OWNER_AND_REPO}@${COMMIT_HASH}."
    exit 1
  fi
fi
write_output "nvmrc-path" "$nvmrc_path"

# hashFiles('yarn.lock') only sees the workspace, so yarn.lock is downloaded
# into the workspace root. actions/checkout overwrites it later. A failed
# download only disables the lookup-only cache check. In a checkout, the
# action doesn't check out again, so nothing would replace a downloaded
# yarn.lock: its yarn.lock is used as it is, or there is none.
yarn_lock_available="false"
if [[ -s yarn.lock ]]; then
  yarn_lock_available="true"
elif [[ "$low_risk_cache_lookup" == "true" && "$checked_out" == "false" ]]; then
  if download_file "yarn.lock" "yarn.lock"; then
    yarn_lock_available="true"
  else
    rm -f yarn.lock
    echo "::warning::Failed to download yarn.lock from ${OWNER_AND_REPO}@${COMMIT_HASH}; not checking for a cache hit before setup."
  fi
fi
write_output "yarn-lock-available" "$yarn_lock_available"

# package.json gives the workspace node_modules paths to cache. Without it,
# the cache falls back to the broad **/node_modules path. A checkout without
# a root package.json is not a project the action can install; if it also has
# no yarn.lock, the "Require yarn.lock" step fails.
package_json_path=""
if [[ -s package.json ]]; then
  package_json_path="package.json"
elif [[ "$IS_HIGH_RISK_ENVIRONMENT" == "false" && "$SKIP_INSTALL" != "true" && "$checked_out" == "false" ]]; then
  package_json_path="$METADATA_DIR/package.json"
  if ! download_file "package.json" "$package_json_path"; then
    rm -f "$package_json_path"
    package_json_path=""
    echo "::warning::Failed to download package.json from ${OWNER_AND_REPO}@${COMMIT_HASH}; caching **/node_modules instead."
  fi
fi
write_output "package-json-path" "$package_json_path"
