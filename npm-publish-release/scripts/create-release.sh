#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Creates the GitHub release v<release version> from the prepared notes and,
# in a monorepo, tags HEAD with <name>@<version> for each released package and
# pushes those tags.
#
# Environment:
#   GH_TOKEN, GITHUB_REPOSITORY, GITHUB_SERVER_URL (default https://github.com)
#   RELEASE_COMMIT_ID: the commit to create the release at
#   RELEASE_VERSION, RELEASE_MODE (monorepo|polyrepo)
#   RELEASE_DIR: as written by prepare-release.sh

set -euo pipefail

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

for var in RELEASE_COMMIT_ID RELEASE_VERSION RELEASE_MODE RELEASE_DIR; do
  if [[ -z "${!var:-}" ]]; then
    echo "::error::$var is not set."
    exit 1
  fi
done

notes_file="$RELEASE_DIR/notes.md"
packages_file="$RELEASE_DIR/packages.tsv"

if [[ ! -s "$notes_file" ]]; then
  echo "::error::No release notes."
  exit 1
fi

tags=()
if [[ "$RELEASE_MODE" == "monorepo" ]]; then
  while IFS=$'\t' read -r name _ version; do
    tags+=("$name@$version")
  done <"$packages_file"
  if ((${#tags[@]} == 0)); then
    echo "::error::No released packages."
    exit 1
  fi
fi

gh release create "v$RELEASE_VERSION" \
  --title "$RELEASE_VERSION" \
  --notes-file "$notes_file" \
  --target "$RELEASE_COMMIT_ID"

if ((${#tags[@]} > 0)); then
  git config user.name github-actions
  git config user.email github-actions@github.com

  refspecs=()
  for tag in "${tags[@]}"; do
    git tag -- "$tag" HEAD
    refspecs+=("refs/tags/$tag")
  done
  server_url="${GITHUB_SERVER_URL:-https://github.com}"
  git push "https://x-access-token:${GH_TOKEN}@${server_url#https://}/${GITHUB_REPOSITORY}.git" "${refspecs[@]}"
fi
