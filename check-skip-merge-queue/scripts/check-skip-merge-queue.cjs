// SPDX-License-Identifier: Apache-2.0
//
// Decision logic for the check-skip-merge-queue action, called from
// actions/github-script steps. Each function takes the objects github-script
// provides, so the tests can pass mocks.

'use strict';

/**
 * Finds the pull request a merge-group head ref belongs to and its position in
 * the merge queue. Sets the `pr-number`, `pr-branch` and
 * `merge-queue-position` outputs, or fails the step.
 *
 * @param {object} args
 * @param {object} args.github - Octokit client.
 * @param {object} args.context - github-script context.
 * @param {object} args.core - @actions/core.
 * @param {string} args.headRef - e.g. refs/heads/gh-readonly-queue/main/pr-123-<sha>.
 */
async function getPullRequestDetails({ github, context, core, headRef }) {
  const match = headRef.match(/\/pr-([0-9]+)-/u);
  if (!match) {
    core.setFailed(`Could not extract pull request number from head ref: "${headRef}".`);
    return;
  }

  const number = parseInt(match[1], 10);
  const { owner, repo } = context.repo;
  const result = await github.graphql(
    `
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $number) {
            headRefName
            mergeQueueEntry { position }
          }
        }
      }
    `,
    { owner, name: repo, number },
  );

  const pullRequest = result.repository.pullRequest;
  if (!pullRequest) {
    core.setFailed(`Pull request #${number} not found in repository "${owner}/${repo}".`);
    return;
  }

  const position = pullRequest.mergeQueueEntry?.position;
  if (!position) {
    core.setFailed(`Pull request #${number} is not in the merge queue.`);
    return;
  }

  core.setOutput('pr-number', number);
  core.setOutput('pr-branch', pullRequest.headRefName);
  core.setOutput('merge-queue-position', position);
}

/**
 * Sets the `up-to-date` output: `true` if the pull request is first in the
 * merge queue and its branch contains the base branch.
 *
 * @param {object} args
 * @param {object} args.github - Octokit client.
 * @param {object} args.context - github-script context.
 * @param {object} args.core - @actions/core.
 * @param {string} args.baseRef - Base branch.
 * @param {string} args.prBranch - Pull request branch.
 * @param {string} args.mergeQueuePosition - Position, as a string.
 */
async function checkUpToDate({ github, context, core, baseRef, prBranch, mergeQueuePosition }) {
  if (parseInt(mergeQueuePosition, 10) !== 1) {
    core.info(`Pull request is not first in the merge queue (position: ${mergeQueuePosition}).`);
    core.setOutput('up-to-date', 'false');
    return;
  }

  const comparison = await github.rest.repos.compareCommitsWithBasehead({
    owner: context.repo.owner,
    repo: context.repo.repo,
    basehead: `${baseRef}...${prBranch}`,
  });

  if (comparison.data.status === 'identical' || comparison.data.status === 'ahead') {
    core.info(`Pull request branch "${prBranch}" is up-to-date with base branch "${baseRef}".`);
    core.setOutput('up-to-date', 'true');
  } else {
    core.info(`Pull request branch "${prBranch}" is not up-to-date with base branch "${baseRef}".`);
    core.setOutput('up-to-date', 'false');
  }
}

module.exports = { getPullRequestDetails, checkUpToDate };
