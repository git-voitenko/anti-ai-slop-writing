#!/usr/bin/env node

import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const TARGET = join(ROOT, 'skills', 'anti-ai-slop-writing');
const SOURCES = ['SKILL.md', 'references'];
const check = process.argv.includes('--check');

function files(path) {
  if (!existsSync(path)) return [];
  if (statSync(path).isDirectory()) {
    return readdirSync(path).flatMap((name) => files(join(path, name)));
  }
  return [path];
}

function sync() {
  rmSync(TARGET, { recursive: true, force: true });
  mkdirSync(TARGET, { recursive: true });
  for (const source of SOURCES) cpSync(join(ROOT, source), join(TARGET, source), { recursive: true });
}

function validate() {
  const expected = SOURCES.flatMap((source) => files(join(ROOT, source)));
  const actual = files(TARGET);
  const expectedNames = expected.map((path) => relative(ROOT, path).replace(/^/, 'skills/anti-ai-slop-writing/')).sort();
  const actualNames = actual.map((path) => relative(ROOT, path)).sort();
  const differences = new Set([...expectedNames, ...actualNames]);
  for (const name of [...differences]) {
    const sourceName = name.replace(/^skills\/anti-ai-slop-writing\//, '');
    const source = join(ROOT, sourceName);
    const target = join(ROOT, name);
    if (!existsSync(source) || !existsSync(target) || !readFileSync(source).equals(readFileSync(target))) {
      console.error(`Codex plugin skill differs from canonical source: ${name}`);
      process.exitCode = 1;
    }
  }
}

if (check) validate();
else {
  sync();
  console.log(`Codex plugin skill synced from ${SOURCES.join(' and ')}`);
}
