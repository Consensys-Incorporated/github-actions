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
        with:
          base-branch: ${{ github.event.pull_request.base.ref }}
          # Not github.head_ref: a fork's branch doesn't exist in this repository.
          head-ref: refs/pull/${{ github.event.pull_request.number }}/head
          labels: ${{ toJSON(github.event.pull_request.labels) }}
          pr-number: ${{ github.event.pull_request.number }}
          repo: ${{ github.repository }}
```

## Inputs

| Input         | Default | Description                                                   |
| ------------- | ------- | ------------------------------------------------------------- |
| `base-branch` | `main`  | The branch the pull request targets.                          |
| `head-ref`    |         | Required. The pull request head ref.                          |
| `labels`      |         | Required. The pull request labels as JSON.                    |
| `pr-number`   |         | Required. The pull request number.                            |
| `repo`        |         | Required. The repository, `owner/name`.                       |

## What is checked

The repository is checked out at `head-ref` into `target-repo/` and compared with the merge base
of `origin/<base-branch>`.

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

- The check script runs from `${{ github.action_path }}` with Node.js 24's built-in type
  stripping and `npm ci --ignore-scripts --omit=dev`, instead of checking out `github-tools` and
  running `yarn` and `ts-node`. The `github-tools-repository` and `github-tools-ref` inputs are
  removed.
- The target repository is checked out with `persist-credentials: false`. If the script's
  `git fetch origin <base-branch>` fails (as it does for a private repository without
  credentials), it uses `origin/<base-branch>` from the full-history checkout, with a warning.
- `execa` is replaced by `node:child_process`.
- Changed files are listed with `core.quotePath` off, so a path with non-ASCII characters still
  maps to its package.
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

## Security

The action installs its own pinned dependencies (`package-lock.json`) at run time, without
install scripts. It reads, but never runs, code from the target repository. Use it in
`pull_request` workflows with a read-only token. The runner does not process workflow commands
in the check script's output (see above), so text from the pull request can't add annotations or
change the step's environment. The script does not read files through symbolic links (see
above), so a pull request can't make it show the contents of other files on the runner.

## Development

```sh
cd check-changelog
npm ci --ignore-scripts
npm run typecheck
npm test              # unit tests of the package.json diff analysis
test/fixtures.sh      # end-to-end runs against fixture git repositories
```

The fixture tests also fail if any output line, split on `\r` as well as `\n`, would be taken as
a workflow command other than the script's own.

`.github/workflows/test_check-changelog.yml` runs these, checks that the `no-changelog` label
skips the checkout, and runs the action against a merged `Consensys-Incorporated/ocap-kernel`
pull request. Run against upstream's script, the fixture tests pass or fail the same way except
in the cases covering the differences listed above.
