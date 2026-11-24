// SPDX-License-Identifier: Apache-2.0
//
// Decision logic for the check-skip-merge-queue action, called from
// actions/github-script steps. Each function takes the objects github-script
// provides, so the tests can pass mocks.

'use strict';

/**
 * Finds the pull request a merge-group head ref belongs to and its position in
 * the merge queue. Sets the `pr-number`, `pr-head-sha` and
 * `merge-queue-position` outputs, or fails the step. `pr-number` is set as soon
 * as the pull request is found.
 *
 * @param {object} args
 * @param {object} args.github - Octokit client.
 * @param {object} args.context - github-script context.
 * @param {object} args.core - @actions/core.
 * @param {string} args.headRef - e.g. refs/heads/gh-readonly-queue/main/pr-123-<sha>.
 */
async function getPullRequestDetails({ github, context, core, headRef }) {
  // Anchored at the end: the base branch name, which comes first, may itself
  // contain "/pr-<n>-".
  const match = headRef.match(/\/pr-([0-9]+)-[0-9a-f]{40}(?:[0-9a-f]{24})?$/u);
  if (!match) {
    core.setFailed(`Could not extract pull request number from head ref: "${headRef}".`);
    return;
  }

  const number = parseInt(match[1], 10);
  const { owner, repo } = context.repo;
  let result;
  try {
    result = await github.graphql(
      `
        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) {
            pullRequest(number: $number) {
              headRefOid
              mergeQueueEntry { position }
            }
          }
        }
      `,
      { owner, name: repo, number },
    );
  } catch (error) {
    core.setFailed(`Could not look up pull request #${number} in "${owner}/${repo}": ${error.message}`);
    return;
  }

  const pullRequest = result?.repository?.pullRequest;
  if (!pullRequest) {
    core.setFailed(`Pull request #${number} not found in repository "${owner}/${repo}".`);
    return;
  }
  core.setOutput('pr-number', number);

  const position = pullRequest.mergeQueueEntry?.position;
  if (!position) {
    core.setFailed(`Pull request #${number} is not in the merge queue.`);
    return;
  }

  core.setOutput('pr-head-sha', pullRequest.headRefOid);
  core.setOutput('merge-queue-position', position);
}

/**
 * Sets the `up-to-date` output: `true` if the pull request is first in the
 * merge queue and its head commit contains the merge group's base commit.
 *
 * The merge group's base is compared by SHA when one is given: it is the
 * commit the merge group was built on, and a SHA can't be shadowed by a tag
 * with the same name as the base branch. Without one, the base branch's
 * current tip is used, named by its full ref for the same reason.
 *
 * The head is compared by SHA, not branch name: a fork's branch doesn't exist
 * in this repository, and a branch can move after the lookup.
 *
 * @param {object} args
 * @param {object} args.github - Octokit client.
 * @param {object} args.context - github-script context.
 * @param {object} args.core - @actions/core.
 * @param {string} args.baseRef - Base branch, with or without `refs/heads/`.
 * Used only when `baseSha` is empty.
 * @param {string} [args.baseSha] - The merge group's base commit.
 * @param {string} args.prHeadSha - Pull request head commit.
 * @param {string} args.mergeQueuePosition - Position, as a string.
 */
async function checkUpToDate({ github, context, core, baseRef, baseSha, prHeadSha, mergeQueuePosition }) {
  const base = (baseRef ?? '').replace(/^refs\/heads\//u, '');
  const sha = baseSha ?? '';
  if (sha && !/^(?:[0-9a-f]{40}|[0-9a-f]{64})$/u.test(sha)) {
    core.setFailed('The base SHA is not a full hexadecimal commit SHA.');
    return;
  }
  if ((!sha && !base) || !prHeadSha) {
    core.setFailed(`Missing base SHA and branch ("${base}") or pull request head ("${prHeadSha}").`);
    return;
  }

  if (parseInt(mergeQueuePosition, 10) !== 1) {
    core.info(`Pull request is not first in the merge queue (position: ${mergeQueuePosition}).`);
    core.setOutput('up-to-date', 'false');
    return;
  }

  const baseName = sha ? `base commit ${sha}` : `base branch "${base}"`;
  const comparison = await github.rest.repos.compareCommitsWithBasehead({
    owner: context.repo.owner,
    repo: context.repo.repo,
    basehead: `${sha || `refs/heads/${base}`}...${prHeadSha}`,
  });

  if (comparison.data.status === 'identical' || comparison.data.status === 'ahead') {
    core.info(`Pull request head ${prHeadSha} is up-to-date with ${baseName}.`);
    core.setOutput('up-to-date', 'true');
  } else {
    core.info(`Pull request head ${prHeadSha} is not up-to-date with ${baseName}.`);
    core.setOutput('up-to-date', 'false');
  }
}

module.exports = { getPullRequestDetails, checkUpToDate };
