#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Decides whether HEAD is a release commit: the root package.json version at
# HEAD differs from the one at BEFORE, and, if COMMIT_STARTS_WITH is set, the commit
# message starts with one of its prefixes, separated by commas or newlines
# (with "[version]" replaced by the new version). Prefixes are matched
# literally.
#
# Environment:
#   BEFORE: the full SHA of the commit to compare with (required)
#   COMMIT_STARTS_WITH: prefixes separated by commas or newlines (optional)
#   COMMIT_MESSAGE: message to check instead of HEAD's subject (optional)
#   GITHUB_TOKEN: token for fetching BEFORE (optional); with GITHUB_SERVER_URL
#
# Outputs (to $GITHUB_OUTPUT): IS_RELEASE=true|false

set -euo pipefail

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

COMMIT_STARTS_WITH="${COMMIT_STARTS_WITH:-}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-}"

if [[ -z "${BEFORE:-}" ]]; then
  echo "::error::The before SHA is not set."
  exit 1
fi

# A push that creates a branch has an all-zero before SHA: nothing to compare
# with.
if [[ "$BEFORE" =~ ^0+$ ]]; then
  echo "::error::The before SHA is all zeros (a push that created a branch); there is no commit to compare with."
  exit 1
fi

# A full SHA-1 or SHA-256 object name. BEFORE is passed to git fetch and
# git show, where a value starting with "-" would be read as an option, and it
# is printed in workflow commands below.
if [[ ! "$BEFORE" =~ ^([0-9a-fA-F]{40}|[0-9a-fA-F]{64})$ ]]; then
  echo "::error::The before input must be a full commit SHA (40 or 64 hexadecimal characters)."
  exit 1
fi

# Fetch BEFORE in case the push contained more than one commit. The checkout
# doesn't persist credentials, so a private repository needs the token. It is
# exported in a subshell for this one command (not argv, not .git/config), as
# config entries appended after any GIT_CONFIG_* entries already set. The empty
# value first clears any header configured for the same URL key, as
# actions/checkout's is, so only one Authorization header is sent. A header the
# caller configured for a more specific URL (e.g. the repository's) takes
# precedence over this one.
fetch_before() {
  # Keep the credential out of the RUNNER_DEBUG trace.
  local xtrace=false
  if [[ "$-" == *x* ]]; then
    xtrace=true
    set +x
  fi
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    local status=0
    git fetch --quiet origin "$BEFORE" || status=$?
    if [[ "$xtrace" == true ]]; then
      set -x
    fi
    return "$status"
  fi
  local key auth n status=0
  key="http.${GITHUB_SERVER_URL:-https://github.com}/.extraheader"
  auth="$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')"
  echo "::add-mask::$auth"
  n="${GIT_CONFIG_COUNT:-0}"
  (
    export GIT_CONFIG_COUNT=$((n + 2))
    export "GIT_CONFIG_KEY_$n=$key" "GIT_CONFIG_VALUE_$n="
    export "GIT_CONFIG_KEY_$((n + 1))=$key" "GIT_CONFIG_VALUE_$((n + 1))=AUTHORIZATION: basic $auth"
    git fetch --quiet origin "$BEFORE"
  ) || status=$?
  if [[ "$xtrace" == true ]]; then
    set -x
  fi
  return "$status"
}

# BEFORE may still be present if the fetch fails (it is HEAD^ for a
# single-commit push with fetch-depth 2).
if ! fetch_before; then
  if git cat-file -e "${BEFORE}^{commit}" 2>/dev/null; then
    echo "::warning::Could not fetch $BEFORE; using the copy already in the repository."
  else
    echo "::error::Could not fetch $BEFORE."
    exit 1
  fi
fi

version_before="$(git show "$BEFORE:package.json" | jq --raw-output .version)"
# HEAD's package.json, not the working tree's: with skip-checkout, an
# uncommitted change in the caller's checkout is not part of the commit.
version_after="$(git show HEAD:package.json | jq --raw-output .version)"

# Both versions are printed and substituted into the prefixes, so they must
# be versions: a newline followed by "::" would start a workflow command. A
# missing version reads as "null" and fails too.
semver='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
if [[ ! "$version_before" =~ $semver ]]; then
  echo "::error::The version in package.json at $BEFORE is not a valid semver version."
  exit 1
fi
if [[ ! "$version_after" =~ $semver ]]; then
  echo "::error::The version in package.json is not a valid semver version."
  exit 1
fi

set_output() {
  echo "IS_RELEASE=$1" >>"$GITHUB_OUTPUT"
}

if [[ "$version_before" == "$version_after" ]]; then
  echo "Version unchanged ($version_after). Not a release."
  set_output false
  exit 0
fi

if [[ -n "$COMMIT_STARTS_WITH" ]]; then
  if [[ -z "$COMMIT_MESSAGE" ]]; then
    COMMIT_MESSAGE="$(git log --max-count=1 --format=%s)"
  fi

  match_found=false
  # Prefixes are separated by commas or newlines (a YAML block scalar), with
  # surrounding whitespace trimmed. Empty prefixes are ignored; one would
  # match every commit.
  mapfile -t raw_prefixes < <(tr ',' '\n' <<<"$COMMIT_STARTS_WITH")
  for raw_prefix in "${raw_prefixes[@]}"; do
    raw_prefix="${raw_prefix#"${raw_prefix%%[![:space:]]*}"}"
    raw_prefix="${raw_prefix%"${raw_prefix##*[![:space:]]}"}"
    if [[ -z "$raw_prefix" ]]; then
      continue
    fi
    # The replacement is quoted, so a "&" in the version is not special.
    prefix="${raw_prefix//\[version\]/"$version_after"}"
    # Quoted, so the prefix is matched literally rather than as a pattern.
    if [[ "$COMMIT_MESSAGE" == "$prefix"* ]]; then
      match_found=true
      break
    fi
  done

  if [[ "$match_found" == false ]]; then
    echo "Commit message does not start with any of \"$COMMIT_STARTS_WITH\" (version $version_after). Not a release."
    set_output false
    exit 0
  fi
fi

echo "Version changed from $version_before to $version_after. This is a release."
set_output true
