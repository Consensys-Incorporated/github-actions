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

import { analyzePackageJsonDiff } from './package-json-diff.ts';
import type { PackageJsonChanges } from './package-json-diff.ts';

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
  } catch (error) {
    // The checkout does not persist credentials, so this fetch fails for a
    // private repository. The checkout fetched all branches, so origin/<base>
    // is usually present already.
    try {
      git(repoPath, ['rev-parse', '--verify', '--quiet', `refs/remotes/origin/${baseRef}`]);
      console.warn(
        `::warning::Could not fetch ${baseRef}; using origin/${baseRef} from the checkout. ${errorMessage(error)}`,
      );
    } catch {
      logError(`Failed to get changed files: ${errorMessage(error)}`);
      throw error;
    }
  }

  try {
    return git(repoPath, ['-c', 'core.quotePath=false', 'diff', '--name-only', `origin/${baseRef}...HEAD`])
      .split('\n')
      .filter(Boolean);
  } catch (error) {
    logError(`Failed to get changed files: ${errorMessage(error)}`);
    throw error;
  }
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
 * Whether a file existed at the merge base and is deleted at HEAD.
 *
 * @param repoPath - The repository.
 * @param filePath - Path relative to the repository.
 * @param baseRef - The base branch.
 * @returns True if the diff since the merge base deletes the file.
 */
function isDeletedSinceBase(repoPath: string, filePath: string, baseRef: string): boolean {
  // --no-renames: a moved package must count as deleted from its old path.
  const output = git(repoPath, [
    'diff',
    '--no-renames',
    '--name-only',
    '--diff-filter=D',
    `origin/${baseRef}...HEAD`,
    '--',
    filePath,
  ]);
  return output !== '';
}

/**
 * Reads a package's visibility from its package.json.
 *
 * @param repoPath - The repository.
 * @param packageJsonPath - Path relative to the repository.
 * @returns 'missing' if the file does not exist, 'private' if it has
 * `"private": true`, otherwise 'public' (also if it can't be read or parsed).
 */
async function getPackageVisibility(
  repoPath: string,
  packageJsonPath: string,
): Promise<'missing' | 'private' | 'public'> {
  try {
    const content = await fs.readFile(path.join(repoPath, packageJsonPath), 'utf-8');
    return (JSON.parse(content) as PackageJson).private === true ? 'private' : 'public';
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === 'ENOENT') {
      return 'missing';
    }
    logError(`Failed to check if package is private: ${errorMessage(error)}`);
    return 'public';
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
  const visibilityCache = new Map<string, 'missing' | 'private' | 'public'>();

  for (const file of files) {
    if (file.startsWith('.github/workflows/')) {
      continue;
    }

    const packageInfo = getPackageInfo(file, workspacePatterns);
    if (!packageInfo) {
      continue;
    }

    // Keyed by directory: two workspace roots can hold packages with the
    // same directory name.
    const packageDir = path.join(packageInfo.base, packageInfo.package);
    let visibility = visibilityCache.get(packageDir);
    if (visibility === undefined) {
      const packageJsonPath = path.join(packageDir, 'package.json');
      visibility = await getPackageVisibility(repoPath, packageJsonPath);
      if (visibility === 'missing') {
        // Only a package deleted by this pull request is skipped. Otherwise
        // the directory was never a package: getPackageInfo maps a file to
        // the first segment after the wildcard's prefix, which is the package
        // directory only for `<root>/*` patterns (`packages/*/*` maps
        // packages/group/foo/src/x.ts to packages/group).
        if (!isDeletedSinceBase(repoPath, packageJsonPath, baseRef)) {
          throw new Error(
            `${file} maps to ${packageDir}, which has no package.json at the pull request head or the merge base. Only workspace patterns of the form <root>/* are supported.`,
          );
        }
        console.log(`Skipping ${packageDir}: its package.json was deleted`);
      }
      visibilityCache.set(packageDir, visibility);
    }
    if (visibility !== 'public') {
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
    // Only the package's manifest, not other files ending in package.json
    // (schema-package.json) or nested package.json files (test fixtures).
    if (file === path.join(packageDir, 'package.json')) {
      const changes = analyzePackageJsonChanges(repoPath, file, baseRef);
      if (!changes.hasChanges) {
        continue;
      }
      if (changes.isVersionOnly) {
        console.log(`Skipping package.json in ${packageDir} as it only contains version changes`);
        continue;
      }
      if (changes.isVersionDowngrade) {
        console.log(
          `Skipping package.json in ${packageDir} as it contains a version downgrade (revert)`,
        );
        continue;
      }
      if (changes.isDevDependencyOnly) {
        console.log(
          `Skipping package.json in ${packageDir} as it only contains dev dependency changes`,
        );
        continue;
      }
      if (changes.isVersionAndDevDependencyOnly) {
        console.log(
          `Skipping package.json in ${packageDir} as it only contains version and dev dependency changes`,
        );
        continue;
      }
      newVersion = changes.newVersion;
    }

    const existing = changedPackages.get(packageDir);
    changedPackages.set(packageDir, {
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
      const packageDir = path.join(pkg.base, pkg.package);
      const changelogPath = path.join(packageDir, 'CHANGELOG.md');
      try {
        await checkChangelogFile({
          repoPath: fullRepoPath,
          changelogPath,
          prNumber,
          packageVersion: pkg.newVersion ?? null,
        });
        console.log(`CHANGELOG.md for ${packageDir} has been correctly updated.`);
        return true;
      } catch (error) {
        logError(`Changelog check failed for package ${packageDir}: ${errorMessage(error)}`);
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
