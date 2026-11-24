// SPDX-License-Identifier: Apache-2.0
//
// Run with: npm test (in check-changelog/)

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  analyzePackageJsonDiff,
  getDevDependencyLines,
  isVersionDowngrade,
} from '../scripts/package-json-diff.ts';

/**
 * Builds a `git diff -U9999` of a package.json from its lines, each prefixed
 * with ' ', '+' or '-'.
 *
 * @param lines - Diff body lines.
 * @returns The diff output.
 */
function diff(...lines: string[]): string {
  return [
    'diff --git a/packages/pub/package.json b/packages/pub/package.json',
    'index 1111111..2222222 100644',
    '--- a/packages/pub/package.json',
    '+++ b/packages/pub/package.json',
    '@@ -1,13 +1,13 @@',
    ...lines,
  ].join('\n');
}

const HEAD = [' {', '   "name": "pub",'];
const DEPS = ['   "dependencies": {', '     "some-dep": "^1.0.0"', '   },'];
const DEV_DEPS = ['   "devDependencies": {', '     "some-dev-dep": "^1.0.0"', '   }'];

describe('analyzePackageJsonDiff', () => {
  it('reports no changes for an empty diff', () => {
    assert.deepEqual(analyzePackageJsonDiff(''), {
      hasChanges: false,
      isVersionOnly: false,
      isDevDependencyOnly: false,
      isVersionAndDevDependencyOnly: false,
      isVersionDowngrade: false,
      newVersion: undefined,
    });
  });

  it('reports no changes for a diff with only headers', () => {
    assert.equal(analyzePackageJsonDiff(diff(...HEAD, ' }')).hasChanges, false);
  });

  it('detects a version-only change', () => {
    const result = analyzePackageJsonDiff(
      diff(...HEAD, '-  "version": "1.0.0",', '+  "version": "1.1.0",', ...DEPS, ...DEV_DEPS, ' }'),
    );
    assert.equal(result.isVersionOnly, true);
    assert.equal(result.newVersion, '1.1.0');
    assert.equal(result.isVersionDowngrade, false);
  });

  it('detects a version downgrade', () => {
    const result = analyzePackageJsonDiff(
      diff(
        ...HEAD,
        '-  "version": "1.1.0",',
        '+  "version": "1.0.0",',
        '   "dependencies": {',
        '-    "some-dep": "^1.0.0"',
        '+    "some-dep": "^2.0.0"',
        '   },',
        ...DEV_DEPS,
        ' }',
      ),
    );
    assert.equal(result.isVersionOnly, false);
    assert.equal(result.isVersionDowngrade, true);
  });

  it('accepts a version line without a trailing comma', () => {
    const result = analyzePackageJsonDiff(
      diff(' {', '   "name": "pub",', '-  "version": "1.0.0"', '+  "version": "2.0.0"', ' }'),
    );
    assert.equal(result.isVersionOnly, true);
    assert.equal(result.newVersion, '2.0.0');
  });

  it('detects devDependency-only changes', () => {
    const result = analyzePackageJsonDiff(
      diff(
        ...HEAD,
        '   "version": "1.0.0",',
        ...DEPS,
        '   "devDependencies": {',
        '-    "some-dev-dep": "^1.0.0"',
        '+    "some-dev-dep": "^2.0.0"',
        '   }',
        ' }',
      ),
    );
    assert.equal(result.isDevDependencyOnly, true);
    assert.equal(result.isVersionAndDevDependencyOnly, false);
    assert.equal(result.newVersion, undefined);
  });

  it('detects version and devDependency changes', () => {
    const result = analyzePackageJsonDiff(
      diff(
        ...HEAD,
        '-  "version": "1.0.0",',
        '+  "version": "1.1.0",',
        ...DEPS,
        '   "devDependencies": {',
        '-    "some-dev-dep": "^1.0.0"',
        '+    "some-dev-dep": "^2.0.0"',
        '   }',
        ' }',
      ),
    );
    assert.equal(result.isDevDependencyOnly, false);
    assert.equal(result.isVersionAndDevDependencyOnly, true);
    assert.equal(result.newVersion, '1.1.0');
  });

  it('records the new version for a version and dependencies change', () => {
    const result = analyzePackageJsonDiff(
      diff(
        ...HEAD,
        '-  "version": "1.0.0",',
        '+  "version": "1.1.0",',
        '   "dependencies": {',
        '-    "some-dep": "^1.0.0"',
        '+    "some-dep": "^2.0.0"',
        '   },',
        ...DEV_DEPS,
        ' }',
      ),
    );
    assert.equal(result.hasChanges, true);
    assert.equal(result.isVersionOnly, false);
    assert.equal(result.isDevDependencyOnly, false);
    assert.equal(result.isVersionAndDevDependencyOnly, false);
    assert.equal(result.isVersionDowngrade, false);
    assert.equal(result.newVersion, '1.1.0');
  });

  it('does not run the devDependencies block past a changed closing brace', () => {
    const result = analyzePackageJsonDiff(
      diff(
        ...HEAD,
        '   "version": "1.0.0",',
        ...DEPS,
        '   "devDependencies": {',
        '     "some-dev-dep": "^1.0.0"',
        '-  }',
        '+  },',
        '+  "files": ["dist"]',
        ' }',
      ),
    );
    assert.equal(result.isDevDependencyOnly, false);
  });

  it('treats a dependencies change as user-facing', () => {
    const result = analyzePackageJsonDiff(
      diff(
        ...HEAD,
        '   "version": "1.0.0",',
        '   "dependencies": {',
        '-    "some-dep": "^1.0.0"',
        '+    "some-dep": "^2.0.0"',
        '   },',
        ...DEV_DEPS,
        ' }',
      ),
    );
    assert.equal(result.isDevDependencyOnly, false);
    assert.equal(result.newVersion, undefined);
  });
});

describe('getDevDependencyLines', () => {
  it('returns nothing without a devDependencies block', () => {
    assert.deepEqual(getDevDependencyLines(diff(...HEAD, '+  "x": 1', ' }'), ['+  "x": 1']), []);
  });

  it('ends the block at the first closing brace', () => {
    const output = diff(
      ...HEAD,
      '   "devDependencies": {',
      '     "a": "^1.0.0"',
      '   },',
      '-  "files": []',
      '+  "files": ["dist"]',
      ' }',
    );
    assert.deepEqual(getDevDependencyLines(output, ['-  "files": []', '+  "files": ["dist"]']), []);
  });
  it('ends the block at a removed or added closing brace', () => {
    const output = diff(
      ...HEAD,
      '   "devDependencies": {',
      '-    "a": "^1.0.0"',
      '+    "a": "^2.0.0"',
      '-  }',
      '+  },',
      '+  "files": ["dist"]',
      ' }',
    );
    assert.deepEqual(
      getDevDependencyLines(output, [
        '-    "a": "^1.0.0"',
        '+    "a": "^2.0.0"',
        '-  }',
        '+  },',
        '+  "files": ["dist"]',
      ]),
      ['-    "a": "^1.0.0"', '+    "a": "^2.0.0"', '-  }'],
    );
  });
});

describe('isVersionDowngrade', () => {
  it('compares semver versions', () => {
    assert.equal(isVersionDowngrade('1.10.0', '1.9.0'), true);
    assert.equal(isVersionDowngrade('1.9.0', '1.10.0'), false);
    assert.equal(isVersionDowngrade('1.0.0', '1.0.0-rc.1'), true);
  });
});
