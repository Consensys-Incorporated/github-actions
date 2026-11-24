#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Decides whether HEAD is a release commit: the root package.json version
# differs from the one at BEFORE, and, if COMMIT_STARTS_WITH is set, the commit
# message starts with one of its comma-separated prefixes (with "[version]"
# replaced by the new version). Prefixes are matched literally.
#
# Environment:
#   BEFORE: the commit to compare with (required)
#   COMMIT_STARTS_WITH: comma-separated prefixes (optional)
#   COMMIT_MESSAGE: message to check instead of HEAD's subject (optional)
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

# Fetch BEFORE in case the push contained more than one commit.
git fetch --quiet origin "$BEFORE"

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
  IFS=',' read -ra raw_prefixes <<<"$COMMIT_STARTS_WITH"
  for raw_prefix in "${raw_prefixes[@]}"; do
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
