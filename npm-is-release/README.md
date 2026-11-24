# npm-is-release

On a push, decides whether the pushed commit is a release: the root `package.json` `version`
changed since the commit before the push, and, optionally, the commit message starts with one of
a set of prefixes.

Ported from [`MetaMask/action-is-release`](https://github.com/MetaMask/action-is-release) v2
(MIT). Differences: prefixes are matched literally (upstream matched them as regular
expressions, so `Release 1.2.0` also matched `Release 1x2y0`); prefixes may also be separated by
newlines, whitespace around them is trimmed and empty ones are ignored; the checkout does not
persist credentials.

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
| `before`             | `${{ github.event.before }}` | The commit to compare with.                                                                                             |
| `skip-checkout`      | `false`                      | Reuse the caller's checkout. `before` must be reachable or fetchable from it.                                           |

## Outputs

| Output       | Description         |
| ------------ | ------------------- |
| `IS_RELEASE` | `true` or `false`. |

## Behavior

1. Unless `skip-checkout`, check out `github.sha` with `fetch-depth: 2`.
2. Fetch `before` (a push may contain more than one commit). If the fetch fails but `before` is
   already present, continue with a warning.
3. If `before`'s root `package.json` version equals the current one, not a release.
4. If `commit-starts-with` is set and the message matches none of the prefixes, not a release.
5. Otherwise, a release.

A push that creates a branch has an all-zero `before`, which cannot be fetched, so the action
fails. Use it on pushes to an existing branch.

## Tests

`test/fixtures.sh` builds fixture repositories with local origins, clones them with `--depth 2`
and runs the script; `.github/workflows/test_npm-is-release.yml` runs it and runs the action with
`skip-checkout`. Run against upstream's script, the fixtures give the same results except for the
two literal-matching cases.
