#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Creates the GitHub release v<release version> from the prepared notes and,
# in a monorepo, tags HEAD with <name>@<version> for each released package and
# pushes those tags.
#
# Safe to re-run after a partial failure: an existing release at the release
# commit is kept, and existing tags at the release commit are pushed again
# (a no-op on the remote). A release or tag at another commit fails.
#
# Environment:
#   GH_TOKEN, GITHUB_REPOSITORY, GITHUB_SERVER_URL (default https://github.com)
#   RELEASE_COMMIT_ID: the commit to create the release at; must be HEAD
#   RELEASE_VERSION, RELEASE_MODE (monorepo|polyrepo)
#   RELEASE_DIR: as written by prepare-release.sh

set -euo pipefail

# shellcheck source=SCRIPTDIR/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

for var in RELEASE_COMMIT_ID RELEASE_VERSION RELEASE_MODE RELEASE_DIR; do
  if [[ -z "${!var:-}" ]]; then
    echo "::error::$var is not set."
    exit 1
  fi
done

if [[ ! "$RELEASE_COMMIT_ID" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]]; then
  echo "::error::The release commit '$(escape_data "$RELEASE_COMMIT_ID")' is not a full commit SHA."
  exit 1
fi

# The release targets RELEASE_COMMIT_ID and the tags go on HEAD, so they must
# be the same commit. Checked before anything is created.
head="$(git rev-parse HEAD)"
if [[ "$head" != "$RELEASE_COMMIT_ID" ]]; then
  echo "::error::The checked-out commit ($head) is not the release commit ($RELEASE_COMMIT_ID). Check out the release commit (by default the commit the workflow runs on, github.sha)."
  exit 1
fi

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

# Local tags left by an earlier attempt must be at the release commit. Checked
# before the release is created.
for tag in "${tags[@]}"; do
  if existing="$(git rev-parse -q --verify "refs/tags/$tag^{commit}")" && [[ "$existing" != "$head" ]]; then
    echo "::error::Tag $tag already exists at $existing, not at the release commit $head."
    exit 1
  fi
done

release_tag="v$RELEASE_VERSION"
error_file="$RELEASE_DIR/gh-error"

# GitHub ignores --target when the tag v<version> already exists, and a
# release's target_commitish does not say where its tag is. So the tag itself
# must be absent or at the release commit, whether or not the release exists.
tag_commit="$(remote_tag_commit "$release_tag" "$error_file")"
if [[ -n "$tag_commit" && "$tag_commit" != "$RELEASE_COMMIT_ID" ]]; then
  echo "::error::Tag $release_tag already exists at $tag_commit, not at the release commit $RELEASE_COMMIT_ID. A release $release_tag would be attached to that commit; delete the tag or release another version."
  exit 1
fi

if target="$(gh api "repos/$GITHUB_REPOSITORY/releases/tags/$release_tag" --jq .target_commitish 2>"$error_file")"; then
  if [[ "$target" != "$RELEASE_COMMIT_ID" ]]; then
    echo "::error::Release $release_tag already exists with target '$(escape_data "$target")', not the release commit $RELEASE_COMMIT_ID."
    exit 1
  fi
  echo "Release $release_tag already exists at $RELEASE_COMMIT_ID: not creating it again."
elif grep -qF "HTTP 404" "$error_file"; then
  gh release create "$release_tag" \
    --title "$RELEASE_VERSION" \
    --notes-file "$notes_file" \
    --target "$RELEASE_COMMIT_ID"
else
  echo "::error::Could not look up release $release_tag: $(escape_data "$(cat "$error_file")")"
  exit 1
fi

if ((${#tags[@]} > 0)); then
  git config user.name github-actions
  git config user.email github-actions@github.com

  refspecs=()
  for tag in "${tags[@]}"; do
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
      echo "Tag $tag already exists at the release commit."
    else
      git tag -- "$tag" HEAD
    fi
    refspecs+=("refs/tags/$tag")
  done
  # Pushing a tag that the remote already has at the same commit succeeds
  # without changes; one that it has at another commit is rejected.
  server_url="${GITHUB_SERVER_URL:-https://github.com}"
  git push "https://x-access-token:${GH_TOKEN}@${server_url#https://}/${GITHUB_REPOSITORY}.git" "${refspecs[@]}"
fi
