#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Determines the release version, the released packages (monorepo) and the
# release notes, in the current directory. Runs no Yarn, npm or Node.js.
#
# Environment:
#   GH_TOKEN, GITHUB_REPOSITORY: for the tag lookups
#   RELEASE_DIR: directory for notes.md and packages.tsv
#
# Outputs (to $GITHUB_OUTPUT): release-version, mode (monorepo|polyrepo)
# Exports (to $GITHUB_ENV): RELEASE_NOTES
# Files: $RELEASE_DIR/notes.md; $RELEASE_DIR/packages.tsv (monorepo:
#   "<name>\t<path>\t<version>" per released package, in workspace order)

set -euo pipefail

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

# shellcheck source=SCRIPTDIR/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mkdir -p "$RELEASE_DIR"
notes_file="$RELEASE_DIR/notes.md"
packages_file="$RELEASE_DIR/packages.tsv"
: >"$packages_file"

release_version="$(jq -r '.version // empty' package.json)"
if ! is_semver "$release_version"; then
  echo "::error::The root package.json version '$(escape_data "$release_version")' is not a valid SemVer version."
  exit 1
fi

repository_url="$(jq -r '.repository | objects | .url // empty' package.json)"
if [[ "$repository_url" != https://* && "$repository_url" != git+https://* ]]; then
  echo "::error::The root package.json repository.url '$(escape_data "$repository_url")' must be an https: or git+https: URL."
  exit 1
fi
repository_url="${repository_url#git+}"
repository_url="${repository_url%.git}"
echo "Repository: $(escape_data "$repository_url")"

echo "release-version=$release_version" >>"$GITHUB_OUTPUT"

if [[ "$(jq 'has("workspaces")' package.json)" != "true" ]]; then
  echo "No workspaces in package.json: polyrepo release."
  echo "mode=polyrepo" >>"$GITHUB_OUTPUT"
  if [[ ! -f CHANGELOG.md ]]; then
    echo "::error::CHANGELOG.md not found."
    exit 1
  fi
  if ! changelog_section CHANGELOG.md "$release_version" >"$notes_file"; then
    echo "::error::CHANGELOG.md has no section for $release_version."
    exit 1
  fi
else
  echo "Workspaces in package.json: monorepo release."
  echo "mode=monorepo" >>"$GITHUB_OUTPUT"

  if [[ ! -f release.config.json ]]; then
    echo "::error::release.config.json not found. Monorepos must set {\"versioningStrategy\": \"independent\"}; fixed versioning is not supported."
    exit 1
  fi
  strategy="$(jq -r '.versioningStrategy // empty' release.config.json)"
  if [[ "$strategy" != "independent" ]]; then
    echo "::error::release.config.json versioningStrategy is '$(escape_data "$strategy")'. Only 'independent' is supported."
    exit 1
  fi

  workspaces="$(list_workspaces .)"

  # tag_exists <tag>: 0 if it exists, 1 if not (HTTP 404); exits on other errors.
  tag_exists() {
    local tag="$1" err
    if err="$(gh api "repos/$GITHUB_REPOSITORY/git/ref/tags/$tag" --silent 2>&1)"; then
      return 0
    fi
    if [[ "$err" == *"HTTP 404"* ]]; then
      return 1
    fi
    echo "::error::Could not look up tag $tag: $(escape_data "$err")"
    exit 1
  }

  declare -A seen_names=()
  while IFS= read -r location; do
    manifest="$location/package.json"
    name="$(jq -r '.name // empty' "$manifest")"
    private="$(jq -r '.private' "$manifest")"
    version="$(jq -r '.version // empty' "$manifest")"

    if [[ -n "$name" ]]; then
      if [[ -n "${seen_names[$name]:-}" ]]; then
        echo "::error::Duplicate workspace name $(escape_data "$name"): $location conflicts with ${seen_names[$name]}."
        exit 1
      fi
      seen_names[$name]="$location"
    fi

    if [[ "$private" == "true" || "$version" == "0.0.0" ]]; then
      continue
    fi
    if [[ -z "$name" ]]; then
      echo "::error::$manifest has no name."
      exit 1
    fi
    if ! is_semver "$version"; then
      echo "::error::$manifest version '$(escape_data "$version")' is not a valid SemVer version."
      exit 1
    fi
    # The name goes into a tag, an API path and packages.tsv, so it must be a
    # valid npm package name.
    if [[ ! "$name" =~ ^(@[a-z0-9][a-z0-9._~-]*/)?[a-z0-9][a-z0-9._~-]*$ ]]; then
      echo "::error::$manifest name '$(escape_data "$name")' is not a valid npm package name."
      exit 1
    fi

    if tag_exists "$name@$version"; then
      echo "Skipping $name@$version: already released."
    else
      echo "Releasing $name@$version ($location)."
      printf '%s\t%s\t%s\n' "$name" "$location" "$version" >>"$packages_file"
    fi
  done <<<"$workspaces"

  if [[ ! -s "$packages_file" ]]; then
    echo "::error::No packages to release: every public package's current version is already tagged."
    exit 1
  fi

  : >"$notes_file"
  first=true
  while IFS=$'\t' read -r name location version; do
    changelog="$location/CHANGELOG.md"
    if [[ ! -f "$changelog" ]]; then
      echo "::error::$changelog not found."
      exit 1
    fi
    if ! section="$(changelog_section "$changelog" "$version")"; then
      echo "::error::$changelog has no section for $version."
      exit 1
    fi
    if [[ -z "${section//[[:space:]]/}" ]]; then
      echo "::error::$changelog has an empty section for $version."
      exit 1
    fi
    if [[ "$first" == false ]]; then
      printf '\n' >>"$notes_file"
    fi
    first=false
    printf '## %s %s\n\n%s\n' "$name" "$version" "$section" >>"$notes_file"
  done <"$packages_file"
fi

if [[ -z "$(tr -d '[:space:]' <"$notes_file")" ]]; then
  echo "::error::The release notes are empty."
  exit 1
fi

# The notes are free text from the changelogs: print them with workflow
# commands stopped, so that a line in them cannot run one.
stop_token="$(openssl rand -hex 16)"
echo "Release notes:"
echo "::stop-commands::$stop_token"
printf '%s\n' "$(cat "$notes_file")"
echo "::$stop_token::"

# Export the notes with a random delimiter that cannot occur in them.
delimiter="EOF_$(openssl rand -hex 16)"
if grep -qF "$delimiter" "$notes_file"; then
  echo "::error::Release notes contain the delimiter."
  exit 1
fi
{
  echo "RELEASE_NOTES<<$delimiter"
  cat "$notes_file"
  echo "$delimiter"
} >>"$GITHUB_ENV"
