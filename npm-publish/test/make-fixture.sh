#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Usage: make-fixture.sh <kind> <dir>
#
# Creates a Yarn project in <dir> and installs it (with Corepack and the
# project's own configuration, as the caller's setup step would). Kinds:
#
#   monorepo     public new package, public package already on npm at its
#                version (left-pad@1.3.0), private package, 0.0.0 package
#   existing     one public package that is on npm, at a version that is not
#                (left-pad@999.0.0)
#   polyrepo     a single public new package at the root
#   canary       a monorepo whose Yarn plugin, yarnPath, lifecycle scripts and
#                `bash`, `jq`, `npm` and `yarn` bins (declared by a private
#                workspace the package depends on) write marker files to
#                $CANARY_DIR
#   registry     a package with publishConfig.registry set to another registry
#   old-yarn     the monorepo fixture with Yarn 4.15.0

set -euo pipefail

kind="$1"
dir="$2"
YARN_VERSION=4.18.1
NEW_PACKAGE_SCOPE="@consensys-incorporated-test"

mkdir -p "$dir"
cd "$dir"

root_manifest() {
  local yarn_version="${1:-$YARN_VERSION}"
  jq -n --arg yarn "yarn@$yarn_version" '{
    name: "npm-publish-fixture", version: "1.0.0", private: true,
    workspaces: ["packages/*"], packageManager: $yarn
  }' >package.json
}

pkg() {
  local path="$1" manifest="$2"
  mkdir -p "$path"
  echo "$manifest" >"$path/package.json"
  echo "module.exports = 1;" >"$path/index.js"
}

yarnrc() {
  printf 'nodeLinker: node-modules\nenableTelemetry: false\n' >.yarnrc.yml
}

case "$kind" in
  monorepo | old-yarn)
    if [[ "$kind" == old-yarn ]]; then root_manifest 4.15.0; else root_manifest; fi
    yarnrc
    pkg packages/new "{\"name\": \"$NEW_PACKAGE_SCOPE/npm-publish-fixture-a\", \"version\": \"1.0.0\"}"
    pkg packages/published '{"name": "left-pad", "version": "1.3.0"}'
    pkg packages/private '{"name": "private-package", "version": "1.0.0", "private": true}'
    pkg packages/unversioned "{\"name\": \"$NEW_PACKAGE_SCOPE/npm-publish-fixture-b\", \"version\": \"0.0.0\"}"
    ;;
  existing)
    root_manifest
    yarnrc
    pkg packages/published '{"name": "left-pad", "version": "999.0.0"}'
    ;;
  polyrepo)
    jq -n --arg yarn "yarn@$YARN_VERSION" --arg name "$NEW_PACKAGE_SCOPE/npm-publish-fixture-root" \
      '{name: $name, version: "1.0.0", packageManager: $yarn}' >package.json
    echo "module.exports = 1;" >index.js
    yarnrc
    ;;
  registry)
    root_manifest
    yarnrc
    pkg packages/new "{\"name\": \"$NEW_PACKAGE_SCOPE/npm-publish-fixture-a\", \"version\": \"1.0.0\", \"publishConfig\": {\"registry\": \"https://npm.example.com/\"}}"
    ;;
  canary)
    : "${CANARY_DIR:?}"
    mkdir -p "$CANARY_DIR" .yarn/plugins
    root_manifest
    cat >.yarn/plugins/canary.cjs <<EOF
module.exports = {
  name: 'canary',
  factory: () => {
    require('fs').writeFileSync('$CANARY_DIR/plugin', 'ran');
    return {};
  },
};
EOF
    cat >.yarnrc.yml <<'EOF'
nodeLinker: node-modules
enableTelemetry: false
plugins:
  - path: .yarn/plugins/canary.cjs
EOF
    # Yarn puts a workspace's dependencies' bins first on PATH when it runs a
    # command in that workspace.
    pkg packages/bins '{
      "name": "npm-publish-fixture-bins", "version": "1.0.0", "private": true,
      "bin": {"bash": "bin.js", "jq": "bin.js", "npm": "bin.js", "yarn": "bin.js"}
    }'
    printf '#!/usr/bin/env node\nrequire("fs").writeFileSync(%s, "ran");\n' \
      "$(jq -n --arg path "$CANARY_DIR/bin" '$path')" >packages/bins/bin.js
    pkg packages/canary "$(jq -n --arg dir "$CANARY_DIR" --arg name "$NEW_PACKAGE_SCOPE/npm-publish-fixture-canary" '{
      name: $name, version: "999.0.0",
      dependencies: {"npm-publish-fixture-bins": "workspace:*"},
      publishConfig: {registry: "https://registry.npmjs.org/"},
      scripts: {
        prepublish: ("touch " + $dir + "/prepublish"),
        prepublishOnly: ("touch " + $dir + "/prepublishOnly"),
        prepack: ("touch " + $dir + "/prepack"),
        postpack: ("touch " + $dir + "/postpack")
      }
    }')"
    ;;
  *)
    echo "Unknown fixture kind: $kind" >&2
    exit 1
    ;;
esac

git init -q
# Corepack must already be enabled, as after node-checkout-and-setup.
COREPACK_ENABLE_DOWNLOAD_PROMPT=0 yarn install --no-immutable

if [[ "$kind" == canary ]]; then
  # The plugin must have loaded during the install, or the canary proves nothing.
  test -e "$CANARY_DIR/plugin"
  # The bins must shadow the real tools in the canary workspace, or the canary
  # proves nothing.
  yarn workspace "$NEW_PACKAGE_SCOPE/npm-publish-fixture-canary" exec jq --version
  test -e "$CANARY_DIR/bin"
  rm "$CANARY_DIR/bin" "$CANARY_DIR/plugin"
  mkdir -p .yarn/releases
  echo "require('fs').writeFileSync('$CANARY_DIR/yarnpath', 'ran'); process.exit(1);" >.yarn/releases/canary.cjs
  echo "yarnPath: .yarn/releases/canary.cjs" >>.yarnrc.yml
fi
