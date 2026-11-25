#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Tests publish.sh's mode selection, main.sh's checks, install-pkdiff.sh's
# `npm ci` and report.sh's pkdiff arguments with `yarn`, `npm` and `pkdiff`
# replaced by shims that record their arguments; and that pkdiff's lockfile
# downloads only from the npm registry.
#
# Usage: test/publish-modes.sh

set -euo pipefail

ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ACTION_DIR/scripts"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/npm-publish-test.XXXXXX")"
SHIMS="$WORK/shims"
failures=0

mkdir -p "$SHIMS"

# npm: `npm view [options] -- <spec> version` prints a version iff <spec> is a
# line of $NPM_PUBLISHED, fails with E500 if the file has a "!error" line, and
# with E404 otherwise. Fails if <spec> doesn't follow `--`, or if the options
# don't include `--registry https://registry.npmjs.org` and, for a scoped
# <spec>, `--@<scope>:registry=https://registry.npmjs.org`: npm_config_*
# variables from the caller's job could otherwise redirect the lookup.
cat >"$SHIMS/npm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "view" ]]; then
  options=()
  while (($# > 0)) && [[ "$1" != "--" ]]; do
    options+=("$1")
    shift
  done
  if (($# < 2)); then
    echo "npm shim: no -- before the spec" >&2
    exit 1
  fi
  if [[ " ${options[*]} " != *" --registry https://registry.npmjs.org "* ]]; then
    echo "npm shim: no --registry https://registry.npmjs.org" >&2
    exit 1
  fi
  if [[ "$2" == @*/* && " ${options[*]} " != *" --${2%%/*}:registry=https://registry.npmjs.org "* ]]; then
    echo "npm shim: no --${2%%/*}:registry=https://registry.npmjs.org" >&2
    exit 1
  fi
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
# npm ci: logs its arguments and the files in its directory, and installs a
# pkdiff that logs its arguments, and pkdiff's diff2html unless
# $SHIM_NO_DIFF2HTML is set.
if [[ "$1" == "ci" ]]; then
  printf 'npm' >>"$SHIM_LOG"
  printf ' %q' "$@" >>"$SHIM_LOG"
  printf ' [files=%s]\n' "$(LC_ALL=C ls -A | tr '\n' ' ')" >>"$SHIM_LOG"
  mkdir -p node_modules/.bin
  if [[ -z "${SHIM_NO_DIFF2HTML:-}" ]]; then
    mkdir -p node_modules/pkdiff/node_modules/diff2html
  fi
  cat >node_modules/.bin/pkdiff <<'PKDIFF'
#!/usr/bin/env bash
printf 'pkdiff' >>"$SHIM_LOG"
printf ' %q' "$@" >>"$SHIM_LOG"
echo >>"$SHIM_LOG"
PKDIFF
  chmod +x node_modules/.bin/pkdiff
  exit 0
fi
echo "npm shim: unexpected command $*" >&2
exit 1
EOF

# yarn: logs its arguments and whether YARN_NPM_AUTH_TOKEN is set; implements
# --version, `workspaces list` (prints $SHIM_WORKSPACES) and `pack --out`.
# Prints a workflow command, as a packed file's name could.
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
echo "::warning::from yarn"
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

for value in True yes 1; do
  run_publish yes ACTIONS_ID_TOKEN_REQUEST_URL=https://oidc DRY_RUN="$value"
  check "dry-run '$value' fails without publishing" failed_with "'dry-run' must be 'true', 'false' or empty"
done

no_token_in_log() {
  ((STATUS == 0)) && [[ -s "$WORK/shim.log" ]] && ! grep -qF -- "$1" <<<"$LOG"
}
run_publish no RUNNER_DEBUG=1 YARN_NPM_AUTH_TOKEN=npm_secret_value
check "RUNNER_DEBUG=1: publish.sh doesn't print the token" no_token_in_log npm_secret_value
run_publish yes RUNNER_DEBUG=1 YARN_NPM_AUTH_TOKEN=npm_secret_value ACTIONS_ID_TOKEN_REQUEST_URL=https://oidc
check "RUNNER_DEBUG=1, OIDC: publish.sh doesn't print the token" no_token_in_log npm_secret_value

# Yarn's output is wrapped in ::stop-commands::<token> ... ::<token>::.
yarn_output_quoted() {
  local token
  token="$(sed -n 's/^::stop-commands::\([0-9a-f]\{32\}\)$/\1/p' <<<"$LOG")"
  [[ -n "$token" ]] &&
    [[ "$(grep -A 1 -xF "::stop-commands::$token" <<<"$LOG")" == "::stop-commands::$token"$'\n'"::warning::from yarn" ]] &&
    grep -qxF "::$token::" <<<"$LOG"
}
run_publish no
check "yarn pack's output is not read as workflow commands" yarn_output_quoted
run_publish yes ACTIONS_ID_TOKEN_REQUEST_URL=https://oidc
check "yarn npm publish's output is not read as workflow commands" yarn_output_quoted

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
  LOG="$(cd "${MAIN_DIR:-$PKG}" && env -u ACTIONS_ID_TOKEN_REQUEST_URL \
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

run_main RUNNER_DEBUG=1 DRY_RUN= YARN_NPM_AUTH_TOKEN=npm_secret_value
check "RUNNER_DEBUG=1: main.sh doesn't print the token" no_token_in_log npm_secret_value

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

# Names and versions from the repository are validated before they are
# printed or used.
no_injected_command() {
  ! grep -q '^::warning::injected' <<<"$LOG"
}
jq -n '{name: "@test/npm-publish-modes", version: "1.2.3\n::warning::injected"}' >"$PKG/package.json"
run_main
check "invalid version: fails" failed_with "Invalid version for package @test/npm-publish-modes"
check "invalid version: not printed as a workflow command" no_injected_command
echo '{"name": "@test/npm-publish-modes", "version": "v1.2.3"}' >"$PKG/package.json"
run_main
check "version with a v prefix: fails" failed_with "Invalid version for package @test/npm-publish-modes: v1.2.3"
jq -n '{name: "@test/x\n::warning::injected", version: "1.2.3"}' >"$PKG/package.json"
run_main
check "invalid name: fails" failed_with "Invalid package name"
check "invalid name: not printed as a workflow command" no_injected_command
echo '{"name": "@test/npm-publish-modes", "version": "1.2.3-beta.1+build.5"}' >"$PKG/package.json"
run_main
check "prerelease version with build metadata is accepted" \
  bash -c "(($STATUS == 0)) && grep -q 'yarn pack' '$WORK/shim.log'"
echo '{"name": "@test/npm-publish-modes", "version": "1.2.3"}' >"$PKG/package.json"

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

# A name with a space and a quote reaches needs-publish.sh whole, which
# rejects it.
echo '{"name": "@test/it'"'"'s a", "version": "1.0.0"}' >"$MONO/packages/a/package.json"
MAIN_DIR="$MONO" run_main SHIM_WORKSPACES="$mono_workspaces"
check "monorepo: a name with a space and a quote is rejected whole" failed_with "Invalid package name: @test/it\\'s\\ a"
echo '{"name": "@test/a", "version": "1.0.0"}' >"$MONO/packages/a/package.json"
: >"$WORK/published"

rm -f "$TARBALL" "$PACK_DIR"/*.tgz

# install-pkdiff.sh installs from the lockfile, without install scripts, from
# the npm registry, into a new directory: a file left there doesn't survive.
PKDIFF_DIR="$WORK/pkdiff"
run_install() {
  : >"$WORK/shim.log"
  set +e
  LOG="$(env PATH="$SHIMS:$PATH" SHIM_LOG="$WORK/shim.log" ACTION_PATH="$ACTION_DIR" PKDIFF_DIR="$PKDIFF_DIR" \
    "$@" "$SCRIPTS/install-pkdiff.sh" 2>&1)"
  STATUS=$?
  set -e
}

# Without diff2html under node_modules/pkdiff, as after an install with
# another layout or one that did nothing, install-pkdiff.sh fails.
run_install SHIM_NO_DIFF2HTML=1
check "install-pkdiff.sh fails if diff2html isn't nested under pkdiff" \
  bash -c "(($STATUS != 0)) && grep -q \"^::error::npm ci did not install pkdiff's diff2html\" <<<\"\$1\"" _ "$LOG"

mkdir -p "$PKDIFF_DIR"
echo "registry=https://example.invalid/" >"$PKDIFF_DIR/.npmrc"
run_install
pkdiff_installed() {
  ((STATUS == 0)) &&
    [[ "$(cat "$WORK/shim.log")" == 'npm ci --ignore-scripts --no-audit --no-fund --install-strategy=shallow --registry https://registry.npmjs.org [files=package-lock.json package.json ]' ]] &&
    test -x "$PKDIFF_DIR/node_modules/.bin/pkdiff"
}
check "install-pkdiff.sh runs npm ci with --ignore-scripts, --install-strategy=shallow and --registry in a new directory" pkdiff_installed

# pkdiff's lockfile pins every package to a registry.npmjs.org tarball. It
# nests pkdiff's dependencies under node_modules/pkdiff, as a global install
# does (npm install --install-strategy=shallow): pkdiff reads diff2html's files
# from its own node_modules, and install-pkdiff.sh runs `npm ci` with
# --install-strategy=shallow, which keeps the lockfile's layout.
# On failure, the log lists the packages that aren't pinned to the registry.
LOG="$(jq --raw-output '
  .packages | to_entries[] | select(.key != "") |
  select((.value.resolved // "" | startswith("https://registry.npmjs.org/") | not) or
    (.value.integrity // "" | startswith("sha512-") | not)) |
  "not pinned: \(.key)"
' "$ACTION_DIR/pkdiff/package-lock.json")"
lockfile_pinned() {
  jq --exit-status '
    .lockfileVersion == 3 and
    .packages["node_modules/pkdiff/node_modules/diff2html"] != null and
    ([.packages | to_entries[] | select(.key != "") | .value] as $deps |
      ($deps | length) > 0 and
      all($deps[]; (.resolved // "" | startswith("https://registry.npmjs.org/")) and (.integrity // "" | startswith("sha512-"))))
  ' "$ACTION_DIR/pkdiff/package-lock.json" >/dev/null
}
check "pkdiff's lockfile is version 3, nests diff2html and resolves every package to https://registry.npmjs.org/" lockfile_pinned

# pkdiff's minimist is overridden from 0.2.1 to 0.2.4, which fixes a
# prototype-pollution advisory (GHSA-xvch-5gv4-984h).
LOG="$(jq --compact-output '.packages | with_entries(select(.key | endswith("/minimist")))' "$ACTION_DIR/pkdiff/package-lock.json")"
minimist_overridden() {
  jq --exit-status '.packages["node_modules/pkdiff/node_modules/minimist"].version == "0.2.4"' \
    "$ACTION_DIR/pkdiff/package-lock.json" >/dev/null
}
check "pkdiff's lockfile overrides pkdiff's minimist to 0.2.4" minimist_overridden

# report.sh runs the installed pkdiff, not one on PATH, and pins its download
# of <name>@latest to the npm registry.
cat >"$SHIMS/pkdiff" <<'EOF'
#!/usr/bin/env bash
echo "pkdiff from PATH" >>"$SHIM_LOG"
EOF
chmod +x "$SHIMS/pkdiff"
mkdir -p "$WORK/report/package"
echo '{"name": "@test/npm-publish-modes", "version": "1.2.3"}' >"$WORK/report/package/package.json"
tar -czf "$TARBALL" -C "$WORK/report" package
run_report() {
  : >"$WORK/shim.log"
  set +e
  LOG="$(PATH="$SHIMS:$PATH" SHIM_LOG="$WORK/shim.log" PACK_DIR="$PACK_DIR" PKDIFF_DIR="$1" \
    "$SCRIPTS/report.sh" 2>&1)"
  STATUS=$?
  set -e
}

# Without an installed pkdiff, report.sh fails rather than ignoring it.
mkdir -p "$WORK/no-pkdiff"
run_report "$WORK/no-pkdiff"
check "report.sh fails if pkdiff isn't installed" \
  bash -c "(($STATUS != 0)) && grep -q '^::error::.*/node_modules/.bin/pkdiff is not executable' <<<\"\$1\" && [[ ! -s '$WORK/shim.log' ]]" _ "$LOG"

run_report "$PKDIFF_DIR"
pkdiff_pinned() {
  ((STATUS == 0)) && [[ "$(wc -l <"$WORK/shim.log")" -eq 1 ]] &&
    grep -q '^pkdiff .* --registry https://registry\.npmjs\.org .*-- ' "$WORK/shim.log"
}
check "report.sh runs the installed pkdiff with --registry https://registry.npmjs.org" pkdiff_pinned

rm -f "$TARBALL" "$PACK_DIR"/*.tgz
if ((failures > 0)); then
  echo "$failures failure(s)"
  exit 1
fi
echo "All tests passed."
