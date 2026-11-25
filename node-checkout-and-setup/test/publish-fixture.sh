#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Publishes node-checkout-and-setup/test-fixture, as committed at HEAD, as the
# root of the test-fixtures/node-checkout-and-setup branch. Some tests need a
# ref of this repository whose root is a Yarn workspace. Run it after changing
# the fixture; the fixture-branch-up-to-date test job fails until then.

set -euo pipefail

branch="test-fixtures/node-checkout-and-setup"
tree="$(git rev-parse HEAD:node-checkout-and-setup/test-fixture)"
commit="$(git commit-tree "$tree" -m "Test fixture for node-checkout-and-setup")"
git push --force origin "$commit:refs/heads/$branch"
echo "Published $commit as $branch."
