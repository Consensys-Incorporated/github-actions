#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# For each packed tarball in $PACK_DIR, writes an HTML diff against the package's
# latest version on npm with pkdiff. A package not yet on npm has nothing to
# diff against; that failure is ignored.

set -euo pipefail

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

: "${PACK_DIR:?PACK_DIR must be set}"

for file in "$PACK_DIR"/*.tgz; do
  [[ -f "$file" ]] || continue
  echo "Processing $file"
  name="$(tar -O -zxf "$file" package/package.json | jq --raw-output .name)"
  echo "$name"
  # `--` so that a name starting with `-` isn't read as an option.
  pkdiff \
    --no-exit-code \
    --no-open \
    --output "$PACK_DIR/$(basename "$file").html" \
    -- "$file" "$name@latest" || true
done
