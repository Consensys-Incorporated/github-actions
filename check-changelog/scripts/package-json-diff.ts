// SPDX-License-Identifier: Apache-2.0
//
// Analysis of a `git diff -U9999` of a workspace package.json, ported from
// MetaMask/github-tools src/changelog-check.mts. Known quirks are kept: the
// devDependencies block is the first `"devDependencies":` line up to the next
// line matching /^\s*\}/, and a changed line is located by its first exact
// occurrence in the diff.

import semver from 'semver';

export type PackageJsonChanges = {
  hasChanges: boolean;
  isVersionOnly: boolean;
  isDevDependencyOnly: boolean;
  isVersionAndDevDependencyOnly: boolean;
  isVersionDowngrade: boolean;
  newVersion: string | undefined;
};

const NO_CHANGES: PackageJsonChanges = {
  hasChanges: false,
  isVersionOnly: false,
  isDevDependencyOnly: false,
  isVersionAndDevDependencyOnly: false,
  isVersionDowngrade: false,
  newVersion: undefined,
};

/**
 * Returns the changed lines that fall within the devDependencies block.
 *
 * @param diffOutput - The full diff output.
 * @param nonVersionLines - The changed lines that are not version lines.
 * @returns The lines among `nonVersionLines` inside devDependencies.
 */
export function getDevDependencyLines(diffOutput: string, nonVersionLines: string[]): string[] {
  const allLines = diffOutput.split('\n');
  const devDependencyLines: string[] = [];

  let devDependencySectionStart: number | undefined;
  let devDependencySectionEnd: number | undefined;

  for (let i = 0; i < allLines.length; i++) {
    const line = allLines[i] as string;
    if (line.includes('"devDependencies":')) {
      devDependencySectionStart = i;
    } else if (devDependencySectionStart && /^\s*\}/u.test(line)) {
      devDependencySectionEnd = i;
      break;
    }
  }

  if (devDependencySectionStart === undefined || devDependencySectionEnd === undefined) {
    return [];
  }

  for (const changeLine of nonVersionLines) {
    const lineIndex = allLines.findIndex((line) => line === changeLine);
    if (
      lineIndex !== -1 &&
      lineIndex >= devDependencySectionStart &&
      lineIndex <= devDependencySectionEnd
    ) {
      devDependencyLines.push(changeLine);
    }
  }

  return devDependencyLines;
}

/**
 * Whether going from `oldVersion` to `newVersion` is a downgrade (a revert).
 *
 * @param oldVersion - The version before the change.
 * @param newVersion - The version after the change.
 * @returns True if `newVersion` is lower.
 */
export function isVersionDowngrade(oldVersion: string, newVersion: string): boolean {
  return new semver.SemVer(newVersion).compare(new semver.SemVer(oldVersion)) < 0;
}

/**
 * Classifies the changes in a package.json diff.
 *
 * @param diffOutput - Output of `git diff -U9999 <range> -- <package.json>`.
 * @returns What kinds of changes the diff contains.
 */
export function analyzePackageJsonDiff(diffOutput: string): PackageJsonChanges {
  if (!diffOutput) {
    return { ...NO_CHANGES };
  }

  const lines = diffOutput
    .split('\n')
    .filter((line) => line.startsWith('+') || line.startsWith('-'))
    .filter((line) => !line.startsWith('+++') && !line.startsWith('---'));

  if (lines.length === 0) {
    return { ...NO_CHANGES };
  }

  const versionLines: { type: 'added' | 'removed'; version: string }[] = [];
  const nonVersionLines: string[] = [];
  let oldVersion: string | undefined;
  let newVersion: string | undefined;

  for (const line of lines) {
    const match = line.match(/^([+-])\s*"version":\s*"([^"]+)"\s*,?\s*$/u);
    if (match) {
      versionLines.push({
        type: match[1] === '+' ? 'added' : 'removed',
        version: match[2] as string,
      });
    } else {
      nonVersionLines.push(line);
    }
  }

  if (versionLines[0]?.type === 'removed' && versionLines[1]?.type === 'added') {
    oldVersion = versionLines[0].version;
    newVersion = versionLines[1].version;
  }

  const isDowngrade =
    oldVersion && newVersion ? isVersionDowngrade(oldVersion, newVersion) : false;

  if (nonVersionLines.length === 0) {
    return {
      hasChanges: true,
      isVersionOnly: true,
      isDevDependencyOnly: false,
      isVersionAndDevDependencyOnly: false,
      isVersionDowngrade: isDowngrade,
      newVersion,
    };
  }

  const devDependencyLines = getDevDependencyLines(diffOutput, nonVersionLines);
  const allNonVersionLinesAreDevDeps = devDependencyLines.length === nonVersionLines.length;

  return {
    hasChanges: true,
    isVersionOnly: false,
    isDevDependencyOnly: !newVersion && allNonVersionLinesAreDevDeps,
    isVersionAndDevDependencyOnly: newVersion !== undefined && allNonVersionLinesAreDevDeps,
    isVersionDowngrade: isDowngrade,
    newVersion,
  };
}
