#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Decides whether HEAD is a release commit: the root package.json version
# differs from the one at BEFORE, and, if COMMIT_STARTS_WITH is set, the commit
# message starts with one of its prefixes, separated by commas or newlines
# (with "[version]" replaced by the new version). Prefixes are matched
# literally.
#
# Environment:
#   BEFORE: the commit to compare with (required)
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

# Fetch BEFORE in case the push contained more than one commit. The checkout
# doesn't persist credentials, so a private repository needs the token. It is
# passed through the environment for this one command (not argv, not
# .git/config). The empty value first clears any header a caller's checkout
# configured for the same URL, so only one Authorization header is sent.
fetch_before() {
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    git fetch --quiet origin "$BEFORE"
    return
  fi
  local key auth
  key="http.${GITHUB_SERVER_URL:-https://github.com}/.extraheader"
  auth="$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')"
  echo "::add-mask::$auth"
  GIT_CONFIG_COUNT=2 \
    GIT_CONFIG_KEY_0="$key" GIT_CONFIG_VALUE_0="" \
    GIT_CONFIG_KEY_1="$key" GIT_CONFIG_VALUE_1="AUTHORIZATION: basic $auth" \
    git fetch --quiet origin "$BEFORE"
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
version_after="$(jq --raw-output .version package.json)"

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
