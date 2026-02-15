#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_ROOTS = ['scripts', '.specify/scripts', 'digital_ocean/scripts'];
const DEFAULT_ALLOWLIST = 'scripts/allowlists/remote-linux-payloads.txt';
const DEFAULT_ALLOWLIST_CONTEXTS = [
  'digital_ocean/scripts/python/orchestrate_deploy.py',
  'digital_ocean/scripts/powershell/deploy.ps1',
];

function parseArgs(args) {
  const out = {
    roots: null,
    allowlist: null,
    allowlistContexts: null,
    help: false,
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === '--help' || arg === '-h') {
      out.help = true;
    } else if (arg === '--roots') {
      const next = args[i + 1];
      if (next) {
        out.roots = next
          .split(',')
          .map((value) => value.trim())
          .filter(Boolean);
        i += 1;
      }
    } else if (arg === '--allowlist') {
      const next = args[i + 1];
      if (next) {
        out.allowlist = next;
        i += 1;
      }
    } else if (arg === '--allowlist-contexts') {
      const next = args[i + 1];
      if (next) {
        out.allowlistContexts = next
          .split(',')
          .map((value) => value.trim())
          .filter(Boolean);
        i += 1;
      }
    }
  }

  return out;
}

function printUsage() {
  console.log('Usage: node scripts/guard-shell-parity.js [options]');
  console.log('');
  console.log('Options:');
  console.log('  --roots <paths>              Comma-separated root paths to scan');
  console.log('  --allowlist <path>           Allowlist file path');
  console.log('  --allowlist-contexts <paths> Comma-separated file paths where allowlist applies');
  console.log('  --help, -h                   Show help');
}

function loadAllowlist(filePath) {
  if (!fs.existsSync(filePath)) {
    return [];
  }
  const raw = fs.readFileSync(filePath, 'utf8');
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .filter((line) => !line.startsWith('#'));
}

function matchesPattern(pattern, line) {
  if (pattern.includes('*') || pattern.includes('?')) {
    const escaped = pattern
      .replace(/[.+^${}()|[\]\\]/g, '\\$&')
      .replace(/\*/g, '.*')
      .replace(/\?/g, '.');
    const regex = new RegExp(escaped);
    return regex.test(line);
  }
  return line.includes(pattern);
}

function isAllowlisted(line, filePath, allowlistPatterns, allowlistContexts) {
  if (!allowlistContexts.has(filePath)) {
    return false;
  }
  return allowlistPatterns.some((pattern) => matchesPattern(pattern, line));
}

function shouldSkipDir(name) {
  return ['.git', 'node_modules', '.venv', 'venv', 'dist', 'build', 'coverage'].includes(name);
}

function walk(dirPath, files, includeFixtures, fixtureRoot) {
  if (!includeFixtures && dirPath.startsWith(fixtureRoot)) {
    return;
  }
  let entries = [];
  try {
    entries = fs.readdirSync(dirPath, { withFileTypes: true });
  } catch {
    return;
  }

  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      if (shouldSkipDir(entry.name)) {
        continue;
      }
      walk(fullPath, files, includeFixtures, fixtureRoot);
    } else if (entry.isFile()) {
      const ext = path.extname(entry.name).toLowerCase();
      if (ext === '.ps1' || ext === '.sh') {
        files.push(fullPath);
      }
    }
  }
}

function isCommentLine(line) {
  const trimmed = line.trim();
  return trimmed.length === 0 || trimmed.startsWith('#');
}

function detectPsViolation(line) {
  if (isCommentLine(line)) {
    return null;
  }
  const hasSh = line.toLowerCase().includes('.sh');
  if (!hasSh) {
    return null;
  }
  const usesShell = /(^|[;&|]\s*|&\s*)(bash|sh)\b/i.test(line);
  const directCall = /&\s*[^#]*\.sh\b/i.test(line);
  if (usesShell || directCall) {
    return 'ps_calls_sh';
  }
  return null;
}

function detectShViolation(line) {
  if (isCommentLine(line)) {
    return null;
  }
  const hasPs = line.toLowerCase().includes('.ps1');
  if (!hasPs) {
    return null;
  }
  const usesPwsh = /\b(pwsh|powershell)\b/i.test(line);
  const directCall = /(^|[;&|])\s*\.\/[^\s"']+\.ps1\b/i.test(line);
  if (usesPwsh || directCall) {
    return 'sh_calls_ps';
  }
  return null;
}

function collectViolations(files, allowlistPatterns, allowlistContexts, repoRoot) {
  const violations = [];
  for (const filePath of files) {
    let content = '';
    try {
      content = fs.readFileSync(filePath, 'utf8');
    } catch {
      continue;
    }

    const ext = path.extname(filePath).toLowerCase();
    const lines = content.split(/\r?\n/);

    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i];
      const type = ext === '.ps1' ? detectPsViolation(line) : detectShViolation(line);
      if (!type) {
        continue;
      }

      if (isAllowlisted(line, filePath, allowlistPatterns, allowlistContexts)) {
        continue;
      }

      const relPath = path.relative(repoRoot, filePath);
      violations.push({
        filePath: relPath,
        lineNumber: i + 1,
        type,
        line: line.trim(),
      });
    }
  }
  return violations;
}

const options = parseArgs(process.argv.slice(2));
if (options.help) {
  printUsage();
  process.exit(0);
}

const repoRoot = process.cwd();
const roots = (options.roots || DEFAULT_ROOTS).map((root) => path.resolve(repoRoot, root));
const allowlistPath = path.resolve(repoRoot, options.allowlist || DEFAULT_ALLOWLIST);
const allowlistContexts = new Set(
  (options.allowlistContexts || DEFAULT_ALLOWLIST_CONTEXTS)
    .map((filePath) => path.resolve(repoRoot, filePath))
    .map((filePath) => path.normalize(filePath))
);
const allowlistPatterns = loadAllowlist(allowlistPath);

const fixtureRoot = path.resolve(repoRoot, 'scripts/tests/fixtures');
const includeFixtures = roots.some((root) => root.startsWith(fixtureRoot));

const files = [];
for (const root of roots) {
  if (fs.existsSync(root)) {
    walk(root, files, includeFixtures, fixtureRoot);
  }
}

const violations = collectViolations(files, allowlistPatterns, allowlistContexts, repoRoot);
if (violations.length > 0) {
  for (const violation of violations) {
    console.log(
      `${violation.filePath}:${violation.lineNumber} | ${violation.type} | ${violation.line}`
    );
  }
  process.exit(1);
}

process.exit(0);
