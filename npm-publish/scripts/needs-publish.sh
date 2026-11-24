#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Usage: needs-publish.sh <name> <version>
#
# Prints <name> if <name>@<version> needs publishing: the version is not
# 0.0.0 and is not on npm yet.

set -euo pipefail

# No xtrace with RUNNER_DEBUG: the environment holds the npm token, which
# GitHub masks in the log only if it came from a secret.

# Tolerate empty invocations (e.g. xargs with no input).
if (($# == 0)); then
  exit 0
fi

name="${1:-}"
local_version="${2:-}"

if [[ -z "$name" || "$name" == "null" ]]; then
  echo "::error::Missing package name." >&2
  exit 1
fi

if [[ -z "$local_version" || "$local_version" == "null" ]]; then
  echo "::error::Missing version for package '$name'." >&2
  exit 1
fi

if [[ "$local_version" == "0.0.0" ]]; then
  exit 0
fi

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Fails, rather than reporting the package as unpublished, if npm can't be
# reached.
published="$("$script_path/npm-view.sh" "$name@$local_version")"
if [[ -n "$published" ]]; then
  exit 0
fi

echo "$name"
