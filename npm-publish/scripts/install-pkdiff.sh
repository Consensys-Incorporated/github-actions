#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Installs pkdiff into $PKDIFF_DIR with `npm ci`, so that pkdiff and each of
# its dependencies are the version, with the integrity hash, in the action's
# pkdiff/package-lock.json. pkdiff reads diff2html's files from its own
# node_modules, so the lockfile nests them there, and `npm ci` is given
# --install-strategy=shallow so that it keeps that layout: with another
# strategy, such as npm_config_install_strategy=linked from the caller's job,
# it would install them elsewhere. To update the lockfile, run `npm install
# --ignore-scripts` in pkdiff/, whose .npmrc sets install-strategy=shallow.
#
# Environment: ACTION_PATH (the action's directory), PKDIFF_DIR.

set -euo pipefail

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

: "${ACTION_PATH:?ACTION_PATH must be set}"
: "${PKDIFF_DIR:?PKDIFF_DIR must be set}"

# A new directory holding only the manifest and the lockfile, so that nothing
# an earlier step left there applies (such as an .npmrc, which npm reads as the
# project's configuration).
rm -rf -- "$PKDIFF_DIR"
mkdir -p "$PKDIFF_DIR"
cp "$ACTION_PATH/pkdiff/package.json" "$ACTION_PATH/pkdiff/package-lock.json" "$PKDIFF_DIR/"
cd "$PKDIFF_DIR"

# Without install scripts. `npm ci` downloads the lockfile's
# https://registry.npmjs.org URLs from the configured registry, so --registry
# overrides npm_config_registry from the caller's job. (pkdiff's dependencies
# are unscoped, so no scope's registry applies.) The lockfile's integrity
# hashes are checked either way. --install-strategy=shallow overrides
# npm_config_install_strategy (see above).
npm ci --ignore-scripts --no-audit --no-fund --install-strategy=shallow --registry https://registry.npmjs.org

# report.sh ignores pkdiff's failures, so check here that the install put
# diff2html where pkdiff reads it: not so after an install with another
# layout, or one that did nothing (npm_config_dry_run=true).
if [[ ! -d node_modules/pkdiff/node_modules/diff2html ]]; then
  echo "::error::npm ci did not install pkdiff's diff2html in $PKDIFF_DIR/node_modules/pkdiff/node_modules."
  exit 1
fi
