#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Tests that scripts/environment.sh unsets the job's YARN_* variables, in any
# case (Yarn matches their names case-insensitively), which would otherwise
# override the configuration file the action writes (e.g. redirect publishing
# to another registry), and keeps only the ones the action sets itself; and
# that it stops Corepack from reading COREPACK_* variables from the
# repository's `.corepack.env`.
#
# Usage: test/environment-variables.sh

set -euo pipefail

ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT_SCRIPT="$ACTION_DIR/scripts/environment.sh"
failures=0

# yarn_environment [VAR=value...]: sources environment.sh with the given
# variables and nothing else in the environment, under the same shell options
# as the action's scripts, and prints the YARN_* variables left, in any case,
# sorted, or an error if environment.sh fails.
yarn_environment() {
  # shellcheck disable=SC2016 # Expanded by the inner shell.
  env -i PATH="$PATH" "$@" bash -euo pipefail -c '
    source "$1"
    env | grep -i "^yarn_" | LC_ALL=C sort || true
  ' _ "$ENVIRONMENT_SCRIPT" || echo "environment.sh failed with exit code $?"
}

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "ok - $name"
  else
    echo "not ok - $name"
    echo "    expected: ${expected//$'\n'/ }"
    echo "    actual:   ${actual//$'\n'/ }"
    failures=$((failures + 1))
  fi
}

# Each of these changes where or how Yarn publishes, or what code it runs.
hostile=(
  YARN_NPM_REGISTRY_SERVER=https://example.invalid
  YARN_NPM_PUBLISH_REGISTRY=https://example.invalid
  YARN_NPM_SCOPES='{"consensys-incorporated-test":{"npmPublishRegistry":"https://example.invalid"}}'
  YARN_NPM_AUTH_IDENT=user:password
  YARN_NPM_ALWAYS_AUTH=true
  YARN_HTTPS_PROXY=http://example.invalid
  YARN_HTTP_PROXY=http://example.invalid
  YARN_ENABLE_SCRIPTS=true
  YARN_NODE_LINKER=pnp
  YARN_INJECT_ENVIRONMENT_FILES=.env
  YARN_YARN_PATH=.yarn/releases/canary.cjs
  YARN_PLUGINS=.yarn/plugins/canary.cjs
  YARN_CACHE_FOLDER=/tmp/yarn-cache
  # Yarn reads these too: it matches names case-insensitively.
  yarn_rc_filename=.yarnrc.yml
  yarn_npm_publish_registry=https://example.invalid
  Yarn_Npm_Registry_Server=https://example.invalid
  yarn_https_proxy=http://example.invalid
  yarn_npm_auth_token=other-token
  yarn_ignore_path=0
)

kept=(
  YARN_IGNORE_PATH=1
  YARN_NPM_AUTH_TOKEN=token
  YARN_RC_FILENAME=.yarnrc-test.yml
)

check "hostile YARN_* variables are unset; the action's own are kept with their values" \
  "$(printf '%s\n' "${kept[@]}")" \
  "$(yarn_environment "${hostile[@]}" "${kept[@]}" NOT_YARN_VARIABLE=1)"

check "only hostile YARN_* variables: none left" \
  "" "$(yarn_environment "${hostile[@]}")"

check "no YARN_* variables: succeeds" \
  "" "$(yarn_environment)"

# Variables that merely contain YARN_ are left alone.
# shellcheck disable=SC2016 # Expanded by the inner shell.
actual="$(env -i PATH="$PATH" MY_YARN_SETTING=1 bash -euo pipefail -c '
  source "$1"
  printf "%s" "${MY_YARN_SETTING:-}"
' _ "$ENVIRONMENT_SCRIPT" || echo "environment.sh failed with exit code $?")"
check "other variables are kept" "1" "$actual"

# With real Corepack: a `.corepack.env` in the project can allow a URL as the
# `packageManager`, so that `yarn` would download and run any script.
# environment.sh stops Corepack from reading that file.
PROJECT="$(mktemp -d "${TMPDIR:-/tmp}/npm-publish-corepack.XXXXXX")"
echo '{"packageManager": "yarn@https://example.invalid/yarn.js"}' >"$PROJECT/package.json"
echo 'COREPACK_ENABLE_UNSAFE_CUSTOM_URLS=1' >"$PROJECT/.corepack.env"
# corepack_yarn [environment.sh]: runs `corepack yarn --version` in $PROJECT,
# after sourcing the given script if any, and prints its output.
corepack_yarn() {
  # shellcheck disable=SC2016 # Expanded by the inner shell.
  (cd "$PROJECT" && env -i PATH="$PATH" HOME="$PROJECT" COREPACK_HOME="$PROJECT/corepack" bash -c '
    if [[ -n "$1" ]]; then source "$1"; fi
    corepack yarn --version 2>&1
  ' _ "$@" || true)
}
# corepack_outcome <output>: "tried" if Corepack requested the URL, "refused"
# if it rejected it, or the output otherwise.
corepack_outcome() {
  if [[ "$1" == *"request to https://example.invalid/yarn.js"* ]]; then
    echo tried
  elif [[ "$1" == *"Illegal use of URL for known package manager"* ]]; then
    echo refused
  else
    echo "$1"
  fi
}
# Control: without environment.sh, Corepack reads the file and tries the URL.
check "control: Corepack reads .corepack.env without environment.sh" \
  "tried" "$(corepack_outcome "$(corepack_yarn)")"
check "Corepack ignores .corepack.env after environment.sh" \
  "refused" "$(corepack_outcome "$(corepack_yarn "$ENVIRONMENT_SCRIPT")")"
rm -r "$PROJECT"

if ((failures > 0)); then
  echo "$failures failure(s)"
  exit 1
fi
echo "All tests passed."
