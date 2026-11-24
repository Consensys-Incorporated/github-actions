#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Publishes or packs the package in the current directory. Run by main.sh,
# directly (polyrepo) or through `yarn workspaces foreach exec` (monorepo).
#
# Mode selection:
#   1. DRY_RUN=true: pack.
#   2. Package not on npm:
#      - with YARN_NPM_AUTH_TOKEN: publish with the token (no staging, no
#        provenance), for the package's first publish;
#      - without a token: pack, or fail if DRY_RUN=false.
#   3. Package on npm (the token is unset; it interferes with OIDC):
#      - with OIDC (ACTIONS_ID_TOKEN_REQUEST_URL): publish, staged if
#        STAGED_PUBLISH=true, with provenance if PROVENANCE=true and the
#        repository is public;
#      - without OIDC: pack, or fail if DRY_RUN=false.
#
# Environment: PUBLISH_NPM_TAG, DRY_RUN, YARN_NPM_AUTH_TOKEN,
# ACTIONS_ID_TOKEN_REQUEST_URL, STAGED_PUBLISH, PROVENANCE,
# REPOSITORY_VISIBILITY, GITHUB_OUTPUT, GITHUB_STEP_SUMMARY.

set -euo pipefail

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=SCRIPTDIR/environment.sh
source "$script_path/environment.sh"

DRY_RUN="${DRY_RUN:-}"
YARN_NPM_AUTH_TOKEN="${YARN_NPM_AUTH_TOKEN:-}"

package_version="$(jq --raw-output .version package.json)"
if [[ "$package_version" == "0.0.0" ]]; then
  echo "Version is 0.0.0. Not publishing."
  exit 0
fi

package_name="$(jq --raw-output .name package.json)"

# Whether the package exists on npm at all. Run from /tmp so that Corepack
# does not detect Yarn.
published_version="$(cd /tmp && npm view "$package_name" --workspaces false --json 2>/dev/null | jq --raw-output '.version // empty' || echo "")"

publish_cmd=()
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Performing a dry run."
elif [[ -z "$published_version" ]]; then
  if [[ -z "$YARN_NPM_AUTH_TOKEN" && "$DRY_RUN" == "false" ]]; then
    echo "::error::'npm-token' not provided for the initial publish of $package_name."
    exit 1
  elif [[ -z "$YARN_NPM_AUTH_TOKEN" ]]; then
    echo "No token for the initial publish of $package_name. Performing a dry run."
    DRY_RUN="true"
  else
    echo "$package_name is not on npm yet. Using the npm token for its initial publish."
    publish_cmd=(yarn npm publish --tag "$PUBLISH_NPM_TAG")
    DRY_RUN="false"
  fi
else
  # The token interferes with OIDC publishing.
  unset YARN_NPM_AUTH_TOKEN
  if [[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" && "$DRY_RUN" == "false" ]]; then
    echo "::error::OIDC is not available to publish $package_name. Grant the job 'id-token: write'."
    exit 1
  elif [[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]]; then
    echo "OIDC is not available. Performing a dry run."
    DRY_RUN="true"
  else
    echo "$package_name is on npm. Publishing with OIDC."
    publish_cmd=(yarn npm publish --tag "$PUBLISH_NPM_TAG")
    if [[ "${STAGED_PUBLISH:-}" == "true" ]]; then
      publish_cmd+=(--staged)
    fi
    if [[ "${PROVENANCE:-}" == "true" && "${REPOSITORY_VISIBILITY:-}" == "public" ]]; then
      publish_cmd+=(--provenance)
    fi
    DRY_RUN="false"
  fi
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "dry-run=$DRY_RUN" >>"$GITHUB_OUTPUT"
fi

if [[ "$DRY_RUN" != "true" ]]; then
  "${publish_cmd[@]}"
  exit 0
fi

yarn pack --out "/tmp/%s-%v.tgz"

# Yarn's %s is the package name with "/" replaced by "-"; a scope's "@" stays.
tarball="/tmp/${package_name//\//-}-$package_version.tgz"
checksum="$(shasum -a 1 "$tarball" | cut -d' ' -f1)"
integrity="sha512-$(openssl dgst -sha512 -binary "$tarball" | openssl base64 -A)"

echo "Checksum: $checksum"
echo "Integrity: $integrity"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### $package_name"
    echo
    echo "- Checksum: \`$checksum\`"
    echo "- Integrity: \`$integrity\`"
    echo
  } >>"$GITHUB_STEP_SUMMARY"
fi
