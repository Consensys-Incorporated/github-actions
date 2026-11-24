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

# shellcheck disable=SC2016 # Literal backticks.
OCAP_PREFIXES='Release [version],Release v[version],Release/[version],Release/v[version],Release `[version]`'

# Builds a repository at $WORK/<name>.src with an origin at $WORK/<name>.git.
# Arguments after the name are commits, each "<version>|<subject>".
# Prints the SHA of each commit, one per line, oldest first.
build() {
  local name="$1"
  shift
  local src="$WORK/$name.src" origin="$WORK/$name.git" i=0
  git init -q --bare "$origin"
  git init -q "$src"
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
  log="$(cd "$WORK/$name" && env GITHUB_OUTPUT="$output_file" COMMIT_STARTS_WITH= COMMIT_MESSAGE= "$@" "$SCRIPT" 2>&1)"
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

expect error "empty BEFORE" multi BEFORE=
# A push that creates a branch has an all-zero before SHA. Documented limitation.
expect error "all-zero BEFORE (new branch)" multi BEFORE=0000000000000000000000000000000000000000

count="$(wc -l <"$FAILURES" | tr -d ' ')"
if ((count > 0)); then
  echo "$count failure(s):"
  cat "$FAILURES"
  exit 1
fi
echo "All fixture tests passed."
