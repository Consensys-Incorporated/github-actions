// SPDX-License-Identifier: Apache-2.0
//
// Bundles scripts/check-changelog.ts and the code it uses from its
// dependencies into dist/check-changelog.js, so the action runs without
// installing anything, and writes the bundled packages' licenses to
// dist/LICENSES.txt.
//
// Usage: node scripts/build.ts

import { build } from 'esbuild';
import type { Plugin } from 'esbuild';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DIST = path.join(ROOT, 'dist');

/**
 * Resolves `@metamask/auto-changelog` to its `parse-changelog.js` module
 * instead of its index, which imports the package's CLI dependencies
 * (`@yarnpkg/core`, Octokit, execa, yargs). The package's `exports` map
 * exposes only the index, so the module is located from the index's path.
 */
const parseChangelogOnly: Plugin = {
  name: 'parse-changelog-only',
  setup(pluginBuild) {
    // No `u` flag: esbuild passes the filter to Go's regexp package.
    pluginBuild.onResolve({ filter: /^@metamask\/auto-changelog$/ }, () => {
      const index = fileURLToPath(import.meta.resolve('@metamask/auto-changelog'));
      return { path: path.join(path.dirname(index), 'parse-changelog.js') };
    });
  },
};

const result = await build({
  absWorkingDir: ROOT,
  entryPoints: ['scripts/check-changelog.ts'],
  outfile: 'dist/check-changelog.js',
  bundle: true,
  platform: 'node',
  format: 'esm',
  target: 'node24',
  minify: false,
  legalComments: 'inline',
  banner: {
    js: [
      '// Generated from scripts/check-changelog.ts by `npm run build`. Do not edit.',
      '// Licenses of the bundled packages are in LICENSES.txt.',
    ].join('\n'),
  },
  plugins: [parseChangelogOnly],
  metafile: true,
  logLevel: 'warning',
});

// esbuild leaves an import it cannot resolve (e.g. a dynamic import in a try
// block) in the bundle without a warning, and the action has no
// node_modules at run time, so the bundle may import only Node built-ins.
const runtimeImports = Object.values(result.metafile.outputs).flatMap(
  (output) => output.imports,
);
const nonBuiltins = runtimeImports.filter(({ path: specifier }) => !specifier.startsWith('node:'));
if (nonBuiltins.length > 0) {
  const list = nonBuiltins.map(({ path: specifier, kind }) => `  ${specifier} (${kind})`);
  throw new Error(
    `The bundle imports modules other than node: built-ins at run time, which the action cannot load:\n${list.join('\n')}`,
  );
}

// The directories of the bundled packages, from the bundle's input paths.
const packageDirs = new Set<string>();
for (const input of Object.keys(result.metafile.inputs)) {
  const match = /^(.*node_modules\/(?:@[^/]+\/)?[^/]+)\//u.exec(input);
  if (match?.[1] !== undefined) {
    packageDirs.add(match[1]);
  }
}

const sections: string[] = [];
for (const dir of [...packageDirs].sort()) {
  const absDir = path.join(ROOT, dir);
  const manifest = JSON.parse(
    await fs.readFile(path.join(absDir, 'package.json'), 'utf8'),
  ) as { name: string; version: string; license: string };
  const licenseFiles = (await fs.readdir(absDir))
    .filter((name) => /^(?:licen[cs]e|copying)/iu.test(name))
    .sort();
  if (licenseFiles.length === 0) {
    throw new Error(`No license file found in ${dir}.`);
  }
  let section = `${manifest.name}@${manifest.version}, license: ${manifest.license}\n`;
  for (const name of licenseFiles) {
    const text = await fs.readFile(path.join(absDir, name), 'utf8');
    section += `\n--- ${name} ---\n\n${text.trimEnd()}\n`;
  }
  sections.push(section);
}

await fs.writeFile(
  path.join(DIST, 'LICENSES.txt'),
  `Licenses of the packages bundled into check-changelog.js.\n\n${sections.join(`\n${'='.repeat(78)}\n\n`)}`,
);
