# check-changelog

On a pull request, fails if a public workspace package has user-facing changes but its
`CHANGELOG.md` has no entry linking the pull request. The `no-changelog` label skips the check.
Changelogs must follow [Keep a Changelog](https://keepachangelog.com/) as parsed by
[`@metamask/auto-changelog`](https://github.com/MetaMask/auto-changelog), with entries linking
pull requests as `([#123](https://github.com/<owner>/<repo>/pull/123))`.

Ported from `MetaMask/github-tools/.github/actions/check-changelog` v1.

## Usage

```yaml
on:
  pull_request:
    types: [opened, synchronize, labeled, unlabeled]

jobs:
  check-changelog:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: Consensys-Incorporated/github-actions/check-changelog@<sha> # <tag>
```

The action fails on any event other than `pull_request`. Don't call it from
`pull_request_target`: that event runs with a write token and secrets, and this action reads the
pull request's content.

Migrating from an earlier version of this action: drop `head-ref` and `repo` from existing calls.

## Inputs

All inputs are optional and default to values from the `pull_request` event.

| Input         | Default                                         | Description                                                      |
| ------------- | ----------------------------------------------- | ---------------------------------------------------------------- |
| `base-branch` | `github.event.pull_request.base.ref`            | The branch the pull request targets.                             |
| `labels`      | `toJSON(github.event.pull_request.labels)`      | The pull request labels as JSON.                                 |
| `pr-number`   | `github.event.pull_request.number`              | The pull request number that changelog entries must link.        |

## What is checked

The workflow's repository is checked out at `refs/pull/<number>/head` (the event's pull request
number) into `target-repo/` with full history, and compared with the merge base of
`origin/<base-branch>`. GitHub mirrors every pull request's head into the base repository under
that ref, so this works for pull requests from forks too. Before any checkout, the action fails
if the event is not `pull_request`, if the event has no pull request number, if `pr-number` is
not a number, or if `base-branch` is empty.

**Monorepo** (root `package.json` has a `workspaces` array): each changed file is mapped to a
package through the workspace patterns that contain `*`: the package directory is the prefix
before the `*` plus the next path segment, so only patterns of the form `<root>/*` are
supported. A file that maps to a directory with no `package.json` at either the pull request
head or the merge base (as with a `packages/*/*` pattern) fails the check. Ignored: files under
`.github/workflows/`, files outside any package, private packages, packages whose `package.json`
the pull request deletes, `*.test.*` and `*.spec.*` files, `__tests__/` and `/docs/` paths, and
`CHANGELOG.md` files. A change to a package's own `package.json` (not a nested one) is ignored
if only its `version` changed, only its `devDependencies` changed (with or without a version
change), or the version went down (a revert). If its version went up along with other changes,
the package's changelog section for the new version is checked instead of `Unreleased`; that
section must exist. Every changed package is checked and every failure reported.

**Single package** (no `workspaces`): the root `CHANGELOG.md`'s `Unreleased` section must link
the pull request.

The `devDependencies` block is taken to end at the first line of the diff (unchanged, removed or
added) starting with `}` that follows a `"devDependencies":` line, and to start at the last
`"devDependencies":` line before that.

## Differences from upstream

- The check script runs from `${{ github.action_path }}` as a committed bundle,
  `dist/check-changelog.js`, with nothing installed at run time, instead of checking out
  `github-tools` and running `yarn` and `ts-node`. The `github-tools-repository` and
  `github-tools-ref` inputs are removed.
- The `head-ref` and `repo` inputs are removed. Callers passed `head-ref: ${{ github.head_ref }}`
  with `repo: ${{ github.repository }}`, and for a pull request from a fork `github.head_ref` is
  the fork's branch name, so the action checked out a branch of that name from the base
  repository: an unrelated branch, or none. The action now always checks out
  `refs/pull/<number>/head` from `github.repository`, and fails on events other than
  `pull_request`. `base-branch`, `labels` and `pr-number` default to the event's values instead of
  being required (`base-branch` defaulted to `main`).
- The target repository is checked out with `persist-credentials: false`. If the script's
  `git fetch origin <base-branch>` fails (as it does for a private repository without
  credentials), it uses `origin/<base-branch>` from the full-history checkout, with a warning.
- `execa` is replaced by `node:child_process`.
- Changed files are listed with `core.quotePath` off and NUL-separated (`git diff -z`), so a path
  with non-ASCII or control characters still maps to its package. Upstream got such paths
  C-quoted, so they mapped to no package and a change to one was ignored.
- Packages are identified by directory (`packages/foo`) rather than by directory name (`foo`), so
  two workspace roots with a package directory of the same name are checked separately, and a
  private package does not exempt a public one of the same name. Log messages name the directory.
- The end of the `devDependencies` block is found on removed and added lines too. Upstream only
  matched unchanged lines, so a diff that changed the block's closing brace (for example, by
  adding a field after it) counted every later change as a `devDependencies` change.
- A package whose `package.json` the pull request deletes is skipped. Upstream treated it as
  public and failed with `CHANGELOG.md not found`. A directory with no `package.json` at the
  merge base either (for example, `packages/group` under a `packages/*/*` pattern) fails with an
  error naming it and saying that only `<root>/*` patterns are supported, where upstream failed
  with `CHANGELOG.md not found`.
- Only the package's own `package.json` gets the `package.json` analysis. Upstream applied it to
  any file whose name ends in `package.json`, such as `schema-package.json` or a test fixture's
  `package.json`, so a version-only change to one of those was skipped.
- A `version` that is not valid semver no longer makes the check skip the `package.json`.
  Upstream's downgrade comparison threw, and the error was caught as "no changes". The change is
  now classified like any other: it is not a downgrade, and if other fields changed too, the
  check fails with an error saying the version is not valid semver, so its changelog section
  can't be checked, and that the `no-changelog` label skips the check.
- The script stops workflow commands (`::stop-commands::` with a random token) for as long as it
  runs, because its output includes text from the pull request (changelog lines, versions, file
  paths), where a `\r` starts a new line for the runner. Commands are resumed only around the
  script's own fetch-failure warning, whose message is escaped onto one line. Error messages go
  to stdout rather than stderr, so the runner sees them in order with the stop and resume
  markers.
- The script refuses to read a root `package.json`, package `package.json` or `CHANGELOG.md` that
  is a symbolic link or is under one, even one pointing inside the repository, because a link
  from the pull request could point at any file on the runner and the file's contents could
  appear in an error message. A refused root `package.json` or `CHANGELOG.md` fails the check; a
  refused package `package.json` is logged and the package is treated as public, as for one that
  can't be parsed.

## Implementation

The check script is `scripts/check-changelog.ts`. The action runs `dist/check-changelog.js`, an
unminified esbuild bundle of the script and the code it uses from its dependencies: `semver` and
`@metamask/auto-changelog`'s `parseChangelog` (`dist/parse-changelog.js` and the modules it
imports). The build resolves `@metamask/auto-changelog` to that module instead of the package's
index, so the bundle contains none of the package's CLI dependencies (`@yarnpkg/core`, Octokit,
execa, yargs). Nothing is installed at run time; all dependencies are devDependencies, used only
to build, typecheck and test. The bundled packages' licenses are in `dist/LICENSES.txt`, written
by the same build. The build fails if the bundle imports anything but `node:` built-ins at run
time: esbuild leaves an import it can't resolve in the bundle without a warning, and the action
has no `node_modules` to load it from.

## Security

The action installs nothing at run time: it runs the committed bundle (see
[Implementation](#implementation)), built from the pinned dependencies in `package-lock.json`. It
reads, but never runs, code from the pull request. Use it in `pull_request`
workflows with a read-only token, never from `pull_request_target`. The content of a pull request
from a fork reaches the script, so it is untrusted: this is why the script stops workflow
commands, refuses symbolic links, lists changed files NUL-separated (`git diff -z`), and the
checkout does not persist credentials. The runner does not process workflow commands
in the check script's output (see above), so text from the pull request can't add annotations or
change the step's environment. The script does not read files through symbolic links (see
above), so a pull request can't make it show the contents of other files on the runner.

## Development

```sh
cd check-changelog
npm ci --ignore-scripts
npm run typecheck
npm test              # unit tests of the package.json diff analysis
npm run build         # rebuilds dist/check-changelog.js and dist/LICENSES.txt
test/fixtures.sh      # end-to-end runs of dist/check-changelog.js against fixture git repositories
```

After changing the script or a dependency, run `npm run build` and commit `dist/`. CI rebuilds
the bundle and fails if `dist/` differs from what is committed. The build empties `dist/` first,
so a committed file that the build doesn't write also fails the check. The fixture tests run the bundle,
which is what the action ships; `SCRIPT="$PWD/scripts/check-changelog.ts" test/fixtures.sh` runs
them against the source instead. The unit tests run against the source.

The fixture tests also fail if any output line, split on `\r` as well as `\n`, would be taken as
a workflow command other than the script's own.

`.github/workflows/test_check-changelog.yml` runs these, checks that `dist/` is up to date, and,
on this repository's own pull requests, runs the action to check that the `no-changelog` label
skips the checkout and that the pull request head (from a fork too) and the base branch are
fetched. On `push` and
`workflow_dispatch` it checks that the action fails without checking anything out. It also checks
out a merged `Consensys-Incorporated/ocap-kernel` pull request at `refs/pull/1290/head`, as the
action would in that repository, and runs the bundled script against it. Run against upstream's script, the fixture tests pass or fail the same way except
in the cases covering the differences listed above.
