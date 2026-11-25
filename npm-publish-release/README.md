# npm-publish-release

For a release commit, creates the GitHub release `v<root version>` with notes from the changelog.
In a monorepo with independently versioned packages, it decides which packages are in the
release, builds the notes from each one's changelog section, and pushes a `<name>@<version>` tag
per released package. In a single-package repository, the notes are the root changelog's
section. Publishing to npm is a separate action, [`npm-publish`](../npm-publish).

Ported from [`MetaMask/action-publish-release`](https://github.com/MetaMask/action-publish-release)
v3 (MIT; see [NOTICE](NOTICE)), in bash and jq: no `dist/`, no `package.json`, nothing installed
at run time.

## Usage

Run it after checking out the commit the workflow runs on (`github.sha`), in a job with
`contents: write`. The release targets the release commit (`release-commit`, by default
`github.sha`) and the tags go on `HEAD`, so the action fails before creating anything if they
differ.

The action needs only bash, git, jq, `gh` and openssl, which GitHub-hosted runners provide; it
does not need Node.js or an install. Nothing from the repository may run earlier in the job: no
install, build or repository script. Such code could change what later steps run, through
`$GITHUB_ENV` or `$GITHUB_PATH`, or change the files this action reads, while the job holds a
token with `contents: write`. Build and publish in other jobs.

```yaml
jobs:
  publish-release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
        with:
          persist-credentials: false
      - uses: Consensys-Incorporated/github-actions/npm-publish-release@<sha> # <tag>
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

It uses `env.GITHUB_TOKEN` if set, otherwise `github.token`.

## Inputs

| Input            | Default      | Description                                                        |
| ---------------- | ------------ | ------------------------------------------------------------------ |
| `release-commit` | `github.sha` | The full SHA of the commit to release. `HEAD` must be this commit. |

## Outputs

| Output            | Description                          |
| ----------------- | ------------------------------------ |
| `release-version` | The root `package.json` `version`.   |

The release notes are also exported to later steps of the job as the `RELEASE_NOTES` environment
variable.

## Behavior

The action reads the working tree, at the root of the repository, but the release is `HEAD`:
every file it reads (`package.json` files, changelogs, `release.config.json`) must be a regular
file committed at `HEAD`, with no staged or unstaged changes. In a monorepo, no `package.json`
committed at `HEAD` may be missing from the working tree. No file in the index may be marked
skip-worktree (as a sparse checkout does) or assume-unchanged, since `git diff` would not show how
the working tree differs from `HEAD`. Otherwise it fails before creating anything.

1. Read the root `package.json`: `version` (must be valid SemVer) and `repository.url` (must be
   `https:` or `git+https:`).
2. **Single package** (no `workspaces`): the notes are the body of the `## [<version>]` section
   of `CHANGELOG.md`, which must exist and be non-empty.
3. **Monorepo** (`workspaces` present): `release.config.json` must contain
   `{"versioningStrategy": "independent"}`; fixed versioning is not supported.
   - Workspaces are listed without running Yarn, the root first, as `yarn workspaces list` does.
     Patterns may be `<dir>/*` or literal paths; anything else (`**`, braces, `..`) fails.
     Nested workspaces are followed.
   - A workspace is released if it is not private, its version is not `0.0.0`, and the tag
     `<name>@<version>` does not exist (the lookup returns HTTP 404; any other error fails).
     At least one package must be released.
   - The notes are a `## <name> <version>` section per released package, in workspace order,
     each followed by the body of its changelog's `## [<version>]` section, which must exist.
4. Fail if `release-commit` is not a full commit SHA, if `HEAD` is not `release-commit`, if a
   `<name>@<version>` tag for a released package already exists locally at another commit, or
   if the tag `v<version>` already exists in the repository (following annotated tags) at
   another commit. GitHub ignores `--target` when that tag exists, so the release would be
   attached to the tag's commit; this happens when a release is deleted but its tag is not.
5. Create the release with `gh release create v<version> --title <version> --notes-file …
   --target <release-commit>`. If release `v<version>` already exists with target
   `release-commit`, skip this step and say so in the log; if it exists with another target,
   fail.
6. Monorepo: tag `HEAD` with `<name>@<version>` for each released package (keeping such tags
   that already exist at `HEAD`) and push those tags. The push fails if the remote has one of
   them at another commit.

Because of steps 5 and 6, re-running the action after the release was created but the tag push
failed creates and pushes the tags without creating the release again.

A changelog section's body is the lines after its `## [<version>]` heading, up to the next `## `
heading or the first link reference definition, with blank lines trimmed at both ends.

## Differences from upstream

- Fixed versioning and the deprecated `npm-tag` input are removed. A monorepo without
  `release.config.json` fails instead of defaulting to fixed versioning.
- Changelog sections are extracted in awk rather than parsed and re-rendered with
  `@metamask/auto-changelog` v3. The notes keep the file's own spacing; auto-changelog v3 put no
  blank line after `###` headings. CRLF changelogs are read.
- An empty changelog section for a released package fails, as an empty root section does.
- Workspace listing supports `<dir>/*` and literal patterns only, and fails on others instead of
  globbing them. Workspace names must be valid npm package names, and workspace paths must not
  contain control characters.
- Tag lookups fail on errors other than HTTP 404 instead of treating every error as "not
  released".
- The notes are passed with `--notes-file` instead of as an argument.
- The action fails before creating anything if `HEAD` is not the release commit. Upstream created
  the release at `github.sha` and tagged `HEAD` regardless. The release commit is the new
  `release-commit` input, which defaults to `github.sha`.
- An existing release `v<version>` at the release commit is kept instead of failing `gh release
  create`, and existing tags at `HEAD` are kept instead of failing `git tag`, so that a re-run
  can finish a release whose tag push failed.
- The action fails if the tag `v<version>` already exists at another commit. Upstream created
  the release anyway, and GitHub attached it to that commit.
- The action fails if a file it reads is not committed at `HEAD` or has uncommitted changes, or
  if any file is marked skip-worktree or assume-unchanged (a sparse checkout). Upstream read the
  working tree as it was.
- `repository.url` may also be a `git+https:` URL, the form npm normalizes it to.
  Upstream required `https:`.
- Only the new tags are pushed, by name, instead of `git push --tags`, to `GITHUB_SERVER_URL`
  instead of a hard-coded `github.com`.

## Security

- No Yarn, npm or Node.js command runs, so no repository-controlled code (Yarn plugins, scripts)
  runs while the token has `contents: write`. The job must not run any earlier (see
  [Usage](#usage)).
- `BASH_ENV` and `ENV` are cleared in the action's steps, so values that an earlier step wrote
  to `$GITHUB_ENV` do not run code there. This does not protect against
  `$GITHUB_PATH` or other changes an earlier step can make.
- Manifest and changelog values reach commands as quoted shell variables, never through `${{ }}`.
- The only tags created are `<name>@<version>` for released packages, with SemVer versions.
- Repository text cannot start a workflow command in the log. The release notes are printed
  between `::stop-commands::<random token>` and `::<random token>::`. Names and versions are
  validated before they are printed; other values from the repository are printed with `%`, CR
  and LF percent-encoded, so they stay on one line, and in plain log lines also with `#`, `[` and
  `]` percent-encoded, since the runner reads the older `##[<command>]` form anywhere in a line.
  Workspace paths with control characters fail.
- `RELEASE_NOTES` is exported with a random delimiter, so changelog text cannot end the value
  early or set other variables.

## Tests

`test/fixtures.sh` tests the scripts against fixture repositories with `gh` and `git push`
replaced by shims. `.github/workflows/test_npm-publish-release.yml` runs it, runs the action in a
fixture workspace committed over a checkout of this repository (passing that commit as
`release-commit`, with a `BASH_ENV` set by an earlier step, which must not run), and checks
parity with the published `v7.0.0` release of `Consensys-Incorporated/ocap-kernel`.
