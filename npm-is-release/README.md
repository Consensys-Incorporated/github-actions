# npm-is-release

On a push, decides whether the pushed commit is a release: the root `package.json` `version`
changed since the commit before the push, and, optionally, the commit message starts with one of
a set of prefixes.

Ported from [`MetaMask/action-is-release`](https://github.com/MetaMask/action-is-release) v2
(MIT; see [NOTICE](NOTICE)). Differences: prefixes are matched literally (upstream matched them as regular
expressions, so `Release 1.2.0` also matched `Release 1x2y0`); prefixes may also be separated by
newlines, whitespace around them is trimmed and empty ones are ignored; the checkout does not
persist credentials, and `github-token` is passed only to the fetch of `before`; `before` must be a
full commit SHA (upstream passed any value to `git fetch`, where one starting with `-` is read as
an option); both versions must be valid semver, or the action fails (upstream compared any values,
including a missing version); the current version is read from the committed `package.json` at
`HEAD` (upstream read the working tree, so with `skip-checkout` an uncommitted change counted).

## Usage

```yaml
on:
  push:
    branches: [main]

jobs:
  is-release:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      IS_RELEASE: ${{ steps.is-release.outputs.IS_RELEASE }}
    steps:
      - id: is-release
        uses: Consensys-Incorporated/github-actions/npm-is-release@<sha> # <tag>
        with:
          commit-starts-with: 'Release [version],Release v[version]'

  publish:
    needs: is-release
    if: ${{ needs.is-release.outputs.IS_RELEASE == 'true' }}
    runs-on: ubuntu-latest
    steps:
      - run: echo publishing
```

## Inputs

| Input                | Default                      | Description                                                                                                             |
| -------------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `commit-starts-with` | `''`                         | Prefixes separated by commas or newlines; `[version]` is replaced by the new version. If empty, a version change alone makes a release. |
| `commit-message`     | `''`                         | Message to check instead of the subject of the checked-out commit.                                                      |
| `before`             | `${{ github.event.before }}` | The full SHA (40 or 64 hexadecimal characters) of the commit to compare with.                                           |
| `github-token`       | `${{ github.token }}`        | Used only to fetch `before` (private repositories, multi-commit pushes). Not stored in `.git/config`.                   |
| `skip-checkout`      | `false`                      | Reuse the caller's checkout. `before` must be reachable or fetchable from it. Uncommitted changes are ignored.          |

## Outputs

| Output       | Description         |
| ------------ | ------------------- |
| `IS_RELEASE` | `true` or `false`. |

## Behavior

1. Unless `skip-checkout`, check out `github.sha` with `fetch-depth: 2`.
2. Check that `before` is a full commit SHA, and fail if it is not.
3. Fetch `before` (a push may contain more than one commit), passing `github-token` to that
   command only. If the fetch fails but `before` is already present, continue with a warning.
4. Read the root `package.json` version at `before` and at `HEAD` (the committed file, not the
   working tree), and fail if either is missing or not valid semver. If they are equal, not a release.
5. If `commit-starts-with` is set and the message matches none of the prefixes, not a release.
6. Otherwise, a release.

A push that creates a branch has an all-zero `before`, with no commit to compare with, so the
action fails. Use it on pushes to an existing branch.

## Tests

`test/fixtures.sh` builds fixture repositories with local origins, clones them with `--depth 2`
and runs the script; `.github/workflows/test_npm-is-release.yml` runs it and runs the action with
`skip-checkout`. Run against upstream's script, the fixtures give the same results except for the
cases covering the differences above: the three literal-matching cases (including the
pre-release version, whose `+` upstream read as a quantifier), the three prefix-list cases
(spaces after commas, newline separators, empty prefixes), the two checks of the token passed to
the fetch, the check that a `before` starting with `-` runs no command, the four invalid
version cases, and the uncommitted-change case.
