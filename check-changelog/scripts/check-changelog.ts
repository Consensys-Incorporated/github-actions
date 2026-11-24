// SPDX-License-Identifier: Apache-2.0
//
// Fails if a public workspace package has user-facing changes but its
// CHANGELOG.md has no entry linking the pull request. Ported from
// MetaMask/github-tools src/changelog-check.mts.
//
// Usage: node check-changelog.ts <repo-path> <base-branch> <pr-number>

import { parseChangelog } from '@metamask/auto-changelog';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import semver from 'semver';

type PackageJson = {
  workspaces?: unknown;
  private?: boolean;
  version?: string;
};

type PackageInfo = { base: string; package: string };

type ChangedPackage = PackageInfo & { newVersion?: string | undefined };

/**
 * Logs an error message in red.
 *
 * @param message - The message.
 */
function logError(message: string): void {
  console.error(`\x1b[31m${message}\x1b[0m`);
}

/**
 * Formats an unknown error.
 *
 * @param error - The error.
 * @returns Its message.
 */
function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * Runs git in the repository and returns stdout.
 *
 * @param repoPath - The repository.
 * @param args - git arguments.
 * @returns stdout, without the trailing newline.
 */
function git(repoPath: string, args: string[]): string {
  return execFileSync('git', args, {
    cwd: repoPath,
    encoding: 'utf8',
    maxBuffer: 256 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  }).replace(/\n$/u, '');
}

/**
 * Gets the workspace patterns from the root package.json (array form only).
 *
 * @param repoPath - The repository.
 * @returns The patterns, or an empty array.
 */
async function getWorkspacePatterns(repoPath: string): Promise<string[]> {
  const content = await fs.readFile(path.join(repoPath, 'package.json'), 'utf-8');
  const packageJson = JSON.parse(content) as PackageJson;
  if (!Array.isArray(packageJson.workspaces)) {
    return [];
  }
  return packageJson.workspaces as string[];
}

/**
 * Maps a file to the workspace package containing it: for each pattern with a
 * `*`, the base is the prefix before the `*` and the package directory is the
 * next path segment.
 *
 * @param filePath - Path relative to the repository root.
 * @param workspacePatterns - The workspace patterns.
 * @returns The base directory and package directory, or null.
 */
export function getPackageInfo(filePath: string, workspacePatterns: string[]): PackageInfo | null {
  for (const pattern of workspacePatterns) {
    const wildcardIndex = pattern.indexOf('*');
    if (wildcardIndex === -1) {
      continue;
    }

    const baseDir = pattern.substring(0, wildcardIndex);
    if (filePath.startsWith(baseDir)) {
      const remainingPath = filePath.substring(baseDir.length);
      const nextSlashIndex = remainingPath.indexOf('/');
      if (nextSlashIndex !== -1) {
        return { base: baseDir, package: remainingPath.substring(0, nextSlashIndex) };
      }
    }
  }
  return null;
}

/**
 * Fetches the base branch and lists the files changed since the merge base.
 *
 * @param repoPath - The repository.
 * @param baseRef - The base branch.
 * @returns Changed file paths.
 */
function getChangedFiles(repoPath: string, baseRef: string): string[] {
  try {
    git(repoPath, ['fetch', 'origin', baseRef]);
    return git(repoPath, ['diff', '--name-only', `origin/${baseRef}...HEAD`])
      .split('\n')
      .filter(Boolean);
  } catch (error) {
    logError(`Failed to get changed files: ${errorMessage(error)}`);
    throw error;
  }
}

// The package.json diff analysis keeps upstream's known quirks: the
// devDependencies block is the first `"devDependencies":` line up to the next
// line matching /^\s*\}/, and a changed line is located by its first exact
// occurrence in the diff.

type PackageJsonChanges = {
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
function getDevDependencyLines(diffOutput: string, nonVersionLines: string[]): string[] {
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
function isVersionDowngrade(oldVersion: string, newVersion: string): boolean {
  return new semver.SemVer(newVersion).compare(new semver.SemVer(oldVersion)) < 0;
}

/**
 * Classifies the changes in a package.json diff.
 *
 * @param diffOutput - Output of `git diff -U9999 <range> -- <package.json>`.
 * @returns What kinds of changes the diff contains.
 */
function analyzePackageJsonDiff(diffOutput: string): PackageJsonChanges {
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

/**
 * Classifies the changes to a package.json since the merge base.
 *
 * @param repoPath - The repository.
 * @param filePath - The package.json path.
 * @param baseRef - The base branch.
 * @returns The classification; no changes if the diff fails.
 */
function analyzePackageJsonChanges(
  repoPath: string,
  filePath: string,
  baseRef: string,
): PackageJsonChanges {
  try {
    const diff = git(repoPath, ['diff', '-U9999', `origin/${baseRef}...HEAD`, '--', filePath]);
    return analyzePackageJsonDiff(diff);
  } catch (error) {
    logError(`Failed to analyze package.json changes in ${filePath}: ${errorMessage(error)}`);
    return analyzePackageJsonDiff('');
  }
}

/**
 * Whether a package.json has `"private": true`.
 *
 * @param repoPath - The repository.
 * @param packageJsonPath - Path relative to the repository.
 * @returns True if private; false if not, or if unreadable.
 */
async function isPrivatePackage(repoPath: string, packageJsonPath: string): Promise<boolean> {
  try {
    const content = await fs.readFile(path.join(repoPath, packageJsonPath), 'utf-8');
    return (JSON.parse(content) as PackageJson).private === true;
  } catch (error) {
    logError(`Failed to check if package is private: ${errorMessage(error)}`);
    return false;
  }
}

/**
 * Throws unless the changelog section to check has an entry linking the PR.
 * The section is `packageVersion` if given (which must exist and be
 * non-empty), otherwise Unreleased.
 *
 * @param args - Arguments.
 * @param args.repoPath - The repository.
 * @param args.changelogPath - Path to CHANGELOG.md, relative to the repository.
 * @param args.prNumber - The pull request number.
 * @param args.packageVersion - The package's new version, for a version bump.
 */
async function checkChangelogFile({
  repoPath,
  changelogPath,
  prNumber,
  packageVersion,
}: {
  repoPath: string;
  changelogPath: string;
  prNumber: string;
  packageVersion?: string | null;
}): Promise<void> {
  try {
    const changelogContent = await fs.readFile(path.join(repoPath, changelogPath), 'utf-8');
    if (!changelogContent) {
      throw new Error('CHANGELOG.md is empty or missing');
    }

    const changelog = parseChangelog({
      changelogContent,
      repoUrl: '',
      shouldExtractPrLinks: true,
    });

    let releaseSection = 'Unreleased';
    if (packageVersion) {
      const versionChanges = changelog.getReleaseChanges(packageVersion);
      if (versionChanges && Object.keys(versionChanges).length > 0) {
        releaseSection = packageVersion;
      } else {
        throw new Error(
          `Could not find section for version '${packageVersion}' in the changelog ("${changelogPath}").`,
        );
      }
    }

    const changes = changelog.getReleaseChanges(releaseSection);
    const linked = Object.values(changes)
      .flat()
      .some((entry) => entry.prNumbers.includes(prNumber));
    if (!linked) {
      throw new Error(
        `There are changes made to this package that may not be reflected in the changelog ("${changelogPath}"). If the changes you've introduced are user-facing, please document them under the "${releaseSection}" section, making sure to link the entries to the current PR. If the changelog is up to date, you can bypass this check by adding the 'no-changelog' label to the PR.`,
      );
    }
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === 'ENOENT') {
      throw new Error(`CHANGELOG.md not found at ${changelogPath}`);
    }
    throw error;
  }
}

/**
 * Finds the public packages with changes that need a changelog entry.
 *
 * @param files - Changed files.
 * @param workspacePatterns - Workspace patterns.
 * @param repoPath - The repository.
 * @param baseRef - The base branch.
 * @returns The changed packages.
 */
async function getChangedPackages(
  files: string[],
  workspacePatterns: string[],
  repoPath: string,
  baseRef: string,
): Promise<ChangedPackage[]> {
  const changedPackages = new Map<string, ChangedPackage>();
  const privatePackageCache = new Map<string, boolean>();

  for (const file of files) {
    if (file.startsWith('.github/workflows/')) {
      continue;
    }

    const packageInfo = getPackageInfo(file, workspacePatterns);
    if (!packageInfo) {
      continue;
    }

    let isPrivate = privatePackageCache.get(packageInfo.package);
    if (isPrivate === undefined) {
      const packageJsonPath = path.join(packageInfo.base, packageInfo.package, 'package.json');
      isPrivate = await isPrivatePackage(repoPath, packageJsonPath);
      privatePackageCache.set(packageInfo.package, isPrivate);
    }
    if (isPrivate) {
      continue;
    }

    if (
      file.match(/\.(test|spec)\./u) ||
      file.includes('__tests__/') ||
      file.includes('/docs/') ||
      file.endsWith('CHANGELOG.md')
    ) {
      continue;
    }

    let newVersion: string | undefined;
    if (file.endsWith('package.json')) {
      const changes = analyzePackageJsonChanges(repoPath, file, baseRef);
      if (!changes.hasChanges) {
        continue;
      }
      if (changes.isVersionOnly) {
        console.log(`Skipping package.json in ${packageInfo.package} as it only contains version changes`);
        continue;
      }
      if (changes.isVersionDowngrade) {
        console.log(
          `Skipping package.json in ${packageInfo.package} as it contains a version downgrade (revert)`,
        );
        continue;
      }
      if (changes.isDevDependencyOnly) {
        console.log(
          `Skipping package.json in ${packageInfo.package} as it only contains dev dependency changes`,
        );
        continue;
      }
      if (changes.isVersionAndDevDependencyOnly) {
        console.log(
          `Skipping package.json in ${packageInfo.package} as it only contains version and dev dependency changes`,
        );
        continue;
      }
      newVersion = changes.newVersion;
    }

    const existing = changedPackages.get(packageInfo.package);
    changedPackages.set(packageInfo.package, {
      ...packageInfo,
      newVersion: existing?.newVersion ?? newVersion,
    });
  }

  return Array.from(changedPackages.values());
}

/**
 * Runs the check.
 *
 * @param argv - Command-line arguments after the script path.
 */
async function main(argv: string[]): Promise<void> {
  const [repoPath, baseRef, prNumber] = argv;
  if (!repoPath || !baseRef || !prNumber) {
    throw new Error('Usage: node check-changelog.ts <repo-path> <base-branch> <pr-number>');
  }

  const fullRepoPath = path.resolve(process.cwd(), repoPath);
  try {
    await fs.access(fullRepoPath);
  } catch {
    throw new Error(`Repository path not found: ${fullRepoPath}`);
  }

  const workspacePatterns = await getWorkspacePatterns(fullRepoPath);

  if (workspacePatterns.length === 0) {
    console.log('Running in single-repo mode - checking changelog for the entire repository...');
    await checkChangelogFile({ repoPath: fullRepoPath, changelogPath: 'CHANGELOG.md', prNumber });
    console.log('CHANGELOG.md has been correctly updated.');
    return;
  }

  console.log('Running in monorepo mode - checking changelogs for changed packages...');

  const changedFiles = getChangedFiles(fullRepoPath, baseRef);
  if (changedFiles.length === 0) {
    console.log('No changed files found. Exiting successfully.');
    return;
  }

  const changedPackages = await getChangedPackages(
    changedFiles,
    workspacePatterns,
    fullRepoPath,
    baseRef,
  );
  if (changedPackages.length === 0) {
    console.log('No package code changes detected that would require changelog updates.');
    return;
  }

  const results = await Promise.all(
    changedPackages.map(async (pkg) => {
      const changelogPath = path.join(pkg.base, pkg.package, 'CHANGELOG.md');
      try {
        await checkChangelogFile({
          repoPath: fullRepoPath,
          changelogPath,
          prNumber,
          packageVersion: pkg.newVersion ?? null,
        });
        console.log(`CHANGELOG.md for ${pkg.package} has been correctly updated.`);
        return true;
      } catch (error) {
        logError(`Changelog check failed for package ${pkg.package}: ${errorMessage(error)}`);
        return false;
      }
    }),
  );

  if (results.includes(false)) {
    throw new Error('One or more changelog checks failed');
  }
}

if (import.meta.main) {
  main(process.argv.slice(2)).catch((error: unknown) => {
    logError(errorMessage(error));
    process.exitCode = 1;
  });
}
