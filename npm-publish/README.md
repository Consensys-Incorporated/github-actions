# npm-publish

Publishes every public workspace package whose current version is not on npm yet, from a job that
has already checked out the release commit and restored its build output. Packages already on npm
are published with OIDC (npm trusted publishing), staged, with provenance for public
repositories; a package's first publish uses `npm-token`. Without a usable credential, the
packages are packed instead (a dry run), with a diff report against the latest published version.
The repository cannot run code while publishing.

Ported from [`MetaMask/action-npm-publish`](https://github.com/MetaMask/action-npm-publish) v7
(MIT). Requires Yarn 4.16 or later.

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
      # Restore build output here.
      - uses: Consensys-Incorporated/github-actions/npm-publish@<sha> # <tag>
        with:
          dry-run: false
          npm-token: ${{ secrets.NPM_TOKEN }}
```

## Inputs

| Input       | Default  | Description                                                                                                      |
| ----------- | -------- | ---------------------------------------------------------------------------------------------------------------- |
| `npm-token` |          | Used only for a package's first publish.                                                                         |
| `dry-run`   |          | `true`: pack instead of publishing. `false`: fail when a credential is missing. Unset: pack when one is missing. |
| `npm-tag`   | `latest` | The dist-tag. Must not be empty.                                                                                 |

Set `dry-run` explicitly on both jobs: with it unset, a publish job whose OIDC grant is missing
packs and passes instead of failing.

## Outputs

| Output    | Description                                               |
| --------- | --------------------------------------------------------- |
| `dry-run` | `true` if any package was packed instead of published. |

## Behavior

1. **Sanitize** (`scripts/sanitize.sh`), before any Yarn command: unset `YARN_*` variables (except
   the action's own), point the action's own Yarn steps at a minimal generated configuration
   outside the checkout (`enableScripts: false`, the npm registry only, no plugins), ignore
   `yarnPath`, delete
   `~/.yarnrc.yml`, reject packages whose `publishConfig.registry` is not
   `https://registry.npmjs.org`, and delete `prepublish`, `prepublishOnly`, `prepack` and
   `postpack` scripts from every workspace, private ones included.
2. **Publish** (`scripts/main.sh`, `publish.sh`): require Yarn ≥ 4.16. Find the public workspaces
   whose `name@version` is not on npm (skipping `0.0.0`; in a single-package repository, the root
   unless it's private), then for each one:
   - `dry-run: true` → pack;
   - not on npm: with a token, `yarn npm publish --tag <tag>`; without, pack (or fail if
     `dry-run: false`);
   - on npm: with OIDC, `yarn npm publish --tag <tag> --staged` (plus `--provenance` for a public
     repository); without, pack (or fail if `dry-run: false`). The token is never used here.
   An npm lookup error other than "not found" fails the action.
3. **Dry run**: tarballs are written to `$RUNNER_TEMP/npm-publish-packages`. Log each tarball's
   SHA-1 and integrity to the step summary, write a `pkdiff` report against `<name>@latest`, and
   upload the tarballs and reports as the
   `npm-publish-dry-run-<sha>` artifact.

## Differences from upstream

- `staged-publish` and `provenance` are removed: OIDC publishes are always staged, with
  provenance for public repositories.
- No Slack notification: upstream posts an "awaiting deployment" Slack message; this port
  doesn't, so `slack-webhook-url`, `channel`, `subteam`, `username` and `icon-url` are removed.
- Publish commands are bash arrays, not strings split on spaces.
- The artifact has an explicit name, overwritten by a second dry run in the same workflow run.
- `pkdiff` is installed from `/tmp`, so no `.npmrc` in the repository applies.
- Tarballs go to `$RUNNER_TEMP/npm-publish-packages` rather than `/tmp`, so tarballs left by
  other jobs on a reused runner aren't reported or uploaded.
- An npm lookup error other than "not found" fails the action, so a registry outage can't send an
  existing package down the token path.
- A single-package repository publishes only if its root isn't private and its version isn't on
  npm yet, so re-running a release doesn't fail on an existing version.
- Lifecycle scripts are removed from private workspaces too.
- `dry-run` is `true` if any package was packed, whatever order the packages were handled in.
- The generated Yarn configuration is passed to the action's own steps only. Upstream writes
  `YARN_RC_FILENAME` to `$GITHUB_ENV`, so every later Yarn command in the caller's job uses it too.

## Security

- No repository-controlled code runs from the sanitize step onward: no repository
  `.yarnrc.yml`, Yarn plugins, `yarnPath`, lifecycle scripts or `YARN_*` overrides.
- Packages are published only to `https://registry.npmjs.org`.
- The token is used only for a package's first publish; existing packages publish only with OIDC,
  staged and with provenance.
- No manifest value is interpolated into a `run:` step.

## Tests

`test/publish-modes.sh` tests mode selection with `yarn` and `npm` shims.
`.github/workflows/test_npm-publish.yml` runs it, and runs the action with real Yarn against
fixture projects built by `test/make-fixture.sh`: dry runs, failures without credentials, a
foreign registry, old Yarn, a polyrepo, a project whose plugin, `yarnPath` and lifecycle scripts
would write marker files, and that `YARN_RC_FILENAME` isn't set in the caller's later steps.
