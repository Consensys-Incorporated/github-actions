#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Publishes or packs the package in the current directory. Run by main.sh,
# in the package's directory.
#
# Mode selection:
#   1. DRY_RUN=true: pack.
#   2. Package not on npm:
#      - with YARN_NPM_AUTH_TOKEN: publish with the token (no staging, no
#        provenance), for the package's first publish;
#      - without a token: pack, or fail if DRY_RUN=false.
#   3. Package on npm (the token is unset; it interferes with OIDC):
#      - with OIDC (ACTIONS_ID_TOKEN_REQUEST_URL): staged publish, with
#        provenance if the repository is public;
#      - without OIDC: pack, or fail if DRY_RUN=false.
#
# Environment: PUBLISH_NPM_TAG, DRY_RUN, YARN_NPM_AUTH_TOKEN,
# ACTIONS_ID_TOKEN_REQUEST_URL, REPOSITORY_VISIBILITY, PACK_DIR (where to
# write tarballs), GITHUB_STEP_SUMMARY.

set -euo pipefail

# No xtrace with RUNNER_DEBUG: the environment holds the npm token, which
# GitHub masks in the log only if it came from a secret.

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=SCRIPTDIR/environment.sh
source "$script_path/environment.sh"

DRY_RUN="${DRY_RUN:-}"
# action.yml checks this too, before anything runs.
if [[ "$DRY_RUN" != "true" && "$DRY_RUN" != "false" && -n "$DRY_RUN" ]]; then
  echo "::error::'dry-run' must be 'true', 'false' or empty."
  exit 1
fi
: "${PACK_DIR:?PACK_DIR must be set}"
YARN_NPM_AUTH_TOKEN="${YARN_NPM_AUTH_TOKEN:-}"

package_version="$(jq --raw-output .version package.json)"
if [[ "$package_version" == "0.0.0" ]]; then
  echo "Version is 0.0.0. Not publishing."
  exit 0
fi

package_name="$(jq --raw-output .name package.json)"

# Whether the package exists on npm at all. Any error other than "not found"
# fails, so a registry outage can't send an existing package down the token
# path.
published_version="$("$script_path/npm-view.sh" "$package_name")"

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
    publish_cmd=(yarn npm publish --tag "$PUBLISH_NPM_TAG" --staged)
    if [[ "${REPOSITORY_VISIBILITY:-}" == "public" ]]; then
      publish_cmd+=(--provenance)
    fi
    DRY_RUN="false"
  fi
fi

if [[ "$DRY_RUN" != "true" ]]; then
  "${publish_cmd[@]}"
  exit 0
fi

yarn pack --out "$PACK_DIR/%s-%v.tgz"

# Yarn's %s is the package name with "/" replaced by "-"; a scope's "@" stays.
tarball="$PACK_DIR/${package_name//\//-}-$package_version.tgz"
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
