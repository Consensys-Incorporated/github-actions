#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Sourced by every script that runs Yarn.
#
# `YARN_*` environment variables override the configuration file the action
# controls (e.g. YARN_NPM_PUBLISH_REGISTRY), and the caller's job may set them.
# Unset all of them except the ones the action itself sets or needs.
#
# `yarn` is Corepack's shim, and Corepack reads `COREPACK_*` variables from a
# `.corepack.env` file in the repository as well as from the environment. In
# that file, COREPACK_ENABLE_UNSAFE_CUSTOM_URLS=1 would let the
# `packageManager` field be any URL. Set COREPACK_ENV_FILE=0 so that Corepack
# doesn't read the file. COREPACK_* variables set by the caller's job, such as
# a mirror's COREPACK_NPM_REGISTRY, are left alone.

for name in $(compgen -e | grep '^YARN_' || true); do
  case "$name" in
    YARN_NPM_AUTH_TOKEN | YARN_RC_FILENAME | YARN_IGNORE_PATH) ;;
    *) unset "$name" ;;
  esac
done

export COREPACK_ENV_FILE=0
