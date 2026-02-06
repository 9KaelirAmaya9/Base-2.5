'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_EXCLUDES = [
  '.git',
  'node_modules',
  'build',
  'dist',
  'coverage',
  'test-results',
  'local_run_logs',
  '.venv',
  'venv',
  '__pycache__',
];

function isExcludedPath(p, excludes) {
  const parts = p.split(/[\\/]+/);
  return parts.some((part) => excludes.includes(part));
}

function walkFiles(rootDir, excludes) {
  /** @type {string[]} */
  const out = [];
  const stack = [rootDir];
  while (stack.length) {
    const dir = stack.pop();
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const ent of entries) {
      const full = path.join(dir, ent.name);
      const rel = path.relative(rootDir, full);
      if (isExcludedPath(rel, excludes)) continue;
      if (ent.isDirectory()) stack.push(full);
      else if (ent.isFile()) out.push(full);
    }
  }
  return out;
}

function normalizeTokens(tokens) {
  if (!Array.isArray(tokens)) return [];
  return tokens
    .map((t) => String(t ?? '').trim())
    .filter(Boolean)
    .map((t) => t.toLowerCase());
}

function scanLegacyIdentifiers({ rootDir, tokens, excludes = DEFAULT_EXCLUDES, maxBytes = 2_000_000 } = {}) {
  if (!rootDir) throw new Error('rootDir is required');

  const needles = normalizeTokens(tokens);
  if (needles.length === 0) return [];

  /** @type {Array<{path: string, line: number, match: string}>} */
  const results = [];

  const files = walkFiles(rootDir, excludes);
  for (const filePath of files) {
    let st;
    try {
      st = fs.statSync(filePath);
    } catch {
      continue;
    }
    if (!st.isFile() || st.size > maxBytes) continue;

    let content;
    try {
      content = fs.readFileSync(filePath, 'utf8');
    } catch {
      continue; // skip binaries
    }

    const lines = content.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lower = line.toLowerCase();
      if (needles.some((n) => lower.includes(n))) {
        results.push({
          path: path.relative(rootDir, filePath).replace(/\\/g, '/'),
          line: i + 1,
          match: line.trim().slice(0, 200),
        });
      }
    }
  }

  return results;
}

module.exports = { scanLegacyIdentifiers, DEFAULT_EXCLUDES };