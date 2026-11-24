#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Tests publish.sh's mode selection and main.sh's checks with `yarn` and `npm`
# replaced by shims that record their arguments.
#
# Usage: test/publish-modes.sh

set -euo pipefail

ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ACTION_DIR/scripts"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/npm-publish-test.XXXXXX")"
SHIMS="$WORK/shims"
failures=0

mkdir -p "$SHIMS"

# npm: `npm view <spec> version --json` prints a version iff <spec> is a line
# of $NPM_PUBLISHED, fails with E500 if the file has a "!error" line, and with
# E404 otherwise.
cat >"$SHIMS/npm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "view" ]]; then
  if grep -qxF -- "$2" "$NPM_PUBLISHED"; then
    echo '"1.0.0"'
    exit 0
  fi
  if grep -qxF -- '!error' "$NPM_PUBLISHED"; then
    echo '{"error": {"code": "E500", "summary": "Internal Server Error"}}'
    echo "npm error code E500" >&2
    exit 1
  fi
  echo '{"error": {"code": "E404", "summary": "Not Found"}}'
  echo "npm error code E404" >&2
  exit 1
fi
echo "npm shim: unexpected command $*" >&2
exit 1
EOF

# yarn: logs its arguments and whether YARN_NPM_AUTH_TOKEN is set; implements
# --version, `workspaces list` (prints $SHIM_WORKSPACES) and `pack --out`.
cat >"$SHIMS/yarn" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  echo "${SHIM_YARN_VERSION:-4.18.1}"
  exit 0
fi
if [[ "$1 $2" == "workspaces list" ]]; then
  printf '%s\n' "$SHIM_WORKSPACES"
  exit 0
fi
printf 'yarn' >>"$SHIM_LOG"
printf ' %q' "$@" >>"$SHIM_LOG"
printf ' [token=%s]\n' "${YARN_NPM_AUTH_TOKEN:+set}" >>"$SHIM_LOG"
if [[ "$1" == "pack" && "$2" == "--out" ]]; then
  name="$(jq -r .name package.json)"
  version="$(jq -r .version package.json)"
  out="${3//%s/${name//\//-}}"
  out="${out//%v/$version}"
  echo "tarball of $name@$version" >"$out"
fi
EOF
chmod +x "$SHIMS/npm" "$SHIMS/yarn"

PKG="$WORK/pkg"
mkdir -p "$PKG"
echo '{"name": "@test/npm-publish-modes", "version": "1.2.3"}' >"$PKG/package.json"
PACK_DIR="$WORK/packages"
mkdir -p "$PACK_DIR"
TARBALL="$PACK_DIR/@test-npm-publish-modes-1.2.3.tgz"

# run_publish <published: yes|no|error> [VAR=value...]: runs publish.sh in $PKG.
run_publish() {
  local published="$1"
  shift
  case "$published" in
    yes) echo "@test/npm-publish-modes" >"$WORK/published" ;;
    error) echo '!error' >"$WORK/published" ;;
    *) : >"$WORK/published" ;;
  esac
  : >"$WORK/shim.log"
  : >"$WORK/output"
  : >"$WORK/summary"
  rm -f "$TARBALL"
  set +e
  LOG="$(cd "$PKG" && env -u ACTIONS_ID_TOKEN_REQUEST_URL -u YARN_NPM_AUTH_TOKEN \
    PATH="$SHIMS:$PATH" SHIM_LOG="$WORK/shim.log" NPM_PUBLISHED="$WORK/published" \
    PACK_DIR="$PACK_DIR" GITHUB_STEP_SUMMARY="$WORK/summary" \
    PUBLISH_NPM_TAG=next DRY_RUN= REPOSITORY_VISIBILITY=public "$@" "$SCRIPTS/publish.sh" 2>&1)"
  STATUS=$?
  set -e
}

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "ok - $name"
  else
    echo "not ok - $name"
    while IFS= read -r line; do echo "    $line"; done <<<"$LOG"
    echo "    shim log: $(cat "$WORK/shim.log")"
    failures=$((failures + 1))
  fi
}

# shellcheck disable=SC2016 # Literal backticks in the summary.
packed() {
  ((STATUS == 0)) && grep -qxF "yarn pack --out $PACK_DIR/%s-%v.tgz [token=${1:-}]" "$WORK/shim.log" &&
    ! grep -q 'npm publish' "$WORK/shim.log" && test -f "$TARBALL" &&
    grep -qx '### @test/npm-publish-modes' "$WORK/summary" && grep -q '^- Checksum: `[0-9a-f]\{40\}`$' "$WORK/summary" &&
    grep -q '^- Integrity: `sha512-' "$WORK/summary"
}

published_with() {
  ((STATUS == 0)) && [[ "$(cat "$WORK/shim.log")" == "$1" ]] && test ! -e "$TARBALL"
}

failed_with() {
  ((STATUS != 0)) && grep -qF -- "$1" <<<"$LOG" && [[ ! -s "$WORK/shim.log" ]]
}

run_publish no DRY_RUN=true YARN_NPM_AUTH_TOKEN=token
check "dry-run true with a token packs" packed set

run_publish yes DRY_RUN=true ACTIONS_ID_TOKEN_REQUEST_URL=https://oidc
check "dry-run true with OIDC packs" packed

run_publish no YARN_NPM_AUTH_TOKEN=token
check "new package with a token: token publish, no staging or provenance" \
  published_with 'yarn npm publish --tag next [token=set]'

run_publish no
check "new package without a token packs" packed

run_publish no DRY_RUN=false
check "new package without a token, dry-run false: fails" failed_with "'npm-token' not provided"

run_publish yes ACTIONS_ID_TOKEN_REQUEST_URL=https://oidc YARN_NPM_AUTH_TOKEN=token
check "existing package with OIDC: staged publish with provenance, token unset" \
  published_with 'yarn npm publish --tag next --staged --provenance [token=]'

run_publish yes ACTIONS_ID_TOKEN_REQUEST_URL=https://oidc REPOSITORY_VISIBILITY=private
check "existing package with OIDC in a private repository: no provenance" \
  published_with 'yarn npm publish --tag next --staged [token=]'

run_publish yes YARN_NPM_AUTH_TOKEN=token
check "existing package without OIDC packs (the token is not used)" packed

run_publish error YARN_NPM_AUTH_TOKEN=token
check "npm lookup error other than 404: fails without publishing" failed_with "'npm view @test/npm-publish-modes' failed"

run_publish yes DRY_RUN=false YARN_NPM_AUTH_TOKEN=token
check "existing package without OIDC, dry-run false: fails" failed_with "OIDC is not available"

run_publish yes ACTIONS_ID_TOKEN_REQUEST_URL=https://oidc PUBLISH_NPM_TAG='beta tag'
check "npm-tag is passed as one argument" \
  published_with 'yarn npm publish --tag beta\ tag --staged --provenance [token=]'

echo '{"name": "@test/npm-publish-modes", "version": "0.0.0"}' >"$PKG/package.json"
run_publish no YARN_NPM_AUTH_TOKEN=token
check "version 0.0.0 is skipped" bash -c "(($STATUS == 0)) && [[ ! -s '$WORK/shim.log' ]]"
echo '{"name": "@test/npm-publish-modes", "version": "1.2.3"}' >"$PKG/package.json"

# main.sh checks, in a polyrepo.
run_main() {
  : >"$WORK/shim.log"
  : >"$WORK/output"
  set +e
  LOG="$(cd "${MAIN_DIR:-$PKG}" && env -u ACTIONS_ID_TOKEN_REQUEST_URL -u GITHUB_SHA \
    PATH="$SHIMS:$PATH" SHIM_LOG="$WORK/shim.log" NPM_PUBLISHED="$WORK/published" PACK_DIR="$PACK_DIR" \
    GITHUB_OUTPUT="$WORK/output" GITHUB_STEP_SUMMARY="$WORK/summary" \
    PUBLISH_NPM_TAG=next DRY_RUN=true YARN_RC_FILENAME=.yarnrc-test.yml "$@" "$SCRIPTS/main.sh" 2>&1)"
  STATUS=$?
  set -e
}

run_main YARN_RC_FILENAME=
check "missing Yarn configuration file fails" failed_with "YARN_RC_FILENAME not set"

run_main PUBLISH_NPM_TAG=
check "empty npm-tag fails" failed_with "'npm-tag' not set"

run_main SHIM_YARN_VERSION=4.15.0
check "Yarn older than 4.16 fails" failed_with "Yarn 4.16.0 or higher is required"

run_main SHIM_YARN_VERSION=3.8.7
check "Yarn 3 fails" failed_with "Yarn 4.16.0 or higher is required"

run_main SHIM_YARN_VERSION=4.16.0
check "Yarn 4.16.0 is accepted; packing sets dry-run=true" \
  bash -c "(($STATUS == 0)) && grep -q 'yarn pack' '$WORK/shim.log' && grep -qx 'dry-run=true' '$WORK/output'"

echo "@test/npm-publish-modes@1.2.3" >"$WORK/published"
run_main
check "polyrepo whose version is already on npm: nothing published, dry-run=false" \
  bash -c "(($STATUS == 0)) && grep -q 'No packages need publishing' <<<\"\$1\" && [[ ! -s '$WORK/shim.log' ]] && grep -qx 'dry-run=false' '$WORK/output'" _ "$LOG"
: >"$WORK/published"

echo '{"name": "@test/npm-publish-modes", "version": "1.2.3", "private": true}' >"$PKG/package.json"
run_main
check "private polyrepo root: not published" \
  bash -c "(($STATUS == 0)) && grep -q 'The package is private' <<<\"\$1\" && [[ ! -s '$WORK/shim.log' ]]" _ "$LOG"
echo '{"name": "@test/npm-publish-modes", "version": "1.2.3"}' >"$PKG/package.json"

echo '!error' >"$WORK/published"
run_main
check "polyrepo with an npm lookup error: fails" failed_with "failed with exit code 1"
: >"$WORK/published"

# main.sh in a monorepo, whose public workspaces Yarn lists as c, a and b. b
# is on npm at its version.
MONO="$WORK/mono"
for name in a b c; do
  mkdir -p "$MONO/packages/$name"
  echo "{\"name\": \"@test/$name\", \"version\": \"1.0.0\"}" >"$MONO/packages/$name/package.json"
done
echo '{"name": "root", "private": true, "workspaces": ["packages/*"]}' >"$MONO/package.json"
mono_workspaces='{"location":"packages/c","name":"@test/c"}
{"location":"packages/a","name":"@test/a"}
{"location":"packages/b","name":"@test/b"}'
echo "@test/b@1.0.0" >"$WORK/published"

packed_c_then_a() {
  ((STATUS == 0)) && [[ "$(grep -c '^yarn pack' "$WORK/shim.log")" == 2 ]] &&
    [[ "$(grep -o 'from packages/[a-c]' <<<"$LOG")" == $'from packages/c\nfrom packages/a' ]] &&
    test -f "$PACK_DIR/@test-a-1.0.0.tgz" && test -f "$PACK_DIR/@test-c-1.0.0.tgz" &&
    test ! -e "$PACK_DIR/@test-b-1.0.0.tgz" && grep -qx 'dry-run=true' "$WORK/output"
}

stopped_after_c() {
  ((STATUS != 0)) && [[ "$(grep -o 'from packages/[a-c]' <<<"$LOG")" == 'from packages/c' ]] &&
    [[ ! -s "$WORK/shim.log" ]]
}

rm -f "$PACK_DIR"/*.tgz
MAIN_DIR="$MONO" run_main SHIM_WORKSPACES="$mono_workspaces"
check "monorepo: pending workspaces are packed in the order Yarn lists them" packed_c_then_a

MAIN_DIR="$MONO" run_main SHIM_WORKSPACES="$mono_workspaces" DRY_RUN=false
check "monorepo: the first failure stops the remaining workspaces" stopped_after_c
: >"$WORK/published"

rm -f "$TARBALL" "$PACK_DIR"/*.tgz
if ((failures > 0)); then
  echo "$failures failure(s)"
  exit 1
fi
echo "All tests passed."
