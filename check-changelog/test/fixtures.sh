#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Runs scripts/check-changelog.ts against fixture git repositories and asserts
# that each passes or fails. Requires the action's dependencies to be
# installed (npm ci in check-changelog/).
#
# Usage: test/fixtures.sh

set -euo pipefail

ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ACTION_DIR/scripts/check-changelog.ts"
PR=42
WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-changelog-test.XXXXXX")"
FAILURES="$WORK/failures"
: >"$FAILURES"

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

BASE_BRANCH=main

# Content of files outside the fixture repositories, which the output must
# never show. Short enough to fit in the snippet of a JSON parse error.
SECRET="LEAK-6f1d"

# changelog <unreleased entries> [<version> <entries>]...
changelog() {
  local unreleased="$1"
  shift
  printf '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n'
  printf 'The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),\n'
  printf 'and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n\n'
  printf '## [Unreleased]\n\n'
  if [[ -n "$unreleased" ]]; then
    printf '### Added\n\n%s\n\n' "$unreleased"
  fi
  while (($# >= 2)); do
    printf '## [%s]\n\n### Changed\n\n%s\n\n' "$1" "$2"
    shift 2
  done
  printf '## [1.0.0]\n\n### Added\n\n- Initial release ([#1](https://github.com/o/r/pull/1))\n\n'
  printf '[Unreleased]: https://github.com/o/r/compare/v1.0.0...HEAD\n'
  printf '[1.0.0]: https://github.com/o/r/releases/tag/v1.0.0\n'
}

# package_json <name> <version> <private> [<dependency range>] [<devDependency range>]
package_json() {
  local name="$1" version="$2" private="$3" dep="${4:-^1.0.0}" dev_dep="${5:-^1.0.0}"
  jq -n --arg name "$name" --arg version "$version" --argjson private "$private" \
    --arg dep "$dep" --arg devDep "$dev_dep" '
    {name: $name, version: $version}
    + (if $private then {private: true} else {} end)
    + {
        scripts: {build: "tsc"},
        dependencies: {"some-dep": $dep},
        devDependencies: {"some-dev-dep": $devDep}
      }'
}

# Pushes HEAD to the fixture's bare origin as the base branch.
publish_base() {
  git push -q origin "HEAD:refs/heads/$BASE_BRANCH"
}

new_repo() {
  local dir="$1"
  git init -q --bare "$dir.origin.git"
  git init -q "$dir"
  cd "$dir"
  git checkout -q -b "$BASE_BRANCH"
  git remote add origin "$dir.origin.git"
}

# Creates <dir>: a monorepo committed on the base branch, pushed to a bare
# origin, with a feature branch checked out.
monorepo() {
  new_repo "$1"
  jq -n '{name: "root", version: "1.0.0", private: true, workspaces: ["packages/*"]}' >package.json
  for pkg in pub other; do
    mkdir -p "packages/$pkg/src"
    package_json "$pkg" 1.0.0 false >"packages/$pkg/package.json"
    changelog "" >"packages/$pkg/CHANGELOG.md"
    echo "export const x = 1;" >"packages/$pkg/src/index.ts"
  done
  mkdir -p packages/priv/src .github/workflows
  package_json priv 1.0.0 true >packages/priv/package.json
  echo "export const x = 1;" >packages/priv/src/index.ts
  echo "name: ci" >.github/workflows/ci.yml
  git add -A
  git commit -q -m base
  publish_base
  git checkout -q -b feature
}

# Creates <dir>: a single-package repository (no workspaces).
single_repo() {
  new_repo "$1"
  package_json single 1.0.0 false >package.json
  changelog "" >CHANGELOG.md
  git add -A
  git commit -q -m base
  publish_base
  git checkout -q -b feature
}

commit() {
  git add -A
  git commit -q -m change
}

# Prints each output line the runner would take as a workflow command, other
# than the script's own: everything outside a ::stop-commands:: region except
# its markers and the fetch-failure warning. Also complains if the output does
# not start by stopping commands or does not end with them resumed. The runner
# splits lines on \r as well as \n and ignores leading whitespace.
stray_commands() {
  local line token="" first=true
  tr '\r' '\n' | {
    while IFS= read -r line; do
      line="${line#"${line%%[![:space:]]*}"}"
      if [[ "$first" == true && "$line" != ::stop-commands::* ]]; then
        echo "(output does not start with ::stop-commands::)"
      fi
      first=false
      if [[ -n "$token" ]]; then
        if [[ "$line" == "::$token::" ]]; then
          token=""
        fi
      elif [[ "$line" == ::stop-commands::* ]]; then
        token="${line#::stop-commands::}"
      elif [[ "$line" == ::* && "$line" != "::warning::Could not fetch "* ]]; then
        echo "$line"
      fi
    done
    if [[ -n "$token" ]]; then
      echo "(commands not resumed)"
    fi
  }
}

# expect <pass|fail> <name> [<string the output must contain>...]
#
# Also fails if stray_commands finds anything, or if the output shows $SECRET.
expect() {
  local expected="$1" name="$2"
  shift 2
  local output status actual=pass ok=true
  set +e
  output="$(node "$SCRIPT" . "$BASE_BRANCH" "$PR" 2>&1)"
  status=$?
  set -e
  if ((status != 0)); then
    actual=fail
  fi
  [[ "$actual" == "$expected" ]] || ok=false
  for pattern in "$@"; do
    grep -qF -- "$pattern" <<<"$output" || ok=false
  done
  if grep -qF -- "$SECRET" <<<"$output"; then
    echo "    output shows $SECRET"
    ok=false
  fi
  local stray
  stray="$(stray_commands <<<"$output")"
  if [[ -n "$stray" ]]; then
    echo "    stray workflow commands: $stray"
    ok=false
  fi
  if [[ "$ok" == true ]]; then
    echo "ok - $name ($actual)"
  else
    echo "not ok - $name: expected $expected, got $actual; required output: $*"
    while IFS= read -r line; do echo "    $line"; done <<<"$output"
    echo "$name" >>"$FAILURES"
  fi
}

entry="- Add a thing ([#$PR](https://github.com/o/r/pull/$PR))"
other_entry="- Add another thing ([#7](https://github.com/o/r/pull/7))"

case_code_with_entry() {
  monorepo "$WORK/code-with-entry"
  echo "export const y = 2;" >>packages/pub/src/index.ts
  changelog "$entry" >packages/pub/CHANGELOG.md
  commit
  expect pass "code change with Unreleased entry"
}

case_code_without_entry() {
  monorepo "$WORK/code-without-entry"
  echo "export const y = 2;" >>packages/pub/src/index.ts
  changelog "$other_entry" >packages/pub/CHANGELOG.md
  commit
  expect fail "code change without entry" \
    "Changelog check failed for package packages/pub" "packages/pub/CHANGELOG.md" '"Unreleased" section' "no-changelog"
}

# git quotes non-ASCII paths unless core.quotePath is off.
case_non_ascii_path_without_entry() {
  monorepo "$WORK/non-ascii-path"
  echo "export const z = 3;" >"packages/pub/src/naïve.ts"
  commit
  expect fail "non-ASCII path without entry" "Changelog check failed for package packages/pub"
}

case_private_only() {
  monorepo "$WORK/private-only"
  echo "export const y = 2;" >>packages/priv/src/index.ts
  commit
  expect pass "change only in a private package"
}

case_tests_and_docs_only() {
  monorepo "$WORK/tests-only"
  echo "test" >packages/pub/src/index.test.ts
  echo "test" >packages/pub/src/index.spec.ts
  mkdir -p packages/pub/src/__tests__ packages/pub/docs
  echo "test" >packages/pub/src/__tests__/a.ts
  echo "docs" >packages/pub/docs/a.md
  commit
  expect pass "change only in tests and docs"
}

case_changelog_only() {
  monorepo "$WORK/changelog-only"
  changelog "$other_entry" >packages/pub/CHANGELOG.md
  commit
  expect pass "change only in CHANGELOG.md"
}

case_deleted_package() {
  monorepo "$WORK/deleted-package"
  git rm -rq packages/other
  commit
  expect pass "public package deleted" "Skipping packages/other: its package.json was deleted"
}

# Only <root>/* patterns are supported: with packages/*/*, a file maps to
# packages/group, which has no package.json, so the check fails rather than
# skipping it.
case_nested_workspace_pattern() {
  new_repo "$WORK/nested-workspace-pattern"
  jq -n '{name: "root", version: "1.0.0", private: true, workspaces: ["packages/*/*"]}' >package.json
  mkdir -p packages/group/foo/src
  package_json foo 1.0.0 false >packages/group/foo/package.json
  changelog "" >packages/group/foo/CHANGELOG.md
  echo "export const x = 1;" >packages/group/foo/src/index.ts
  commit
  publish_base
  git checkout -q -b feature
  echo "export const y = 2;" >>packages/group/foo/src/index.ts
  changelog "$entry" >packages/group/foo/CHANGELOG.md
  commit
  expect fail "packages/*/* workspace pattern" \
    "maps to packages/group, which has no package.json" "Only workspace patterns of the form <root>/* are supported"
}

case_workflows_only() {
  monorepo "$WORK/workflows-only"
  echo "name: ci2" >.github/workflows/ci.yml
  commit
  expect pass "change only in .github/workflows/"
}

case_version_only() {
  monorepo "$WORK/version-only"
  package_json pub 1.1.0 false >packages/pub/package.json
  commit
  expect pass "package.json version bump only" "only contains version changes"
}

# Only the package's own package.json gets the package.json analysis: a
# version-only change to any other JSON file is a code change.
# other_json_version_only <dir> <file>
other_json_version_only() {
  monorepo "$1"
  mkdir -p "$(dirname "$2")"
  jq -n '{version: "1.0.0"}' >"$2"
  commit
  publish_base
  jq -n '{version: "1.1.0"}' >"$2"
  commit
  expect fail "version change in $2" "Changelog check failed for package packages/pub"
}

case_suffix_package_json_version_only() {
  other_json_version_only "$WORK/suffix-package-json" packages/pub/schema-package.json
}

case_nested_package_json_version_only() {
  other_json_version_only "$WORK/nested-package-json" packages/pub/src/fixture/package.json
}

case_dev_deps_only() {
  monorepo "$WORK/dev-deps-only"
  package_json pub 1.0.0 false ^1.0.0 ^2.0.0 >packages/pub/package.json
  commit
  expect pass "package.json devDependencies only" "only contains dev dependency changes"
}

case_version_and_dev_deps() {
  monorepo "$WORK/version-and-dev-deps"
  package_json pub 1.1.0 false ^1.0.0 ^2.0.0 >packages/pub/package.json
  commit
  expect pass "package.json version bump and devDependencies" \
    "only contains version and dev dependency changes"
}

case_downgrade() {
  monorepo "$WORK/downgrade"
  package_json pub 1.1.0 false >packages/pub/package.json
  commit
  publish_base
  package_json pub 1.0.0 false ^2.0.0 >packages/pub/package.json
  commit
  expect pass "package.json version downgrade" "version downgrade (revert)"
}

case_version_and_deps_entry_in_version_section() {
  monorepo "$WORK/version-and-deps-ok"
  package_json pub 1.1.0 false ^2.0.0 >packages/pub/package.json
  # Unreleased does not link the PR; the 1.1.0 section does.
  changelog "" 1.1.0 "$entry" >packages/pub/CHANGELOG.md
  commit
  expect pass "version bump and dependencies change, entry under the new version"
}

case_version_and_deps_entry_in_unreleased_only() {
  monorepo "$WORK/version-and-deps-unreleased"
  package_json pub 1.1.0 false ^2.0.0 >packages/pub/package.json
  changelog "$entry" >packages/pub/CHANGELOG.md
  commit
  expect fail "version bump and dependencies change, entry under Unreleased only" \
    "Could not find section for version '1.1.0'"
}

case_version_and_deps_version_section_without_entry() {
  monorepo "$WORK/version-and-deps-no-entry"
  package_json pub 1.1.0 false ^2.0.0 >packages/pub/package.json
  changelog "$entry" 1.1.0 "$other_entry" >packages/pub/CHANGELOG.md
  commit
  expect fail "version bump and dependencies change, new version section without entry" \
    '"1.1.0" section'
}

case_invalid_version_and_deps() {
  monorepo "$WORK/invalid-version-and-deps"
  package_json pub 1.1 false ^2.0.0 >packages/pub/package.json
  changelog "$entry" >packages/pub/CHANGELOG.md
  commit
  expect fail "version bump to invalid semver and dependencies change" \
    "The new version '1.1' in packages/pub/package.json is not valid semver" "no-changelog"
}

case_two_packages_one_missing() {
  monorepo "$WORK/two-packages-one-missing"
  echo "export const y = 2;" >>packages/pub/src/index.ts
  echo "export const y = 2;" >>packages/other/src/index.ts
  changelog "$entry" >packages/pub/CHANGELOG.md
  commit
  expect fail "two packages, one missing its entry" \
    "CHANGELOG.md for packages/pub has been correctly updated." \
    "Changelog check failed for package packages/other" \
    "One or more changelog checks failed"
}

case_two_packages_both_missing() {
  monorepo "$WORK/two-packages-both-missing"
  echo "export const y = 2;" >>packages/pub/src/index.ts
  echo "export const y = 2;" >>packages/other/src/index.ts
  commit
  expect fail "two packages, both missing entries" \
    "Changelog check failed for package packages/pub" \
    "Changelog check failed for package packages/other"
}

# Adds a second workspace root, libs/*, with a package also named pub, and
# publishes it as the new base. libs/ sorts before packages/, so its files are
# seen first.
add_libs_root() {
  jq '.workspaces += ["libs/*"]' package.json >package.json.tmp
  mv package.json.tmp package.json
  mkdir -p libs/pub/src
  package_json libs-pub 1.0.0 "$1" >libs/pub/package.json
  changelog "" >libs/pub/CHANGELOG.md
  echo "export const x = 1;" >libs/pub/src/index.ts
  commit
  publish_base
}

case_same_directory_name_in_two_roots() {
  monorepo "$WORK/same-dir-name"
  add_libs_root false
  echo "export const y = 2;" >>libs/pub/src/index.ts
  echo "export const y = 2;" >>packages/pub/src/index.ts
  changelog "$entry" >packages/pub/CHANGELOG.md
  commit
  expect fail "same directory name in two workspace roots, one missing its entry" \
    "Changelog check failed for package libs/pub" \
    "CHANGELOG.md for packages/pub has been correctly updated."
}

case_same_directory_name_private_in_other_root() {
  monorepo "$WORK/same-dir-name-private"
  add_libs_root true
  echo "export const y = 2;" >>libs/pub/src/index.ts
  echo "export const y = 2;" >>packages/pub/src/index.ts
  commit
  expect fail "public package named like a private one in another root" \
    "Changelog check failed for package packages/pub"
}

case_stale_base() {
  monorepo "$WORK/stale-base"
  echo "export const y = 2;" >>packages/pub/src/index.ts
  changelog "$entry" >packages/pub/CHANGELOG.md
  commit
  # The base branch moves on with a change to another package; the merge-base
  # comparison must not attribute it to this branch.
  git checkout -q "$BASE_BRANCH"
  echo "export const z = 3;" >>packages/other/src/index.ts
  commit
  publish_base
  git checkout -q feature
  expect pass "base branch moved on after branching"
}

# Text from the pull request can contain \r, which starts a new line for the
# runner. Here a changelog line, a version and a file path carry
# \r::warning::injected; the output must show the text, but only where the
# runner does not process commands.
injected=$'\r::warning::injected'

case_injected_changelog_line() {
  monorepo "$WORK/injected-changelog-line"
  echo "export const y = 2;" >>packages/pub/src/index.ts
  changelog "$entry" | sed "s/^### Added\$/### Added$injected/" >packages/pub/CHANGELOG.md
  commit
  expect fail "changelog line with \\r::warning::" "Malformed category header" "::warning::injected"
}

case_injected_version() {
  monorepo "$WORK/injected-version"
  local json
  json="$(package_json pub 1.1.0 false ^2.0.0)"
  printf '%s\n' "${json/1.1.0/1.1$injected}" >packages/pub/package.json
  changelog "$entry" >packages/pub/CHANGELOG.md
  commit
  expect fail "version with \\r::warning::" "is not valid semver" "::warning::injected"
}

case_injected_file_path() {
  monorepo "$WORK/injected-file-path"
  echo "export const y = 2;" >"packages/pub/src/a${injected}.ts"
  echo "export const y = 2;" >>packages/pub/src/index.ts
  commit
  expect fail "file path with \\r::warning::" "Changelog check failed for package packages/pub"
}

# git C-quotes a path with control characters unless the list is
# NUL-separated, and a quoted path maps to no package.
case_control_character_path_without_entry() {
  monorepo "$WORK/control-character-path"
  echo "export const y = 2;" >"packages/pub/src/a"$'\r'"b.ts"
  commit
  expect fail "path with \\r, without entry" "Changelog check failed for package packages/pub"
}

# The script's own warning is emitted with commands resumed, and git's
# multi-line error in it is escaped onto one line.
case_fetch_fails() {
  monorepo "$WORK/fetch-fails"
  echo "export const y = 2;" >>packages/pub/src/index.ts
  changelog "$entry" >packages/pub/CHANGELOG.md
  commit
  git remote set-url origin "$WORK/does-not-exist.git"
  expect pass "base branch fetch fails" "::warning::Could not fetch main; using origin/main" "%0A"
}

# The pull request controls the checkout, so a file the script reads can be a
# symbolic link to any file on the runner. The script must refuse it rather
# than show the target's contents in an error.
# secret_file <name> <contents>: creates $WORK/<name> and prints its path.
secret_file() {
  printf '%s\n' "$2" >"$WORK/$1"
  echo "$WORK/$1"
}

case_symlinked_root_package_json() {
  single_repo "$WORK/symlinked-root-package-json"
  ln -sf "$(secret_file root-package.json "$SECRET is not JSON")" package.json
  changelog "$entry" >CHANGELOG.md
  commit
  expect fail "root package.json is a symbolic link" "package.json is a symbolic link"
}

case_symlinked_package_json() {
  monorepo "$WORK/symlinked-package-json"
  ln -sf "$(secret_file package.json "$SECRET is not JSON")" packages/pub/package.json
  echo "export const y = 2;" >>packages/pub/src/index.ts
  commit
  expect fail "package package.json is a symbolic link" \
    "packages/pub/package.json is a symbolic link" "Changelog check failed for package packages/pub"
}

case_symlinked_changelog() {
  monorepo "$WORK/symlinked-changelog"
  ln -sf "$(secret_file CHANGELOG.md "$(changelog "$entry" | sed "s/^### Added\$/### $SECRET/")")" \
    packages/pub/CHANGELOG.md
  echo "export const y = 2;" >>packages/pub/src/index.ts
  commit
  expect fail "package CHANGELOG.md is a symbolic link" \
    "packages/pub/CHANGELOG.md is a symbolic link"
}

# A link to a file inside the repository is refused too.
case_symlinked_changelog_in_repo() {
  monorepo "$WORK/symlinked-changelog-in-repo"
  changelog "$entry" >packages/other/CHANGELOG.md
  ln -sf ../other/CHANGELOG.md packages/pub/CHANGELOG.md
  echo "export const y = 2;" >>packages/pub/src/index.ts
  commit
  expect fail "package CHANGELOG.md links to another in the repository" \
    "packages/pub/CHANGELOG.md is a symbolic link"
}

case_single_repo_with_entry() {
  single_repo "$WORK/single-with-entry"
  echo "x" >index.js
  changelog "$entry" >CHANGELOG.md
  commit
  expect pass "single repo with Unreleased entry" "single-repo mode"
}

case_single_repo_without_entry() {
  single_repo "$WORK/single-without-entry"
  echo "x" >index.js
  commit
  expect fail "single repo without entry" '"Unreleased" section'
}

# Not `if ! (...)`: bash ignores set -e inside a condition, so a failed
# setup step would go unnoticed.
for case_fn in $(declare -F | awk '{print $3}' | grep '^case_'); do
  set +e
  (
    set -e
    cd "$WORK"
    "$case_fn"
  )
  status=$?
  set -e
  if ((status != 0)); then
    echo "not ok - $case_fn: fixture setup failed"
    echo "$case_fn" >>"$FAILURES"
  fi
done

count="$(wc -l <"$FAILURES" | tr -d ' ')"
if ((count > 0)); then
  echo "$count failure(s):"
  cat "$FAILURES"
  exit 1
fi
echo "All fixture tests passed."
