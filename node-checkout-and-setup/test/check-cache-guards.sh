#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Test helper. Checks that every step of action.yml that can read or write an
# Actions cache runs only when `is-high-risk-environment` is `false`. A job
# cannot observe whether such a step ran, so this checks the step conditions
# instead.
#
# A cache step is any `actions/cache*` step, or any `actions/setup-node` step
# with a `cache` input. Its `if:` must be a plain `&&` chain (no `||`, no
# parentheses) with `inputs.is-high-risk-environment == 'false'` as one of its
# terms. Every `actions/setup-node` step must also either set
# `package-manager-cache: false` or be guarded the same way, since setup-node
# otherwise enables a cache from package.json's `packageManager` field.
#
# Requires yq (mikefarah, v4) and jq, both preinstalled on GitHub's Ubuntu
# runners.
#
# Usage: check-cache-guards.sh [path/to/action.yml]

set -euo pipefail

action_file="${1:-$(dirname "${BASH_SOURCE[0]}")/../action.yml}"

yq -o=json '.' "$action_file" | jq -r '
  def guarded:
    (.if // "" | tostring
      | sub("^\\s*\\$\\{\\{"; "") | sub("\\}\\}\\s*$"; "")) as $expr
    | ($expr | test("\\|\\||[()]") | not)
      and ($expr | split("&&") | map(gsub("^\\s+|\\s+$"; ""))
        | index("inputs.is-high-risk-environment == '\''false'\''") != null);
  def uses_action($name):
    (.uses // "") | startswith($name + "@") or startswith($name + "/");

  [.runs.steps[] | . + {label: (.name // .id // .uses)}] as $steps
  | [$steps[] | select(uses_action("actions/cache")
      or (uses_action("actions/setup-node") and .with.cache != null))] as $cache
  | [$steps[] | select(uses_action("actions/setup-node"))] as $setup_node
  | (
      [$cache[] | select(guarded | not)
        | "Cache step \"\(.label)\" is not guarded by is-high-risk-environment == '\''false'\''."]
      + [$setup_node[] | select((.with["package-manager-cache"] | tostring) != "false" and (guarded | not))
        | "setup-node step \"\(.label)\" neither sets package-manager-cache: false nor is guarded by is-high-risk-environment == '\''false'\''."]
      + (if ($cache | length) == 0 then ["Found no cache steps; the check would pass vacuously."] else [] end)
      + (if ($setup_node | length) == 0 then ["Found no setup-node steps; the check would pass vacuously."] else [] end)
    ) as $errors
  | ($cache | map("Cache step: \(.label)")[]),
    ($setup_node | map("setup-node step: \(.label)")[]),
    ($errors | map("::error::" + .)[]),
    (if ($errors | length) > 0 then error("\($errors | length) problem(s) found") else empty end)
'
