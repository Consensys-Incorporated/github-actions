# node-checkout-and-setup

Checks out the repository (unless the workspace is already a git repository), sets up Node.js and
Corepack, and runs `yarn --immutable`, retrying up to 5 times. Optionally caches `node_modules`.
For Yarn 4 projects.

Ported from
[`MetaMask/action-checkout-and-setup`](https://github.com/MetaMask/action-checkout-and-setup) v3
and replaces
[`MetaMask/action-retry-command`](https://github.com/MetaMask/action-retry-command). Differences:

- `persist-credentials` defaults to `false`.
- High-risk jobs cannot use `cache-node-modules` (upstream's write-only cache mode is removed).
- `fetch-depth`, `filter`, `yarn-install-max-retries` and `yarn-tarball` are removed.
- Every boolean input must be exactly `true` or `false`.
- Outputs are `node-modules-cache-hit`, `skipped-setup` (both always `true` or `false`) and
  `node-version`.
- Retries use `scripts/retry.sh`: 5 attempts, the command run directly rather than through
  `$SHELL -c`, and no sleep after the last attempt.
- `actions/setup-node` v7, with `package-manager-cache: false` on the first setup.
- If the selected Node.js doesn't ship Corepack (25 and later), `corepack@0.36.0` is installed for
  it.
- `allow-scripts` is detected by `node_modules/.bin/allow-scripts` rather than `yarn bin`.
- Nothing is downloaded into a workspace that is already checked out. Without `node-version`,
  the action fails with a clear error if such a workspace has no `.nvmrc`. Upstream downloaded a
  missing `.nvmrc`, `package.json` or `yarn.lock` there from `ref` or the triggering commit,
  which may differ from the commit checked out, and could install from that `yarn.lock`.
- The action fails with a clear error when there is no root `yarn.lock` or `package.json`
  (unless `skip-install`). Without a `yarn.lock`, upstream's cache keys end in an empty hash,
  which matches other entries by prefix; without a `package.json`, Corepack runs its default Yarn.
- When the workspace is already a git repository, the action does not check out, and warns if
  `ref` or `persist-credentials: true` is given. Upstream ignored them silently.
- Whether the workspace is already a git repository is decided once, by `-e .git` in
  `scripts/download-metadata.sh`, rather than by `hashFiles('.git')`, which hashes the whole
  `.git` directory and treats an empty one as absent.

## Usage

```yaml
jobs:
  prepare:
    runs-on: ubuntu-latest
    steps:
      - uses: Consensys-Incorporated/github-actions/node-checkout-and-setup@<sha> # <tag>
        with:
          is-high-risk-environment: false
          cache-node-modules: true

  test:
    needs: prepare
    runs-on: ubuntu-latest
    steps:
      - uses: Consensys-Incorporated/github-actions/node-checkout-and-setup@<sha> # <tag>
        with:
          is-high-risk-environment: false
      - run: yarn test

  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: Consensys-Incorporated/github-actions/node-checkout-and-setup@<sha> # <tag>
        with:
          is-high-risk-environment: true
```

## Inputs

| Input                      | Default  | Description                                                                                                                                         |
| -------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `is-high-risk-environment` |          | Required, `true` or `false`. Set `true` in any job that holds write tokens or publish credentials: no Actions cache is then read or written.        |
| `node-version`             | `.nvmrc` | `24`, `24.x`, `v24.13`, `v24.13.0` or `lts/*`. Resolved to the newest matching release. Required in a checked-out workspace without `.nvmrc`.       |
| `cache-node-modules`       | `false`  | Save `node_modules` to the cache after a fresh install. If the cache already holds an entry for this lockfile, skip everything else. Low-risk only. |
| `force-setup`              | `false`  | With `cache-node-modules`, prepare the workspace even when the cache already holds an entry.                                                        |
| `ref`                      | trigger  | Branch, tag or SHA to check out. No effect, with a warning, if the workspace is already a git repository.                                           |
| `persist-credentials`      | `false`  | Leave the job token in `.git/config`, for later steps that push with it. No effect, with a warning, if the workspace is already a git repository.   |
| `skip-install`             | `false`  | Check out and set up Node.js only. No Yarn command runs and no cache is used.                                                                       |
| `skip-allow-scripts`       | `false`  | Do not run `yarn allow-scripts` after restoring `node_modules` from the cache.                                                                      |

## Outputs

| Output                   | Description                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------- |
| `node-modules-cache-hit` | `true` if `node_modules` was restored or found in the cache, otherwise `false`.                |
| `skipped-setup`          | `true` if setup was skipped because the cache already holds `node_modules`, otherwise `false`. |
| `node-version`           | The Node.js version set up; empty if setup was skipped.                                        |

## Behavior

1. If the workspace is not a git repository (has no `.git`), download `.nvmrc`, `yarn.lock` and
   `package.json` from the requested ref, as needed and unless already in the workspace (from
   `raw.githubusercontent.com` for a public repository, otherwise with `gh api` and the job
   token). `yarn.lock` is written to the workspace root and overwritten by the checkout. Nothing
   is downloaded into a workspace that is already a git repository: its files belong to the
   commit checked out, which may differ from `ref` or the triggering commit. There, without
   `node-version`, the action fails if there is no `.nvmrc`. Without a root `package.json`, the
   cache paths fall back to `**/node_modules`, as when a download fails, and unless
   `skip-install` the action then fails at the check below.
2. With `cache-node-modules` in a low-risk job, look up the cache key without downloading. On a
   hit, the job's purpose (warming the cache) is met and the remaining steps are skipped.
3. If the workspace is not a git repository (has no `.git`), check out `ref` with
   `fetch-depth: 1` and `persist-credentials`. Otherwise leave the workspace as it is, and warn if
   `ref` (which then has no effect) or `persist-credentials: true` is given. Unless
   `skip-install`, fail if there is no root `yarn.lock` or `package.json`. Set up Node.js,
   `corepack enable`.
4. Low-risk: restore `node_modules` from the cache. On a hit, run `yarn allow-scripts` if it is
   installed. On a miss, restore Yarn's download cache with `actions/setup-node` and install.
5. High-risk: install, with no cache.
6. With `cache-node-modules` and a cache miss, save `node_modules`.

The cache key is `node-modules-<os>-<arch>-<node version>-<hash of yarn.lock>`, the same as
upstream's, and the cached paths are `.yarn/install-state.gz`, `node_modules` and
`<workspace pattern>/node_modules`.

## Security

- High-risk jobs never read from or write to the Actions cache, so a cache poisoned by a
  pull-request run cannot reach a job with write tokens or publish credentials.
- `skip-install: true` runs no repository code beyond what Corepack needs to provision Yarn.
- When the action checks out, the job token is not left in `.git/config` unless
  `persist-credentials: true`. In a workspace that was already checked out, `.git/config` is left
  as the earlier checkout set it (`actions/checkout` persists the token by default).

## Tests

`.github/workflows/test_node-checkout-and-setup.yml` runs the action against `test-fixture/`, a
Yarn 4 workspace using the LavaMoat `allow-scripts` plugin. Its `allow-scripts-marker` dependency's
allowed `postinstall` script writes `.allow-scripts-ran` in the workspace root, so tests can tell
whether `allow-scripts` ran.

A job can't observe whether a cache step was skipped, so `test/check-cache-guards.sh` checks
`action.yml` instead: every step that can read or write the Actions cache must have
`inputs.is-high-risk-environment == 'false'` in its `if:`, and every `actions/setup-node` step must
set `package-manager-cache: false` or have that condition too. It uses `yq` and `jq`, which GitHub's
Ubuntu runners include.

The scripts job runs `scripts/download-metadata.sh` against the fixture branch, for a public and a
private source. In a `git init`ed directory it must download nothing, and fail without `.nvmrc`
unless `node-version` is given. Its `checked-out` output must be `true` with any `.git` (a
repository, an empty directory or a file) and `false` without one; the `empty-git-dir` job checks
that the action then neither checks out nor downloads.

Annotations can't be read from inside a job, so the warning about `ref` and `persist-credentials`
in a checked-out workspace is tested by running `scripts/warn-ignored-checkout-inputs.sh` in the
scripts job.

Some tests need the fixture at the root of a ref of this repository. After changing
`test-fixture/`, commit, then run `test/publish-fixture.sh` to update the
`test-fixtures/node-checkout-and-setup` branch.

There is one fixture branch for the whole repository. When a pull request changes the fixture and
republishes it, the fixture-branch-up-to-date job fails on every other open pull request until the
change merges and they are rebased onto it. Merge fixture changes before other pull requests that
touch this action.
