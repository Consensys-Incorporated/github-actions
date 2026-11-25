#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Tests for the npm-publish-release scripts, against fixture repositories with
# `gh` and `git push` replaced by shims that record their arguments.
#
# Usage:
#   test/fixtures.sh                          run all tests
#   test/fixtures.sh --prepare-workspace DIR  build the monorepo fixture in DIR
#                                             and install the shims in DIR.shims
#                                             (for the action-level test)

set -euo pipefail

ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ACTION_DIR/scripts"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/npm-publish-release-test.XXXXXX")"
FAILURES="$WORK/failures"
: >"$FAILURES"

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GITHUB_REPOSITORY=octo/repo

# shellcheck source=SCRIPTDIR/../scripts/lib.sh
source "$SCRIPTS/lib.sh"

fail() {
  echo "not ok - $1"
  shift
  for line in "$@"; do echo "    $line"; done
  echo "x" >>"$FAILURES"
}

pass() {
  echo "ok - $1"
}

# install_shims <dir>: writes gh and git shims into <dir>.
#   gh: logs to $SHIM_LOG; answers tag lookups from $EXISTING_TAGS (one tag
#       per line; "!error" makes every lookup fail with HTTP 500); records the
#       notes of `gh release create` in $SHIM_LOG.notes; answers release
#       lookups from $EXISTING_RELEASES ("<tag> <target>" per line; "!error"
#       makes every lookup fail with HTTP 500), if the file exists.
#   git: logs and swallows `git push`; passes everything else to the real git.
install_shims() {
  local dir="$1" real_git
  real_git="$(command -v git)"
  mkdir -p "$dir"
  cat >"$dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh' >>"$SHIM_LOG"
printf ' %q' "$@" >>"$SHIM_LOG"
printf '\n' >>"$SHIM_LOG"
if [[ "$1" == "api" && "$2" == repos/*/git/ref/tags/* ]]; then
  tag="${2#repos/*/git/ref/tags/}"
  if grep -qxF '!error' "$EXISTING_TAGS"; then
    echo "gh: Server Error (HTTP 500)" >&2
    exit 1
  fi
  if grep -qxF -- "$tag" "$EXISTING_TAGS"; then
    exit 0
  fi
  echo "gh: Not Found (HTTP 404)" >&2
  exit 1
fi
if [[ "$1" == "api" && "$2" == repos/*/releases/tags/* ]]; then
  tag="${2#repos/*/releases/tags/}"
  if [[ -f "${EXISTING_RELEASES:-}" ]] && grep -qxF '!error' "$EXISTING_RELEASES"; then
    echo "gh: Server Error (HTTP 500)" >&2
    exit 1
  fi
  if [[ -f "${EXISTING_RELEASES:-}" ]] && target="$(awk -v tag="$tag" '$1 == tag { print $2; found = 1 } END { exit !found }' "$EXISTING_RELEASES")"; then
    echo "$target"
    exit 0
  fi
  echo "gh: Not Found (HTTP 404)" >&2
  exit 1
fi
if [[ "$1" == "release" && "$2" == "create" ]]; then
  while (($# > 0)); do
    if [[ "$1" == "--notes-file" ]]; then
      cp "$2" "$SHIM_LOG.notes"
    fi
    shift
  done
  exit 0
fi
echo "gh shim: unexpected command" >&2
exit 1
EOF
  cat >"$dir/git" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "push" ]]; then
  printf 'git' >>"\$SHIM_LOG"
  printf ' %q' "\$@" >>"\$SHIM_LOG"
  printf '\n' >>"\$SHIM_LOG"
  exit 0
fi
exec "$real_git" "\$@"
EOF
  chmod +x "$dir/gh" "$dir/git"
}

# changelog <path> <version> <entries> [<version> <entries>]...
changelog() {
  local file="$1"
  shift
  mkdir -p "$(dirname "$file")"
  {
    printf '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n'
    printf '## [Unreleased]\n\n'
    while (($# >= 2)); do
      printf '## [%s]\n\n### Added\n\n%s\n\n' "$1" "$2"
      shift 2
    done
    printf '[Unreleased]: https://github.com/octo/repo/compare/HEAD\n'
  } >"$file"
}

# pkg <dir> <name> <version> [private] [extra jq filter]
pkg() {
  local dir="$1" name="$2" version="$3" private="${4:-false}" extra="${5:-.}"
  mkdir -p "$dir"
  jq -n --arg name "$name" --arg version "$version" --argjson private "$private" \
    "{name: \$name, version: \$version} + (if \$private then {private: true} else {} end) | $extra" \
    >"$dir/package.json"
}

root_manifest() {
  local version="$1" workspaces="${2:-[\"packages/*\"]}"
  jq -n --arg version "$version" --argjson workspaces "$workspaces" '{
    name: "root", version: $version, private: true,
    repository: {type: "git", url: "https://github.com/octo/repo.git"},
    workspaces: $workspaces
  }' >package.json
}

commit_all() {
  git init -q
  git add -A
  git commit -q -m "Release"
}

# commit_changes: commits every change in the current repository, as the
# release commit.
commit_changes() {
  git add -A
  git commit -q -m "Change"
}

# The main monorepo fixture: a and b are released; c is already tagged; d is
# private; e is at 0.0.0.
monorepo_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  cd "$dir"
  root_manifest 3.0.0
  echo '{"versioningStrategy": "independent"}' >release.config.json
  pkg packages/a @octo/a 1.1.0
  changelog packages/a/CHANGELOG.md 1.1.0 $'- Add a feature ([#12](https://github.com/octo/repo/pull/12))\n- EOF_0123456789abcdef: a line that looks like a delimiter' 1.0.0 '- Initial release'
  pkg packages/b @octo/b 2.0.0
  changelog packages/b/CHANGELOG.md 2.0.0 '- **BREAKING:** Remove a thing ([#13](https://github.com/octo/repo/pull/13))' 1.0.0 '- Initial release'
  pkg packages/c @octo/c 1.0.0
  changelog packages/c/CHANGELOG.md 1.0.0 '- Initial release'
  pkg packages/d @octo/d 1.0.0 true
  pkg packages/e @octo/e 0.0.0
  commit_all
  printf '%s\n' "@octo/c@1.0.0" "@octo/a@1.0.0" "@octo/b@1.0.0" >"$dir.existing-tags"
}

if [[ "${1:-}" == "--prepare-workspace" ]]; then
  dir="$2"
  install_shims "$dir.shims"
  monorepo_fixture "$dir"
  exit 0
fi

# run_prepare <dir> <existing tags file>: runs prepare-release.sh in <dir>.
# Sets PREPARE_STATUS and PREPARE_LOG; outputs are in <dir>.out/.
run_prepare() {
  local dir="$1" tags="$2"
  mkdir -p "$dir.out"
  : >"$dir.out/github_output"
  : >"$dir.out/github_env"
  : >"$dir.out/shim.log"
  set +e
  PREPARE_LOG="$(cd "$dir" && PATH="$WORK/shims:$PATH" SHIM_LOG="$dir.out/shim.log" EXISTING_TAGS="$tags" \
    GITHUB_OUTPUT="$dir.out/github_output" GITHUB_ENV="$dir.out/github_env" RELEASE_DIR="$dir.out/release" \
    "$SCRIPTS/prepare-release.sh" 2>&1)"
  PREPARE_STATUS=$?
  set -e
}

# run_create <dir> <mode> <version> [<release commit>]: runs create-release.sh
# in <dir>, with the release commit defaulting to HEAD. Sets CREATE_STATUS and
# CREATE_LOG.
run_create() {
  local dir="$1" mode="$2" version="$3" commit="${4:-}"
  if [[ -z "$commit" ]]; then
    commit="$(git -C "$dir" rev-parse HEAD)"
  fi
  set +e
  CREATE_LOG="$(cd "$dir" && PATH="$WORK/shims:$PATH" SHIM_LOG="$dir.out/shim.log" GH_TOKEN=token \
    EXISTING_RELEASES="$dir.existing-releases" \
    RELEASE_COMMIT_ID="$commit" RELEASE_VERSION="$version" RELEASE_MODE="$mode" \
    RELEASE_DIR="$dir.out/release" "$SCRIPTS/create-release.sh" 2>&1)"
  CREATE_STATUS=$?
  set -e
}

# env_value <github_env file> <name>: parses a NAME<<DELIM ... DELIM entry as
# the runner does.
env_value() {
  awk -v name="$2" '
    !inside && index($0, name "<<") == 1 { delim = substr($0, length(name) + 3); inside = 1; next }
    inside && $0 == delim { exit }
    inside { print }
  ' "$1"
}

# workflow_commands <log>: prints the lines of <log> that the runner would
# run as workflow commands. The runner splits output at CR as well as LF,
# ignores leading whitespace, reads "::<command>::" at the start of a line and
# the older "##[<command>]" anywhere in it, and runs nothing between
# ::stop-commands::<token> and ::<token>::.
workflow_commands() {
  tr '\r' '\n' <<<"$1" | awk '
    { sub(/^[[:space:]]+/, "") }
    stop != "" { if ($0 == "::" stop "::") stop = ""; next }
    /^::stop-commands::/ { stop = substr($0, 18); next }
    /^::/ || index($0, "##[") { print }
  '
}

expect_prepare_failure() {
  local test_name="$1" pattern="$2"
  if ((PREPARE_STATUS != 0)) && grep -qF -- "$pattern" <<<"$PREPARE_LOG"; then
    pass "$test_name"
  else
    fail "$test_name" "status $PREPARE_STATUS, expected output containing: $pattern" "$PREPARE_LOG"
  fi
}

install_shims "$WORK/shims"

# --- changelog_section -------------------------------------------------------

test_changelog_section() {
  local file="$WORK/CHANGELOG.md" actual expected
  cat >"$file" <<'EOF'
# Changelog

## [Unreleased]

## [2.0.0]

### Changed

- **BREAKING:** Rename `foo` to `bar` ([#20](https://github.com/octo/repo/pull/20))
- Improve performance

### Fixed

- Fix a bug ([#21](https://github.com/octo/repo/pull/21), [#22](https://github.com/octo/repo/pull/22))
  - With a nested note

## [1.1.0] - 2024-01-01

### Added

- Dated section entry

## [1.0.0]

### Added

- Initial release

[Unreleased]: https://github.com/octo/repo/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/octo/repo/compare/v1.1.0...v2.0.0
EOF

  expected=$'### Changed\n\n- **BREAKING:** Rename `foo` to `bar` ([#20](https://github.com/octo/repo/pull/20))\n- Improve performance\n\n### Fixed\n\n- Fix a bug ([#21](https://github.com/octo/repo/pull/21), [#22](https://github.com/octo/repo/pull/22))\n  - With a nested note'
  actual="$(changelog_section "$file" 2.0.0)"
  if [[ "$actual" == "$expected" ]]; then pass "changelog_section: middle section, categories, BREAKING"; else fail "changelog_section: middle section" "$actual"; fi

  actual="$(changelog_section "$file" 1.0.0)"
  if [[ "$actual" == $'### Added\n\n- Initial release' ]]; then pass "changelog_section: oldest section, before link references"; else fail "changelog_section: oldest section" "$actual"; fi

  actual="$(changelog_section "$file" 1.1.0)"
  if [[ "$actual" == $'### Added\n\n- Dated section entry' ]]; then pass "changelog_section: heading with a date"; else fail "changelog_section: dated" "$actual"; fi

  actual="$(changelog_section "$file" Unreleased)"
  if [[ -z "$actual" ]]; then pass "changelog_section: empty section"; else fail "changelog_section: empty section" "$actual"; fi

  if changelog_section "$file" 3.0.0 >/dev/null; then
    fail "changelog_section: missing section fails"
  else
    pass "changelog_section: missing section fails"
  fi

  printf '## [2.0.0]\r\n\r\n- crlf\r\n\r\n## [1.0.0]\r\n' >"$file"
  actual="$(changelog_section "$file" 2.0.0 || true)"
  if [[ "$actual" == "- crlf" ]]; then
    pass "changelog_section: CRLF line endings"
  else
    fail "changelog_section: CRLF line endings" "got: $(printf '%q' "$actual")"
  fi

  # "1.0.0" must not match "1.0.0-rc.1" or "11.0.0".
  printf '## [1.0.0-rc.1]\n\n- rc\n\n## [11.0.0]\n\n- eleven\n' >"$file"
  if changelog_section "$file" 1.0.0 >/dev/null; then
    fail "changelog_section: no prefix match"
  else
    pass "changelog_section: no prefix match"
  fi
}

# --- list_workspaces ---------------------------------------------------------

test_list_workspaces() {
  local dir="$WORK/workspaces" actual
  mkdir -p "$dir"
  (
    cd "$dir"
    root_manifest 1.0.0 '["packages/*", "tools/cli", "missing/*"]'
    pkg packages/b b 1.0.0
    pkg packages/a a 1.0.0
    mkdir -p packages/no-manifest packages/node_modules/x
    pkg packages/node_modules x 1.0.0
    pkg tools/cli cli 1.0.0
    pkg packages/n n 1.0.0 true '. + {workspaces: ["plugins/*"]}'
    pkg packages/n/plugins/p p 1.0.0
  )
  actual="$(list_workspaces "$dir" | tr '\n' ' ')"
  if [[ "$actual" == ". packages/a packages/b packages/n packages/n/plugins/p tools/cli " ]]; then
    pass "list_workspaces: order, nested workspaces, skipped directories"
  else
    fail "list_workspaces: order" "$actual"
  fi

  (cd "$dir" && root_manifest 1.0.0 '{"packages": ["packages/*"]}')
  actual="$(list_workspaces "$dir" | tr '\n' ' ')"
  if [[ "$actual" == ". packages/a packages/b packages/n packages/n/plugins/p " ]]; then
    pass "list_workspaces: object form"
  else
    fail "list_workspaces: object form" "$actual"
  fi

  for pattern in 'packages/**' 'packages/*/x' '*' 'packages/{a,b}' '../other'; do
    (cd "$dir" && root_manifest 1.0.0 "[\"$pattern\"]")
    if list_workspaces "$dir" >/dev/null 2>&1; then
      fail "list_workspaces: rejects $pattern"
    else
      pass "list_workspaces: rejects $pattern"
    fi
  done
}

# --- prepare-release.sh and create-release.sh --------------------------------

test_monorepo() {
  local dir="$WORK/monorepo"
  (monorepo_fixture "$dir")
  run_prepare "$dir" "$dir.existing-tags"
  if ((PREPARE_STATUS != 0)); then
    fail "monorepo: prepare succeeds" "$PREPARE_LOG"
    return
  fi
  pass "monorepo: prepare succeeds"

  local packages
  packages="$(cat "$dir.out/release/packages.tsv")"
  if [[ "$packages" == $'@octo/a\tpackages/a\t1.1.0\n@octo/b\tpackages/b\t2.0.0' ]]; then
    pass "monorepo: releases exactly the new public packages, in workspace order"
  else
    fail "monorepo: released packages" "$packages"
  fi

  local expected_notes
  expected_notes=$'## @octo/a 1.1.0\n\n### Added\n\n- Add a feature ([#12](https://github.com/octo/repo/pull/12))\n- EOF_0123456789abcdef: a line that looks like a delimiter\n\n## @octo/b 2.0.0\n\n### Added\n\n- **BREAKING:** Remove a thing ([#13](https://github.com/octo/repo/pull/13))'
  if [[ "$(cat "$dir.out/release/notes.md")" == "$expected_notes" ]]; then
    pass "monorepo: notes"
  else
    fail "monorepo: notes" "$(cat "$dir.out/release/notes.md")"
  fi

  if grep -qx 'release-version=3.0.0' "$dir.out/github_output" && grep -qx 'mode=monorepo' "$dir.out/github_output"; then
    pass "monorepo: outputs"
  else
    fail "monorepo: outputs" "$(cat "$dir.out/github_output")"
  fi

  if [[ "$(env_value "$dir.out/github_env" RELEASE_NOTES)" == "$expected_notes" ]]; then
    pass "monorepo: RELEASE_NOTES exported intact"
  else
    fail "monorepo: RELEASE_NOTES" "$(cat "$dir.out/github_env")"
  fi

  if grep -q 'git/ref/tags/@octo/d@\|git/ref/tags/@octo/e@' "$dir.out/shim.log"; then
    fail "monorepo: no tag lookup for private or 0.0.0 packages" "$(cat "$dir.out/shim.log")"
  else
    pass "monorepo: no tag lookup for private or 0.0.0 packages"
  fi

  run_create "$dir" monorepo 3.0.0
  if ((CREATE_STATUS != 0)); then
    fail "monorepo: create succeeds" "$CREATE_LOG"
    return
  fi
  local sha
  sha="$(git -C "$dir" rev-parse HEAD)"
  if grep -qxF "gh release create v3.0.0 --title 3.0.0 --notes-file $dir.out/release/notes.md --target $sha" "$dir.out/shim.log" &&
    cmp -s "$dir.out/shim.log.notes" "$dir.out/release/notes.md"; then
    pass "monorepo: release created"
  else
    fail "monorepo: release created" "$(cat "$dir.out/shim.log")"
  fi
  if grep -qxF "git push https://x-access-token:token@github.com/octo/repo.git refs/tags/@octo/a@1.1.0 refs/tags/@octo/b@2.0.0" "$dir.out/shim.log" &&
    [[ "$(git -C "$dir" tag --points-at HEAD | tr '\n' ' ')" == "@octo/a@1.1.0 @octo/b@2.0.0 " ]]; then
    pass "monorepo: exactly the released tags created and pushed"
  else
    fail "monorepo: tags" "$(cat "$dir.out/shim.log")" "$(git -C "$dir" tag)"
  fi
}

test_missing_section() {
  local dir="$WORK/missing-section"
  (
    monorepo_fixture "$dir"
    changelog packages/b/CHANGELOG.md 1.0.0 '- Initial release'
    commit_changes
  )
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "missing changelog section fails" "packages/b/CHANGELOG.md has no section for 2.0.0"
  if [[ -s "$dir.out/github_env" ]] || grep -q '^gh release' "$dir.out/shim.log"; then
    fail "missing changelog section: nothing exported"
  else
    pass "missing changelog section: nothing exported"
  fi
}

test_nothing_to_release() {
  local dir="$WORK/nothing"
  (monorepo_fixture "$dir")
  printf '%s\n' "@octo/a@1.1.0" "@octo/b@2.0.0" "@octo/c@1.0.0" >"$dir.existing-tags"
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "no released packages fails" "No packages to release"
}

test_lookup_error() {
  local dir="$WORK/lookup-error"
  (monorepo_fixture "$dir")
  echo '!error' >"$dir.existing-tags"
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "tag lookup error other than 404 fails" "Could not look up tag"
}

test_config_errors() {
  local dir
  dir="$WORK/fixed"
  (monorepo_fixture "$dir" && echo '{"versioningStrategy": "fixed"}' >release.config.json && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "versioningStrategy fixed fails" "Only 'independent' is supported"

  dir="$WORK/no-config"
  (monorepo_fixture "$dir" && git rm -q release.config.json && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "monorepo without release.config.json fails" "release.config.json not found"

  dir="$WORK/globstar"
  (monorepo_fixture "$dir" && root_manifest 3.0.0 '["packages/**"]' && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "workspaces packages/** fails" "Unsupported workspace pattern 'packages/**'"

  dir="$WORK/bad-version"
  (monorepo_fixture "$dir" && root_manifest 3.0 '["packages/*"]' && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "invalid root version fails" "not a valid SemVer version"

  dir="$WORK/bad-url"
  (monorepo_fixture "$dir" && jq '.repository.url = "git@github.com:octo/repo.git"' package.json >p && mv p package.json && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "non-https repository URL fails" "must be an https: or git+https: URL"

  dir="$WORK/git-https-url"
  (monorepo_fixture "$dir" && jq '.repository.url = "git+https://github.com/octo/repo.git"' package.json >p && mv p package.json && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  if ((PREPARE_STATUS == 0)) && grep -qxF "Repository: https://github.com/octo/repo" <<<"$PREPARE_LOG"; then
    pass "git+https repository URL is accepted"
  else
    fail "git+https repository URL is accepted" "status $PREPARE_STATUS" "$PREPARE_LOG"
  fi

  dir="$WORK/bad-name"
  (monorepo_fixture "$dir" && pkg packages/a '@octo/a?x' 1.1.0 && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "invalid package name fails" "is not a valid npm package name"

  dir="$WORK/empty-section"
  (monorepo_fixture "$dir" && printf '## [Unreleased]\n\n## [2.0.0]\n\n## [1.0.0]\n\n- Initial release\n' >packages/b/CHANGELOG.md && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "empty changelog section fails" "packages/b/CHANGELOG.md has an empty section for 2.0.0"

  dir="$WORK/duplicate"
  (monorepo_fixture "$dir" && pkg packages/z @octo/a 9.9.9 && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "duplicate workspace names fail" "Duplicate workspace name @octo/a"
}

# Changelog lines and other repository text must not reach the log as
# workflow commands.
test_workflow_commands() {
  local dir="$WORK/commands" commands
  (
    monorepo_fixture "$dir"
    changelog packages/a/CHANGELOG.md 1.1.0 $'- Entry\n::warning::from a line\n  ::warning::indented\n- x\r::warning::after CR\n##[warning]legacy' 1.0.0 '- Initial release'
    jq '.repository.url = "https://github.com/octo/repo\n::warning::from the URL"' package.json >p && mv p package.json
    commit_changes
  )
  run_prepare "$dir" "$dir.existing-tags"
  commands="$(workflow_commands "$PREPARE_LOG")"
  if ((PREPARE_STATUS == 0)) && [[ -z "$commands" ]] && grep -qF '::warning::from a line' <<<"$PREPARE_LOG"; then
    pass "workflow commands: none from release notes or the repository URL"
  else
    fail "workflow commands: none from release notes or the repository URL" "status $PREPARE_STATUS" "commands: $commands" "$PREPARE_LOG"
  fi

  # "##[" anywhere in a printed value: a repository URL that would stop
  # commands with a token the changelog then resumes, and a workspace path.
  dir="$WORK/commands-legacy"
  (
    monorepo_fixture "$dir"
    jq '.repository.url = "https://github.com/octo/repo##[stop-commands]zz123456"' package.json >p && mv p package.json
    changelog packages/a/CHANGELOG.md 1.1.0 $'- Entry\n::zz123456::\n::warning::after the resume' 1.0.0 '- Initial release'
    pkg 'packages/##[add-mask]x' @octo/x 1.0.0
    changelog 'packages/##[add-mask]x/CHANGELOG.md' 1.0.0 '- Initial release'
    commit_changes
  )
  run_prepare "$dir" "$dir.existing-tags"
  commands="$(workflow_commands "$PREPARE_LOG")"
  if ((PREPARE_STATUS == 0)) && [[ -z "$commands" ]] && grep -qF 'Releasing @octo/x@1.0.0 (packages/' <<<"$PREPARE_LOG"; then
    pass "workflow commands: none from ##[ in the repository URL or a workspace path"
  else
    fail "workflow commands: none from ##[ in the repository URL or a workspace path" "status $PREPARE_STATUS" "commands: $commands" "$PREPARE_LOG"
  fi

  dir="$WORK/commands-error"
  (monorepo_fixture "$dir" && root_manifest $'3.0\n::warning::from the version' && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  commands="$(workflow_commands "$PREPARE_LOG")"
  if ((PREPARE_STATUS != 0)) && [[ "$commands" == "::error::The root package.json version '3.0%0A::warning::from the version' is not a valid SemVer version." ]]; then
    pass "workflow commands: invalid values are escaped in errors"
  else
    fail "workflow commands: invalid values are escaped in errors" "status $PREPARE_STATUS" "commands: $commands"
  fi

  dir="$WORK/commands-path"
  (monorepo_fixture "$dir" && pkg $'packages/x\n::warning::from a path' @octo/x 1.0.0 && commit_changes)
  run_prepare "$dir" "$dir.existing-tags"
  commands="$(workflow_commands "$PREPARE_LOG")"
  if ((PREPARE_STATUS != 0)) && [[ "$commands" == "::error::Workspace path 'packages/x%0A::warning::from a path' contains a control character." ]]; then
    pass "workflow commands: workspace paths with control characters fail"
  else
    fail "workflow commands: workspace paths with control characters fail" "status $PREPARE_STATUS" "commands: $commands"
  fi
}

# expect_uncommitted_failure <name> <dir> <pattern>: runs prepare-release.sh
# in <dir> and expects it to fail with <pattern> before exporting anything.
expect_uncommitted_failure() {
  local test_name="$1" dir="$2" pattern="$3"
  run_prepare "$dir" "$dir.existing-tags"
  if ((PREPARE_STATUS != 0)) && grep -qF -- "$pattern" <<<"$PREPARE_LOG" && [[ ! -s "$dir.out/github_env" ]]; then
    pass "$test_name"
  else
    fail "$test_name" "status $PREPARE_STATUS, expected output containing: $pattern" "$PREPARE_LOG"
  fi
}

# The scripts read the working tree, but the release is HEAD: every file they
# read must be committed, unchanged.
test_uncommitted() {
  local dir

  dir="$WORK/uncommitted-version"
  (monorepo_fixture "$dir" && pkg packages/a @octo/a 1.2.0)
  expect_uncommitted_failure "uncommitted workspace version fails" "$dir" \
    "packages/a/package.json has uncommitted changes."

  dir="$WORK/staged-root"
  (monorepo_fixture "$dir" && root_manifest 4.0.0 && git add package.json)
  expect_uncommitted_failure "staged root package.json fails" "$dir" "::error::package.json has uncommitted changes."

  dir="$WORK/uncommitted-config"
  (monorepo_fixture "$dir" && echo '{"versioningStrategy": "independent", "x": 1}' >release.config.json)
  expect_uncommitted_failure "uncommitted release.config.json fails" "$dir" \
    "release.config.json has uncommitted changes."

  dir="$WORK/uncommitted-changelog"
  (monorepo_fixture "$dir" && changelog packages/b/CHANGELOG.md 2.0.0 '- Not in HEAD' 1.0.0 '- Initial release')
  expect_uncommitted_failure "uncommitted changelog fails" "$dir" "packages/b/CHANGELOG.md has uncommitted changes."

  dir="$WORK/untracked-workspace"
  (monorepo_fixture "$dir" && pkg packages/f @octo/f 1.0.0)
  expect_uncommitted_failure "untracked workspace fails" "$dir" \
    "packages/f/package.json is not a file committed at HEAD."

  dir="$WORK/ignored-workspace"
  (monorepo_fixture "$dir" && echo 'packages/f/' >.gitignore && commit_changes && pkg packages/f @octo/f 1.0.0)
  expect_uncommitted_failure "ignored workspace fails" "$dir" \
    "packages/f/package.json is not a file committed at HEAD."

  dir="$WORK/deleted-workspace"
  (monorepo_fixture "$dir" && mv packages/b "$dir.b")
  expect_uncommitted_failure "workspace missing from the working tree fails" "$dir" \
    "package.json files committed at HEAD are missing from the working tree."

  dir="$WORK/symlinked-manifest"
  (
    monorepo_fixture "$dir"
    mv packages/a/package.json "$dir.a.json"
    ln -s "$dir.a.json" packages/a/package.json
    commit_changes
  )
  expect_uncommitted_failure "manifest committed as a symlink fails" "$dir" \
    "packages/a/package.json is not a file committed at HEAD."

  dir="$WORK/uncommitted-polyrepo"
  mkdir -p "$dir"
  (
    cd "$dir"
    jq -n '{name: "@octo/single", version: "1.2.0", repository: {url: "https://github.com/octo/repo"}}' >package.json
    changelog CHANGELOG.md 1.1.0 '- Old thing'
    commit_all
    changelog CHANGELOG.md 1.2.0 '- Not in HEAD' 1.1.0 '- Old thing'
  )
  : >"$dir.existing-tags"
  expect_uncommitted_failure "polyrepo: uncommitted changelog fails" "$dir" "CHANGELOG.md has uncommitted changes."
}

test_head_mismatch() {
  local dir="$WORK/head-mismatch" release_commit
  (monorepo_fixture "$dir")
  run_prepare "$dir" "$dir.existing-tags"
  release_commit="$(git -C "$dir" rev-parse HEAD)"
  git -C "$dir" commit -q --allow-empty -m "After the release"
  : >"$dir.out/shim.log"
  run_create "$dir" monorepo 3.0.0 "$release_commit"
  if ((CREATE_STATUS != 0)) && grep -qF "is not the release commit ($release_commit)" <<<"$CREATE_LOG" &&
    [[ ! -s "$dir.out/shim.log" && -z "$(git -C "$dir" tag)" ]]; then
    pass "HEAD other than the release commit fails before creating anything"
  else
    fail "HEAD other than the release commit fails" "status $CREATE_STATUS" "$CREATE_LOG" "$(cat "$dir.out/shim.log")"
  fi
  # A ref name is not a release commit, even if it resolves to HEAD.
  git -C "$dir" reset -q --hard "$release_commit"
  : >"$dir.out/shim.log"
  run_create "$dir" monorepo 3.0.0 HEAD
  if ((CREATE_STATUS != 0)) && grep -qF "The release commit 'HEAD' is not a full commit SHA." <<<"$CREATE_LOG" &&
    [[ ! -s "$dir.out/shim.log" && -z "$(git -C "$dir" tag)" ]]; then
    pass "a release commit that is not a full SHA fails"
  else
    fail "a release commit that is not a full SHA fails" "status $CREATE_STATUS" "$CREATE_LOG"
  fi
}

# A re-run after the release was created but the tag push failed: the release
# is not created again, and the tags are created and pushed.
test_rerun() {
  local dir="$WORK/rerun" sha
  (monorepo_fixture "$dir")
  sha="$(git -C "$dir" rev-parse HEAD)"
  run_prepare "$dir" "$dir.existing-tags"
  echo "v3.0.0 $sha" >"$dir.existing-releases"
  : >"$dir.out/shim.log"
  run_create "$dir" monorepo 3.0.0
  if ((CREATE_STATUS == 0)) && grep -qF "Release v3.0.0 already exists at $sha" <<<"$CREATE_LOG" &&
    ! grep -q '^gh release create' "$dir.out/shim.log" &&
    grep -qxF "git push https://x-access-token:token@github.com/octo/repo.git refs/tags/@octo/a@1.1.0 refs/tags/@octo/b@2.0.0" "$dir.out/shim.log" &&
    [[ "$(git -C "$dir" tag --points-at HEAD | tr '\n' ' ')" == "@octo/a@1.1.0 @octo/b@2.0.0 " ]]; then
    pass "re-run: existing release kept, tags created and pushed"
  else
    fail "re-run: existing release" "status $CREATE_STATUS" "$CREATE_LOG" "$(cat "$dir.out/shim.log")"
  fi

  # Again, now with the tags already created locally.
  : >"$dir.out/shim.log"
  run_create "$dir" monorepo 3.0.0
  if ((CREATE_STATUS == 0)) && grep -qF "Tag @octo/a@1.1.0 already exists at the release commit." <<<"$CREATE_LOG" &&
    ! grep -q '^gh release create' "$dir.out/shim.log" &&
    grep -qxF "git push https://x-access-token:token@github.com/octo/repo.git refs/tags/@octo/a@1.1.0 refs/tags/@octo/b@2.0.0" "$dir.out/shim.log"; then
    pass "re-run: existing tags at the release commit are pushed again"
  else
    fail "re-run: existing tags" "status $CREATE_STATUS" "$CREATE_LOG" "$(cat "$dir.out/shim.log")"
  fi
}

test_rerun_conflicts() {
  local dir="$WORK/rerun-release-conflict"
  (monorepo_fixture "$dir")
  run_prepare "$dir" "$dir.existing-tags"
  echo "v3.0.0 0123456789abcdef0123456789abcdef01234567" >"$dir.existing-releases"
  : >"$dir.out/shim.log"
  run_create "$dir" monorepo 3.0.0
  if ((CREATE_STATUS != 0)) && grep -qF "Release v3.0.0 already exists with target '0123456789abcdef0123456789abcdef01234567'" <<<"$CREATE_LOG" &&
    ! grep -q '^gh release create\|^git push' "$dir.out/shim.log" && [[ -z "$(git -C "$dir" tag)" ]]; then
    pass "re-run: release at another commit fails"
  else
    fail "re-run: release at another commit" "status $CREATE_STATUS" "$CREATE_LOG" "$(cat "$dir.out/shim.log")"
  fi

  dir="$WORK/rerun-tag-conflict"
  (
    monorepo_fixture "$dir"
    git commit -q --allow-empty -m "Earlier"
    git tag @octo/b@2.0.0 HEAD
    git reset -q --hard HEAD~1
  )
  run_prepare "$dir" "$dir.existing-tags"
  : >"$dir.out/shim.log"
  run_create "$dir" monorepo 3.0.0
  if ((CREATE_STATUS != 0)) && grep -qF "Tag @octo/b@2.0.0 already exists at" <<<"$CREATE_LOG" &&
    ! grep -q '^gh release create\|^git push' "$dir.out/shim.log" &&
    [[ -z "$(git -C "$dir" tag --points-at HEAD)" ]]; then
    pass "re-run: tag at another commit fails before creating anything"
  else
    fail "re-run: tag at another commit" "status $CREATE_STATUS" "$CREATE_LOG" "$(cat "$dir.out/shim.log")"
  fi
}

test_release_lookup_error() {
  local dir="$WORK/release-lookup-error"
  (monorepo_fixture "$dir")
  run_prepare "$dir" "$dir.existing-tags"
  echo '!error' >"$dir.existing-releases"
  : >"$dir.out/shim.log"
  run_create "$dir" monorepo 3.0.0
  if ((CREATE_STATUS != 0)) && grep -qF "Could not look up release v3.0.0" <<<"$CREATE_LOG" &&
    ! grep -q '^gh release create\|^git push' "$dir.out/shim.log"; then
    pass "release lookup error other than 404 fails"
  else
    fail "release lookup error" "status $CREATE_STATUS" "$CREATE_LOG" "$(cat "$dir.out/shim.log")"
  fi
}

test_polyrepo() {
  local dir="$WORK/polyrepo"
  mkdir -p "$dir"
  (
    cd "$dir"
    jq -n '{name: "@octo/single", version: "1.2.0", repository: {url: "https://github.com/octo/repo"}}' >package.json
    changelog CHANGELOG.md 1.2.0 '- New thing ([#5](https://github.com/octo/repo/pull/5))' 1.1.0 '- Old thing'
    commit_all
  )
  : >"$dir.existing-tags"
  run_prepare "$dir" "$dir.existing-tags"
  if ((PREPARE_STATUS != 0)); then
    fail "polyrepo: prepare succeeds" "$PREPARE_LOG"
    return
  fi
  if [[ "$(cat "$dir.out/release/notes.md")" == $'### Added\n\n- New thing ([#5](https://github.com/octo/repo/pull/5))' ]] &&
    grep -qx 'mode=polyrepo' "$dir.out/github_output" && grep -qx 'release-version=1.2.0' "$dir.out/github_output" &&
    ! grep -q 'git/ref/tags' "$dir.out/shim.log"; then
    pass "polyrepo: notes from the root changelog, no tag lookups, no release.config.json needed"
  else
    fail "polyrepo: prepare" "$(cat "$dir.out/release/notes.md")" "$(cat "$dir.out/github_output")" "$(cat "$dir.out/shim.log")"
  fi
  run_create "$dir" polyrepo 1.2.0
  if ((CREATE_STATUS == 0)) && grep -q '^gh release create v1.2.0 ' "$dir.out/shim.log" &&
    ! grep -q '^git push' "$dir.out/shim.log" && [[ -z "$(git -C "$dir" tag)" ]]; then
    pass "polyrepo: release created, no tags"
  else
    fail "polyrepo: create" "$CREATE_LOG" "$(cat "$dir.out/shim.log")"
  fi

  (cd "$dir" && changelog CHANGELOG.md 1.1.0 '- Old thing' && git commit -q -am "No section")
  run_prepare "$dir" "$dir.existing-tags"
  expect_prepare_failure "polyrepo: missing section fails" "CHANGELOG.md has no section for 1.2.0"
}

test_changelog_section
test_list_workspaces
test_monorepo
test_missing_section
test_nothing_to_release
test_lookup_error
test_config_errors
test_workflow_commands
test_uncommitted
test_head_mismatch
test_rerun
test_rerun_conflicts
test_release_lookup_error
test_polyrepo

count="$(wc -l <"$FAILURES" | tr -d ' ')"
if ((count > 0)); then
  echo "$count failure(s)"
  exit 1
fi
echo "All tests passed."
