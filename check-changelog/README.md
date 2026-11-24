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
package through the workspace patterns that contain `*`. Ignored: files under
`.github/workflows/`, files outside any package, private packages, `*.test.*` and `*.spec.*`
files, `__tests__/` and `/docs/` paths, and `CHANGELOG.md` files. A changed `package.json` is
ignored if only its `version` changed, only its `devDependencies` changed (with or without a
version change), or the version went down (a revert). If its version went up along with other
changes, the package's changelog section for the new version is checked instead of `Unreleased`;
that section must exist. Every changed package is checked and every failure reported.

**Single package** (no `workspaces`): the root `CHANGELOG.md`'s `Unreleased` section must link
the pull request.

Two upstream quirks are kept: the `devDependencies` block is taken to end at the first line
starting with `}` after it, and only the first `"devDependencies":` is considered.

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

## Security

The action installs its own pinned dependencies (`package-lock.json`) at run time, without
install scripts. It reads, but never runs, code from the target repository. Use it in
`pull_request` workflows with a read-only token.

## Development

```sh
cd check-changelog
npm ci --ignore-scripts
npm run typecheck
npm test              # unit tests of the package.json diff analysis
test/fixtures.sh      # end-to-end runs against fixture git repositories
```

`.github/workflows/test_check-changelog.yml` runs these, checks that the `no-changelog` label
skips the checkout, and runs the action against a merged `Consensys-Incorporated/ocap-kernel`
pull request. The fixture tests were also run against upstream's script, with the same results.
