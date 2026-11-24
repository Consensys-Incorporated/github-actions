# npm-publish

Publishes every public workspace package whose current version is not on npm yet, from a job that
has already checked out the release commit and restored its build output. Packages already on npm
are published with OIDC (npm trusted publishing), staged, with provenance for public
repositories; a package's first publish uses `npm-token`. Without a usable credential, the
packages are packed instead (a dry run), with a diff report against the latest published version.
The repository cannot run code while publishing.

Ported from [`MetaMask/action-npm-publish`](https://github.com/MetaMask/action-npm-publish) v7
(MIT; see [NOTICE](NOTICE)). Requires Yarn 4.16 or later.

## Usage

```yaml
jobs:
  publish-npm-dry-run:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: Consensys-Incorporated/github-actions/node-checkout-and-setup@<sha> # <tag>
        with:
          is-high-risk-environment: true
          ref: ${{ github.sha }}
          skip-install: true
      # Restore build output here.
      - uses: Consensys-Incorporated/github-actions/npm-publish@<sha> # <tag>
        with:
          dry-run: true

  publish-npm:
    needs: publish-npm-dry-run
    runs-on: ubuntu-latest
    environment: npm-publish
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: Consensys-Incorporated/github-actions/node-checkout-and-setup@<sha> # <tag>
        with:
          is-high-risk-environment: true
          ref: ${{ github.sha }}
          skip-install: true
      # Restore build output here.
      - uses: Consensys-Incorporated/github-actions/npm-publish@<sha> # <tag>
        with:
          dry-run: false
          npm-token: ${{ secrets.NPM_TOKEN }}
```

Nothing from the repository may run in the publish job before this action, since code that runs
earlier can make the action's steps run it again: through `$GITHUB_PATH` (which the action can't
undo), the Corepack cache, or files left in the checkout. Hence `skip-install: true`: `yarn install`
would run Yarn plugins and allowed dependency scripts with OIDC available. Build in another job
and restore the build output as an artifact. Packing and publishing don't need `node_modules`, only
the committed `yarn.lock`.

## Inputs

| Input       | Default  | Description                                                                                                      |
| ----------- | -------- | ---------------------------------------------------------------------------------------------------------------- |
| `npm-token` |          | Used only for a package's first publish.                                                                         |
| `dry-run`   |          | `true`: pack instead of publishing. `false`: fail when a credential is missing. Unset: pack when one is missing. |
| `npm-tag`   | `latest` | The dist-tag. Must not be empty.                                                                                 |

Set `dry-run` explicitly on both jobs: with it unset, a publish job whose OIDC grant is missing
packs and passes instead of failing. Any value of `dry-run` other than `true`, `false` or empty
fails the action before anything else runs.

## Outputs

| Output    | Description                                               |
| --------- | --------------------------------------------------------- |
| `dry-run` | `true` if any package was packed instead of published. |

## Behavior

1. **Sanitize** (`scripts/sanitize.sh`), before any Yarn command: unset `YARN_*` variables (except
   the action's own), stop Corepack from reading a `.corepack.env` file (`COREPACK_ENV_FILE=0`),
   point the action's own Yarn steps at a minimal generated configuration outside the checkout
   (`enableScripts: false`, the npm registry only, no plugins), ignore `yarnPath`, delete
   `~/.yarnrc.yml`, reject packages whose `publishConfig.registry` is not
   `https://registry.npmjs.org`, and delete `prepublish`, `prepublishOnly`, `prepack` and `postpack`
   scripts from every workspace, private ones included.
2. **Find the release pull request**: log the pull request that merged the commit, in a step of
   its own, so that the Publish step doesn't hold the job's `GITHUB_TOKEN`.
3. **Publish** (`scripts/main.sh`, `publish.sh`): require Yarn ≥ 4.16. Find the public workspaces
   whose `name@version` is not on npm (skipping `0.0.0`; in a single-package repository, the root
   unless it's private), then for each one, in the order `yarn workspaces list` prints them, run
   `scripts/publish.sh` in its directory, stopping at the first failure:
   - `dry-run: true` → pack;
   - not on npm: with a token, `yarn npm publish --tag <tag>`; without, pack (or fail if
     `dry-run: false`);
   - on npm: with OIDC, `yarn npm publish --tag <tag> --staged` (plus `--provenance` for a public
     repository); without, pack (or fail if `dry-run: false`). The token is never used here.
   An npm lookup error other than "not found" fails the action, as does a package name that isn't
   a valid npm name, a version that isn't a semantic version, or a workspace location with a
   control character.
4. **Dry run**: tarballs are written to `$RUNNER_TEMP/npm-publish-packages`. Log each tarball's
   SHA-1 and integrity to the step summary, write a `pkdiff` report against `<name>@latest`, and
   upload the tarballs and reports as the
   `npm-publish-dry-run-<sha>` artifact.

The Sanitize step's changes outlast the job on a runner that is reused (self-hosted): it doesn't
restore `~/.yarnrc.yml`, remove the generated `.yarnrc-<random>.yml` from the checkout's parent
directory, or restore the lifecycle scripts it removed from the checkout's manifests.

## Differences from upstream

- `staged-publish` and `provenance` are removed: OIDC publishes are always staged, with
  provenance for public repositories.
- No Slack notification: upstream posts an "awaiting deployment" Slack message; this port
  doesn't, so `slack-webhook-url`, `channel`, `subteam`, `username` and `icon-url` are removed.
- Publish commands are bash arrays, not strings split on spaces, and `npm view` and `pkdiff` get
  package names after `--`, so that a name starting with `-` isn't read as an option.
- The artifact has an explicit name, overwritten by a second dry run in the same workflow run.
- `pkdiff` is installed from `/tmp`, so no `.npmrc` in the repository applies, with
  `--ignore-scripts`, since its dependencies aren't pinned, and with
  `--registry https://registry.npmjs.org`, so that `npm_config_registry` can't redirect it. `pkdiff`
  is also run with `--registry https://registry.npmjs.org`, which it passes to the `npm pack` that
  downloads `<name>@latest`. That doesn't override a scope's registry (e.g.
  `npm_config_@scope:registry` set through `$GITHUB_ENV`), and `pkdiff` has no option that does, so
  for a scoped package the dry run's diff report can still be made against a tarball from another
  registry. The report is informational only: nothing is published from it.
- Tarballs go to `$RUNNER_TEMP/npm-publish-packages` rather than `/tmp`, so tarballs left by
  other jobs on a reused runner aren't reported or uploaded.
- An npm lookup error other than "not found" fails the action, so a registry outage can't send an
  existing package down the token path.
- `npm view` is given `--registry https://registry.npmjs.org`, and for a scoped package
  `--@<scope>:registry=https://registry.npmjs.org` (which `--registry` doesn't override), so that
  `npm_config_*` variables set by the caller's job or through `$GITHUB_ENV`, such as
  `npm_config_registry`, or an `.npmrc`, can't redirect the lookup that chooses between the token
  and OIDC.
- A single-package repository publishes only if its root isn't private and its version isn't on
  npm yet, so re-running a release doesn't fail on an existing version.
- Lifecycle scripts are removed from private workspaces too.
- `dry-run` must be `true`, `false` or empty. Upstream publishes for any value other than `true`.
- `dry-run` is `true` if any package was packed, whatever order the packages were handled in.
- `publish.sh` runs directly in each workspace, not through `yarn workspaces foreach exec`, which
  puts the bins of the workspace and its dependencies first on `PATH`: a package declaring a
  `bash`, `jq`, `npm` or `yarn` bin would run in place of the real tool, with the token in its
  environment.
- `.corepack.env` is ignored: Corepack reads `COREPACK_*` variables from that file in the
  repository, and `COREPACK_ENABLE_UNSAFE_CUSTOM_URLS=1` there lets the `packageManager` field name
  any URL as the Yarn to download and run.
- The action's steps set `BASH_ENV`, `ENV` and `NODE_OPTIONS` to empty values, so that an earlier
  step can't make them run code through `$GITHUB_ENV`.
- With `RUNNER_DEBUG`, `main.sh`, `publish.sh` and `needs-publish.sh` don't trace commands
  (`set -x`): their environment holds the token, which GitHub masks only if it came from a secret.
- Package names, versions and workspace locations are validated (see Behavior), names and
  versions reach `xargs` NUL-separated rather than split on spaces and quotes, and Yarn's output
  while packing or publishing, which lists file names from the repository, is printed between
  `::stop-commands::` markers, so that no repository-controlled text is read as a workflow command.
  A non-npm `publishConfig.registry` is printed as JSON, on one line.
- The release pull request is looked up in its own step, so `GH_TOKEN` is not in the Publish
  step's environment.
- The generated Yarn configuration is passed to the action's own steps only. Upstream writes
  `YARN_RC_FILENAME` to `$GITHUB_ENV`, so every later Yarn command in the caller's job uses it too.

## Security

- No repository-controlled code runs from the sanitize step onward: no repository `.yarnrc.yml`,
  Yarn plugins, `yarnPath`, lifecycle scripts, `YARN_*` overrides, `.corepack.env` or package bins,
  and no `BASH_ENV`, `ENV` or `NODE_OPTIONS` from earlier steps.
- Packages are published only to `https://registry.npmjs.org`, and looked up only there. `pkdiff`
  is installed from there too; its diff report can follow a scope's registry (see above).
- The token is used only for a package's first publish; existing packages publish only with OIDC,
  staged and with provenance.
- No manifest value is interpolated into a `run:` step, and none is printed where the runner could
  read it as a workflow command.

## Tests

`test/publish-modes.sh` tests mode selection with `yarn` and `npm` shims (the `npm` shim fails
unless `npm view` is pinned to `https://registry.npmjs.org`), that `report.sh` passes
`--registry https://registry.npmjs.org` to `pkdiff`, that an invalid `dry-run` fails, that
invalid names and versions fail without being read as workflow commands, that Yarn's output is
wrapped in `::stop-commands::`, that `RUNNER_DEBUG` doesn't print the token, and that a monorepo's
workspaces are handled in Yarn's order and stop at the first failure.
`test/environment-variables.sh` tests that `scripts/environment.sh` unsets every `YARN_*` variable
except the action's own, and that real Corepack then ignores a `.corepack.env` that allows a URL as
the `packageManager`. `.github/workflows/test_npm-publish.yml` runs both, and runs the action with
real Yarn against fixture projects built by `test/make-fixture.sh`: dry runs, failures without
credentials, a foreign registry, old Yarn, an invalid `dry-run` (rejected before the sanitize step),
a polyrepo, a project whose plugin, `yarnPath`, lifecycle scripts and `bash`/`jq`/`npm`/`yarn` bins
would write marker files, as would `BASH_ENV` and `NODE_OPTIONS` set in `$GITHUB_ENV`, that a dry
run with `npm_config_registry` and a scope's registry set to an unreachable host in `$GITHUB_ENV`
still looks packages up on, and installs `pkdiff` from, `https://registry.npmjs.org`, that `YARN_*`
overrides such as `YARN_NPM_REGISTRY_SERVER` don't change the configuration the Publish step reads,
and that `YARN_RC_FILENAME` isn't set in the caller's later steps.
