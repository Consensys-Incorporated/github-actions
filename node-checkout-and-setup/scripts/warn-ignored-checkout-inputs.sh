#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Run when the workspace is already a git repository, so the action skips its
# checkout. `ref` and `persist-credentials` are passed to that checkout, so
# warn when either is set: the caller would otherwise get neither, with no
# message. Nothing is downloaded from `ref` into a checkout either, so it has
# no effect at all. The input values are not printed, so they can't inject
# workflow commands.
#
# Environment:
#   INPUT_REF: the `ref` input
#   PERSIST_CREDENTIALS: the `persist-credentials` input (`true` or `false`)

set -euo pipefail

echo 'The workspace is already a git repository; not checking it out again.'
if [[ -n "$INPUT_REF" ]]; then
  echo "::warning::'ref' has no effect because the workspace is already a git repository: it is not checked out, and nothing is downloaded from it. Check out that ref in the step that ran actions/checkout before this action."
fi
if [[ "$PERSIST_CREDENTIALS" != "false" ]]; then
  echo "::warning::'persist-credentials: true' has no effect because the workspace is already a git repository; .git/config is left as it is. Set persist-credentials on the checkout that ran before this action."
fi
