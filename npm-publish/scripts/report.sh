#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# For each packed tarball in $PACK_DIR, writes an HTML diff against the package's
# latest version on npm with the pkdiff that install-pkdiff.sh installed in
# $PKDIFF_DIR. A package not yet on npm has nothing to diff against; that
# failure is ignored. Run from outside the repository, so that no .npmrc in it
# applies.

set -euo pipefail

if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
  set -x
fi

: "${PACK_DIR:?PACK_DIR must be set}"
: "${PKDIFF_DIR:?PKDIFF_DIR must be set}"
pkdiff="$PKDIFF_DIR/node_modules/.bin/pkdiff"

for file in "$PACK_DIR"/*.tgz; do
  [[ -f "$file" ]] || continue
  echo "Processing $file"
  name="$(tar -O -zxf "$file" package/package.json | jq --raw-output .name)"
  echo "$name"
  # `--` so that a name starting with `-` isn't read as an option. pkdiff
  # downloads <name>@latest with `npm pack --registry=<registry>`, which
  # overrides npm_config_registry from the caller's job but not a scope's
  # registry (e.g. npm_config_@scope:registry), for which pkdiff has no
  # option.
  "$pkdiff" \
    --no-exit-code \
    --no-open \
    --registry https://registry.npmjs.org \
    --output "$PACK_DIR/$(basename "$file").html" \
    -- "$file" "$name@latest" || true
done
