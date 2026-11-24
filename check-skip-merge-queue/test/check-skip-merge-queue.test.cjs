// SPDX-License-Identifier: Apache-2.0
//
// Run with: node --test 'check-skip-merge-queue/test/*.test.cjs'

'use strict';

const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const {
  getPullRequestDetails,
  checkUpToDate,
} = require('../scripts/check-skip-merge-queue.cjs');

const context = { repo: { owner: 'octo', repo: 'repo' } };

function makeCore() {
  const core = { outputs: {}, failed: undefined, infos: [] };
  core.setOutput = (name, value) => {
    core.outputs[name] = value;
  };
  core.setFailed = (message) => {
    core.failed = message;
  };
  core.info = (message) => core.infos.push(message);
  return core;
}

function makeGithub({ pullRequest = null, status = 'identical' } = {}) {
  const calls = { graphql: [], compare: [] };
  const github = {
    graphql: async (query, variables) => {
      calls.graphql.push(variables);
      return { repository: { pullRequest } };
    },
    rest: {
      repos: {
        compareCommitsWithBasehead: async (params) => {
          calls.compare.push(params);
          return { data: { status } };
        },
      },
    },
  };
  return { github, calls };
}

const HEAD_REF = 'refs/heads/gh-readonly-queue/main/pr-123-0123456789abcdef0123456789abcdef01234567';

describe('getPullRequestDetails', () => {
  it('sets outputs for a queued pull request', async () => {
    const core = makeCore();
    const { github, calls } = makeGithub({
      pullRequest: { headRefOid: 'fedcba9876543210fedcba9876543210fedcba98', mergeQueueEntry: { position: 1 } },
    });
    await getPullRequestDetails({ github, context, core, headRef: HEAD_REF });
    assert.equal(core.failed, undefined);
    assert.deepEqual(calls.graphql, [{ owner: 'octo', name: 'repo', number: 123 }]);
    assert.deepEqual(core.outputs, {
      'pr-number': 123,
      'pr-head-sha': 'fedcba9876543210fedcba9876543210fedcba98',
      'merge-queue-position': 1,
    });
  });

  it('fails for a head ref without a pull request number', async () => {
    const core = makeCore();
    const { github, calls } = makeGithub();
    await getPullRequestDetails({ github, context, core, headRef: 'refs/heads/main' });
    assert.match(core.failed, /Could not extract pull request number/u);
    assert.equal(calls.graphql.length, 0);
    assert.deepEqual(core.outputs, {});
  });

  it('fails for an empty head ref', async () => {
    const core = makeCore();
    const { github } = makeGithub();
    await getPullRequestDetails({ github, context, core, headRef: '' });
    assert.match(core.failed, /Could not extract pull request number/u);
  });

  it('uses the last /pr-<n>-<sha> segment when the base branch contains one', async () => {
    const core = makeCore();
    const { github, calls } = makeGithub({
      pullRequest: { headRefOid: 'abc', mergeQueueEntry: { position: 1 } },
    });
    await getPullRequestDetails({
      github,
      context,
      core,
      headRef: 'refs/heads/gh-readonly-queue/hotfix/pr-7-x/pr-123-0123456789abcdef0123456789abcdef01234567',
    });
    assert.deepEqual(calls.graphql, [{ owner: 'octo', name: 'repo', number: 123 }]);
  });

  it('fails for a head ref whose pr-<n>- segment is not followed by a SHA', async () => {
    const core = makeCore();
    const { github, calls } = makeGithub();
    await getPullRequestDetails({
      github,
      context,
      core,
      headRef: 'refs/heads/gh-readonly-queue/hotfix/pr-7-x',
    });
    assert.match(core.failed, /Could not extract pull request number/u);
    assert.equal(calls.graphql.length, 0);
  });

  it('fails with a lookup message when the GraphQL call throws', async () => {
    const core = makeCore();
    const { github } = makeGithub();
    github.graphql = async () => {
      throw new Error('Could not resolve to a PullRequest with the number of 123.');
    };
    await getPullRequestDetails({ github, context, core, headRef: HEAD_REF });
    assert.match(core.failed, /Could not look up pull request #123.*Could not resolve/u);
    assert.deepEqual(core.outputs, {});
  });

  it('fails when the pull request does not exist', async () => {
    const core = makeCore();
    const { github } = makeGithub({ pullRequest: null });
    await getPullRequestDetails({ github, context, core, headRef: HEAD_REF });
    assert.match(core.failed, /not found/u);
    assert.deepEqual(core.outputs, {});
  });

  it('fails when the pull request is not in the merge queue', async () => {
    const core = makeCore();
    const { github } = makeGithub({
      pullRequest: { headRefOid: 'fedcba9876543210fedcba9876543210fedcba98', mergeQueueEntry: null },
    });
    await getPullRequestDetails({ github, context, core, headRef: HEAD_REF });
    assert.match(core.failed, /not in the merge queue/u);
    assert.deepEqual(core.outputs, { 'pr-number': 123 });
  });
});

describe('checkUpToDate', () => {
  for (const [status, expected] of [
    ['identical', 'true'],
    ['ahead', 'true'],
    ['behind', 'false'],
    ['diverged', 'false'],
  ]) {
    it(`sets up-to-date=${expected} for first in queue and status ${status}`, async () => {
      const core = makeCore();
      const { github, calls } = makeGithub({ status });
      await checkUpToDate({
        github,
        context,
        core,
        baseRef: 'main',
        prHeadSha: 'abc123',
        mergeQueuePosition: '1',
      });
      assert.deepEqual(calls.compare, [
        { owner: 'octo', repo: 'repo', basehead: 'main...abc123' },
      ]);
      assert.deepEqual(core.outputs, { 'up-to-date': expected });
    });
  }

  it('strips refs/heads/ from the base ref', async () => {
    const core = makeCore();
    const { github, calls } = makeGithub();
    await checkUpToDate({
      github,
      context,
      core,
      baseRef: 'refs/heads/release/1.x',
      prHeadSha: 'abc123',
      mergeQueuePosition: '1',
    });
    assert.deepEqual(calls.compare, [
      { owner: 'octo', repo: 'repo', basehead: 'release/1.x...abc123' },
    ]);
  });

  for (const [name, args] of [
    ['an empty base ref', { baseRef: '', prHeadSha: 'abc123' }],
    ['an empty head SHA', { baseRef: 'main', prHeadSha: '' }],
  ]) {
    it(`fails without comparing for ${name}`, async () => {
      const core = makeCore();
      const { github, calls } = makeGithub();
      await checkUpToDate({ github, context, core, mergeQueuePosition: '1', ...args });
      assert.match(core.failed, /Missing base branch/u);
      assert.equal(calls.compare.length, 0);
      assert.deepEqual(core.outputs, {});
    });
  }

  it('sets up-to-date=false without comparing when not first in queue', async () => {
    const core = makeCore();
    const { github, calls } = makeGithub();
    await checkUpToDate({
      github,
      context,
      core,
      baseRef: 'main',
      prHeadSha: 'abc123',
      mergeQueuePosition: '2',
    });
    assert.equal(calls.compare.length, 0);
    assert.deepEqual(core.outputs, { 'up-to-date': 'false' });
  });
});
