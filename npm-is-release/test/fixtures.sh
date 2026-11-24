#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Runs scripts/is-release.sh against fixture repositories. Each fixture has a
# local bare origin, and the script runs in a clone with --depth 2, as
# actions/checkout with fetch-depth: 2 leaves it.
#
# Usage: test/fixtures.sh
#
# With --prepare-workspace <dir>, instead builds one fixture (a release commit
# whose version changed two commits back) cloned into <dir>, and prints
# "before=<sha>", for the action-level test.

set -euo pipefail

ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ACTION_DIR/scripts/is-release.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/npm-is-release-test.XXXXXX")"
FAILURES="$WORK/failures"
: >"$FAILURES"

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# Command-scoped config from the caller's environment would show up in the
# token tests.
unset GIT_CONFIG_COUNT

# shellcheck disable=SC2016 # Literal backticks.
OCAP_PREFIXES='Release [version],Release v[version],Release/[version],Release/v[version],Release `[version]`'

# Builds a repository at $WORK/<name>.src with an origin at $WORK/<name>.git.
# Arguments after the name are commits, each "<version>|<subject>".
# Prints the SHA of each commit, one per line, oldest first. OBJECT_FORMAT
# (default sha1) sets the repositories' hash algorithm.
build() {
  local name="$1"
  shift
  local src="$WORK/$name.src" origin="$WORK/$name.git" i=0
  git init -q --bare --object-format="${OBJECT_FORMAT:-sha1}" "$origin"
  git init -q --object-format="${OBJECT_FORMAT:-sha1}" "$src"
  for spec in "$@"; do
    local version="${spec%%|*}" subject="${spec#*|}"
    i=$((i + 1))
    jq -n --arg version "$version" '{name: "root", version: $version, private: true}' >"$src/package.json"
    echo "$i" >"$src/file.txt"
    git -C "$src" add -A
    git -C "$src" commit -q -m "$subject"
    git -C "$src" rev-parse HEAD
  done
  git -C "$src" push -q "$origin" HEAD:refs/heads/trunk
}

# Clones <name>'s origin with --depth 2 into $WORK/<name>.
clone() {
  local name="$1"
  git clone -q --depth 2 --branch trunk "file://$WORK/$name.git" "$WORK/$name"
}

# expect <true|false|error> <test name> <fixture> [VAR=value...]
expect() {
  local expected="$1" test_name="$2" name="$3"
  shift 3
  local output_file="$WORK/$name.out" log status actual
  : >"$output_file"
  set +e
  log="$(cd "$WORK/$name" && env GITHUB_OUTPUT="$output_file" COMMIT_STARTS_WITH= COMMIT_MESSAGE= GITHUB_TOKEN= GITHUB_SERVER_URL= \
    RUNNER_DEBUG= "$@" "$SCRIPT" 2>&1)"
  status=$?
  set -e
  if ((status != 0)); then
    actual=error
  else
    actual="$(sed -n 's/^IS_RELEASE=//p' "$output_file")"
  fi
  if [[ "$actual" == "$expected" ]]; then
    echo "ok - $test_name ($actual)"
  else
    echo "not ok - $test_name: expected $expected, got $actual"
    while IFS= read -r line; do echo "    $line"; done <<<"$log"
    echo "$test_name" >>"$FAILURES"
  fi
}

# Runs build, then reads the SHAs it printed into the shas array. Not
# `mapfile < <(build ...)`: set -e doesn't see a failure in a process
# substitution.
build_shas() {
  build "$@" >"$WORK/shas"
  mapfile -t shas <"$WORK/shas"
}

if [[ "${1:-}" == "--prepare-workspace" ]]; then
  dir="$2"
  build_shas workspace '1.1.0|Initial' '1.2.0|Bump version' '1.2.0|Release 1.2.0 (#5)'
  git clone -q --depth 2 --branch trunk "file://$WORK/workspace.git" "$dir"
  echo "before=${shas[0]}"
  exit 0
fi

# Kept with --prepare-workspace above: the clone's origin is in $WORK.
trap 'rm -rf -- "$WORK"' EXIT

build_shas unchanged '1.1.0|Initial' '1.1.0|Release 1.1.0 (#5)'
clone unchanged
expect false "version unchanged" unchanged BEFORE="${shas[0]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES"

i=0
# shellcheck disable=SC2016 # Literal backticks.
for subject in 'Release 1.2.0 (#5)' 'Release v1.2.0 (#5)' 'Release/1.2.0' 'Release/v1.2.0' 'Release `1.2.0`'; do
  i=$((i + 1))
  build_shas "subject-$i" '1.1.0|Initial' "1.2.0|$subject"
  clone "subject-$i"
  expect true "subject: $subject" "subject-$i" BEFORE="${shas[0]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES"
done

build_shas chore '1.1.0|Initial' '1.2.0|chore: bump'
clone chore
expect false "version changed, subject chore: bump" chore BEFORE="${shas[0]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES"

# Upstream matched the prefix as a regex, so "." matched any character.
build_shas regex '1.1.0|Initial' '1.2.0|Release 1x2y0'
clone regex
expect false "version changed, subject Release 1x2y0 (literal match)" regex BEFORE="${shas[0]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES"

build_shas regex-chars '1.1.0|Initial' '1.2.0|Release (1.2.0)'
clone regex-chars
expect true "prefix with regex metacharacters" regex-chars BEFORE="${shas[0]}" COMMIT_STARTS_WITH='Release ([version])'

build_shas spaced '1.1.0|Initial' '1.2.0|Release v1.2.0'
clone spaced
expect true "prefixes with spaces after the commas" spaced BEFORE="${shas[0]}" COMMIT_STARTS_WITH='Release [version], Release v[version]'
expect true "prefixes on separate lines" spaced BEFORE="${shas[0]}" COMMIT_STARTS_WITH=$'Release [version]\nRelease v[version]\n'
expect false "an empty prefix matches nothing" spaced BEFORE="${shas[0]}" COMMIT_STARTS_WITH='chore,, ,'

build_shas no-prefix '1.1.0|Initial' '1.2.0|chore: bump'
clone no-prefix
expect true "version changed, no commit-starts-with" no-prefix BEFORE="${shas[0]}"

build_shas message '1.1.0|Initial' '1.2.0|chore: bump'
clone message
expect true "commit-message overrides the HEAD subject" message BEFORE="${shas[0]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES" COMMIT_MESSAGE='Release 1.2.0'
expect false "commit-message that does not match" message BEFORE="${shas[0]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES" COMMIT_MESSAGE='chore: bump'

# Version changed in the first of two pushed commits; HEAD^ has the new version.
# BEFORE is outside the depth-2 clone, so the script must fetch it.
build_shas multi '1.1.0|Initial' '1.2.0|Bump version' '1.2.0|Release 1.2.0 (#5)'
clone multi
expect true "multi-commit push compares with BEFORE, not HEAD^" multi BEFORE="${shas[0]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES"
expect false "single-commit comparison with HEAD^" multi BEFORE="${shas[1]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES"

# With a token, the fetch gets it as an Authorization header through
# GIT_CONFIG_* (a file:// origin ignores the header, so a git shim records the
# config entries it was given).
mkdir -p "$WORK/shims"
cat >"$WORK/shims/git" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == fetch ]]; then
  {
    echo "count=\${GIT_CONFIG_COUNT:-}"
    for ((i = 0; i < \${GIT_CONFIG_COUNT:-0}; i++)); do
      key="GIT_CONFIG_KEY_\$i" value="GIT_CONFIG_VALUE_\$i"
      echo "\$i: \${!key}=\${!value}"
    done
  } >>"$WORK/git-fetch.log"
fi
exec "$(command -v git)" "\$@"
EOF
chmod +x "$WORK/shims/git"
TOKEN_HEADER="AUTHORIZATION: basic $(printf 'x-access-token:secret' | base64 | tr -d '\n')"
TOKEN_KEY="http.https://github.example/.extraheader"

# check_fetch_log <name> <expected log>
check_fetch_log() {
  if [[ "$(cat "$WORK/git-fetch.log")" == "$2" ]]; then
    echo "ok - $1"
  else
    echo "not ok - $1: got"
    sed 's/^/    /' "$WORK/git-fetch.log"
    echo "$1" >>"$FAILURES"
  fi
}

build_shas token '1.1.0|Initial' '1.2.0|Bump version' '1.2.0|Release 1.2.0 (#5)'
clone token
: >"$WORK/git-fetch.log"
expect true "multi-commit push with a token" token BEFORE="${shas[0]}" COMMIT_STARTS_WITH="$OCAP_PREFIXES" \
  GITHUB_TOKEN=secret GITHUB_SERVER_URL=https://github.example PATH="$WORK/shims:$PATH"
check_fetch_log "the token is passed to the fetch, after a reset of the same key" \
  "count=2
0: $TOKEN_KEY=
1: $TOKEN_KEY=$TOKEN_HEADER"

build_shas token2 '1.1.0|Initial' '1.2.0|Bump version' '1.2.0|Release 1.2.0 (#5)'
clone token2
: >"$WORK/git-fetch.log"
expect true "multi-commit push with a token and existing GIT_CONFIG_* entries" token2 BEFORE="${shas[0]}" \
  GITHUB_TOKEN=secret GITHUB_SERVER_URL=https://github.example PATH="$WORK/shims:$PATH" \
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.example GIT_CONFIG_VALUE_0=kept
check_fetch_log "existing GIT_CONFIG_* entries are kept" \
  "count=3
0: core.example=kept
1: $TOKEN_KEY=
2: $TOKEN_KEY=$TOKEN_HEADER"

# Under RUNNER_DEBUG the script traces commands, but not the credential.
build_shas token3 '1.1.0|Initial' '1.2.0|Bump version' '1.2.0|Release 1.2.0 (#5)'
clone token3
trace="$(cd "$WORK/token3" && env GITHUB_OUTPUT="$WORK/token3.out" COMMIT_STARTS_WITH= COMMIT_MESSAGE= \
  RUNNER_DEBUG=1 GITHUB_TOKEN=secret BEFORE="${shas[0]}" "$SCRIPT" 2>&1)"
encoded="$(printf 'x-access-token:secret' | base64 | tr -d '\n')"
if grep -q '^+ ' <<<"$trace" && ! grep '^+' <<<"$trace" | grep -qE "secret|$encoded"; then
  echo "ok - the debug trace leaves out the token"
else
  echo "not ok - the debug trace leaves out the token:"
  while IFS= read -r line; do echo "    $line"; done <<<"$trace"
  echo "debug trace" >>"$FAILURES"
fi

expect error "empty BEFORE" multi BEFORE=
# A push that creates a branch has an all-zero before SHA. Documented limitation.
expect error "all-zero BEFORE (new branch)" multi BEFORE=0000000000000000000000000000000000000000

# BEFORE must be a full SHA. A value starting with "-" would otherwise reach
# git fetch as an option: --upload-pack runs a command on a local origin.
expect error "BEFORE that is a git option" multi BEFORE="--upload-pack=touch $WORK/pwned;git-upload-pack"
if [[ -e "$WORK/pwned" ]]; then
  echo "not ok - BEFORE that is a git option does not run a command"
  echo "BEFORE option ran a command" >>"$FAILURES"
else
  echo "ok - BEFORE that is a git option does not run a command"
fi
build_shas before-format '1.1.0|Initial' '1.2.0|Release 1.2.0 (#5)'
clone before-format
expect error "abbreviated BEFORE" before-format BEFORE="${shas[0]:0:12}"
expect error "BEFORE that is a ref" before-format BEFORE=HEAD^
expect true "upper-case BEFORE" before-format BEFORE="$(tr a-f A-F <<<"${shas[0]}")"

OBJECT_FORMAT=sha256 build_shas sha256 '1.1.0|Initial' '1.2.0|Bump version' '1.2.0|Release 1.2.0 (#5)'
clone sha256
expect true "SHA-256 repository (64-character BEFORE)" sha256 BEFORE="${shas[0]}"

count="$(wc -l <"$FAILURES" | tr -d ' ')"
if ((count > 0)); then
  echo "$count failure(s):"
  cat "$FAILURES"
  exit 1
fi
echo "All fixture tests passed."
