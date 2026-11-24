# check-skip-merge-queue

In a `merge_group` run, reports whether the pull request is first in the merge queue and its
head commit already contains the base branch. In that case the merge group's tree is the one the pull
request's own `pull_request` run already tested, and the caller can skip its expensive jobs.

Ported from `MetaMask/github-tools/.github/actions/check-skip-merge-queue` v1 (MIT).

## Usage

The action makes only API calls; it needs no checkout.

```yaml
on:
  merge_group:

jobs:
  check-skip-merge-queue:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
    outputs:
      skip: ${{ steps.check.outputs.up-to-date }}
    steps:
      - id: check
        uses: Consensys-Incorporated/github-actions/check-skip-merge-queue@<sha> # <tag>

  test:
    needs: check-skip-merge-queue
    if: ${{ needs.check-skip-merge-queue.outputs.skip != 'true' }}
    runs-on: ubuntu-latest
    steps:
      - run: echo testing
```

## Inputs

| Input          | Default                                    | Description                                        |
| -------------- | ------------------------------------------ | -------------------------------------------------- |
| `head-ref`     | `${{ github.event.merge_group.head_ref }}` | Merge group head ref (`…/pr-<number>-<sha>`).      |
| `base-ref`     | `${{ github.event.merge_group.base_ref }}` | Base branch, with or without `refs/heads/`.        |
| `github-token` | `${{ github.token }}`                      | Needs `pull-requests: read` and `contents: read`.  |

## Outputs

| Output       | Description                                                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------------------- |
| `up-to-date` | `true` if the pull request is first in the queue and its head commit is `identical` to or `ahead` of the base branch. `false` otherwise, and whenever a lookup fails. |
| `pr-number`  | The pull request number, once the pull request is found.                                                      |

## Differences from upstream

- The inputs are `required: false`. Upstream marked them required while also giving them defaults.
- The decision logic lives in `scripts/check-skip-merge-queue.cjs`, loaded with `require`, so it can be
  unit-tested.
- The comparison step is skipped when the lookup fails. `up-to-date` is still `false`.
- The pull request's head is compared by commit SHA, not branch name. A fork's branch doesn't exist in the base
  repository, and a branch can move between the lookup and the comparison.
- `base-ref` defaults to the merge group's base branch instead of `main`.
- The pull request number is taken from the last `/pr-<number>-<sha>` segment of the head ref, so a base branch
  whose name contains `/pr-<n>-` can't be mistaken for it.
- A failed GraphQL lookup fails the step with a clear message, and the `pr-number` output is set once the pull
  request is found.

## Tests

`.github/workflows/test_check-skip-merge-queue.yml` runs the unit tests in `test/` (`node --test
'check-skip-merge-queue/test/*.test.cjs'`), which cover both decisions with a mocked API client, and runs the
action for head refs that must yield `false`. The positive path depends on live merge-queue state
and is not exercised by the workflow.
