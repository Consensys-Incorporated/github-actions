#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Usage: needs-publish.sh <name> <version>
#
# Prints <name> if <name>@<version> needs publishing: the version is not
# 0.0.0 and is not on npm yet. Fails unless <name> is a valid npm package name
# and <version> a semantic version: both come from the repository, and later
# steps print them and pass them to commands.

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

# npm's rules for package names, except that upper case is allowed, as in
# names published before the rule.
name_pattern='^(@[A-Za-z0-9~-][A-Za-z0-9._~-]*/)?[A-Za-z0-9~-][A-Za-z0-9._~-]*$'
if [[ ! "$name" =~ $name_pattern || ${#name} -gt 214 ]]; then
  # %q keeps the value on one line.
  printf '::error::Invalid package name: %q\n' "$name" >&2
  exit 1
fi

if [[ -z "$local_version" || "$local_version" == "null" ]]; then
  echo "::error::Missing version for package '$name'." >&2
  exit 1
fi

identifier='[0-9A-Za-z-]+'
version_pattern="^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-$identifier(\.$identifier)*)?(\+$identifier(\.$identifier)*)?\$"
if [[ ! "$local_version" =~ $version_pattern ]]; then
  printf '::error::Invalid version for package %s: %q\n' "$name" "$local_version" >&2
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
