'use strict';

const path = require('path');
const fs = require('fs');
const { spawnSync } = require('child_process');

const { fileExists, readText, parseEnv } = require('./lib/envFile');
const { scanLegacyIdentifiers } = require('./lib/legacyIdentifierScan');
const { deriveIdentifiers } = require('./lib/derived');
const { validateEnv, normalizeEnv, normalizeDeployMode, CATEGORY, requiredCategories } = require('./envRules');

function printHelp() {
  console.log('Usage: npm run doctor -- [--json] [--strict]');
  console.log('');
  console.log('Read-only readiness report for the repo configuration.');
  console.log('');
  console.log('Options:');
  console.log('  --json     Emit machine-readable JSON');
  console.log('  --strict   Exit nonzero if any required issue exists');
  console.log('  --help     Show this help');
}

function repoRoot() {
  return path.resolve(__dirname, '..');
}

function envPath(rootDir) {
  return path.join(rootDir, '.env');
}

function parseArgs(argv) {
  const args = new Set(argv);
  return {
    json: args.has('--json'),
    strict: args.has('--strict'),
    help: args.has('--help') || args.has('-h'),
  };
}

function checkCommand(command, args = ['--version']) {
  const res = spawnSync(command, args, { encoding: 'utf8' });
  if (res.error) return { ok: false, message: res.error.message };
  if (res.status !== 0) return { ok: false, message: (res.stderr || res.stdout || '').trim() || `exit ${res.status}` };
  return { ok: true, message: (res.stdout || '').trim() };
}

function makeFinding({ category, key, message, required }) {
  return { category, key, message, required: Boolean(required) };
}

function derivedConsistencyFindings(envMap) {
  const findings = [];
  if (!envMap || !envMap.PROJECT_NAME) return findings;

  let expected;
  try {
    expected = deriveIdentifiers({ projectName: envMap.PROJECT_NAME });
  } catch {
    return findings;
  }

  const checkKeys = Object.keys(expected);
  for (const key of checkKeys) {
    if (!(key in envMap)) continue;
    const actual = String(envMap[key] ?? '').trim();
    const exp = String(expected[key] ?? '').trim();
    if (!actual || !exp) continue;
    if (actual !== exp) {
      findings.push(
        makeFinding({
          category: CATEGORY.Core,
          key,
          message: `Derived identifier mismatch: expected ${key}=${exp} from PROJECT_NAME`,
          required: true,
        })
      );
    }
  }
  return findings;
}

function recommend({ hasEnv, requiredIssues, deployMode }) {
  if (!hasEnv) {
    return { command: 'npm run setup', reason: 'No .env found; create one from .env.example' };
  }
  if (requiredIssues) {
    return { command: 'npm run setup:complete', reason: 'Required configuration is incomplete or invalid' };
  }
  if (deployMode === 'digitalocean') {
    return { command: './digital_ocean/scripts/powershell/deploy.ps1', reason: 'DEPLOY_MODE=digitalocean' };
  }
  return { command: './scripts/start.sh --build', reason: 'Local run is ready' };
}

function parseTokenList(value) {
  const raw = String(value ?? '').trim();
  if (!raw) return [];
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

/**
 * @param {{
 *  rootDir?: string,
 *  argv?: string[],
 *  now?: () => Date,
 *  scan?: Function,
 *  check?: Function,
 * }} options
 */
function runDoctor(options = {}) {
  const rootDir = options.rootDir ?? repoRoot();
  const argv = options.argv ?? process.argv.slice(2);
  const now = options.now ?? (() => new Date());
  const scan = options.scan ?? ((root, tokens) => scanLegacyIdentifiers({ rootDir: root, tokens }));
  const check = options.check ?? checkCommand;

  const args = parseArgs(argv);
  if (args.help) {
    printHelp();
    return { exitCode: 0, help: true };
  }

  const envFile = envPath(rootDir);
  const hasEnv = fileExists(envFile);
  const envMap = hasEnv ? parseEnv(readText(envFile)) : {};

  const env = normalizeEnv(envMap.ENV);
  const deployMode = normalizeDeployMode(envMap.DEPLOY_MODE);

  const validation = hasEnv ? validateEnv(envMap) : { required: new Set(), missing: [], placeholders: [], invalid: [] };
  const derivedFindings = hasEnv ? derivedConsistencyFindings(envMap) : [];

  const prerequisites = [];
  const docker = check('docker');
  if (!docker.ok) {
    prerequisites.push(makeFinding({ category: CATEGORY.Other, key: 'docker', message: `Docker not available: ${docker.message}`, required: true }));
  }
  const compose = check('docker', ['compose', 'version']);
  if (!compose.ok) {
    prerequisites.push(makeFinding({ category: CATEGORY.Other, key: 'docker compose', message: `Docker Compose not available: ${compose.message}`, required: true }));
  }

  if (!hasEnv) {
    prerequisites.push(makeFinding({ category: CATEGORY.Other, key: '.env', message: '.env is missing', required: true }));
  }

  const legacyTokens = parseTokenList(envMap.LEGACY_IDENTIFIER_TOKENS ?? process.env.LEGACY_IDENTIFIER_TOKENS);
  const hardcodedIdentifiers = legacyTokens.length > 0 ? scan(rootDir, legacyTokens) : [];

  // strict evaluation: any required finding => not ok
  const requiredSet = requiredCategories({ env: envMap.ENV, deployMode: envMap.DEPLOY_MODE });
  const requiredFindingsCount =
    validation.missing.filter((f) => requiredSet.has(f.category)).length +
    validation.placeholders.filter((f) => requiredSet.has(f.category)).length +
    validation.invalid.filter((f) => requiredSet.has(f.category)).length +
    derivedFindings.length +
    prerequisites.filter((f) => f.required).length +
    (hardcodedIdentifiers.length > 0 ? 1 : 0);

  const ok = requiredFindingsCount === 0;
  const recommendation = recommend({ hasEnv, requiredIssues: !ok, deployMode });

  const payload = {
    version: '1.0',
    timestamp: now().toISOString(),
    ok,
    strict: Boolean(args.strict),
    deployMode,
    env,
    findings: {
      placeholders: validation.placeholders,
      missing: [...validation.missing, ...derivedFindings],
      invalid: validation.invalid,
      hardcodedIdentifiers,
      prerequisites,
    },
    recommendation,
  };

  const exitCode = args.strict ? (ok ? 0 : 2) : 0;
  return { exitCode, payload };
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    printHelp();
    return;
  }

  const { exitCode, payload } = runDoctor({ argv: args });

  if (args.includes('--json')) {
    process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
  } else {
    console.log(`doctor: ${payload.ok ? 'OK' : 'NOT READY'}`);
    console.log(`- ENV=${payload.env} DEPLOY_MODE=${payload.deployMode}`);
    console.log(`- hardcoded identifier matches: ${payload.findings.hardcodedIdentifiers.length}`);
    console.log(`- missing: ${payload.findings.missing.length}`);
    console.log(`- placeholders: ${payload.findings.placeholders.length}`);
    console.log(`- invalid: ${payload.findings.invalid.length}`);
    console.log(`- prerequisites: ${payload.findings.prerequisites.length}`);
    console.log('');
    console.log(`Recommendation: ${payload.recommendation.command}`);
    console.log(`Reason: ${payload.recommendation.reason}`);
  }

  process.exit(exitCode);
}

if (require.main === module) {
  main().catch((e) => {
    console.error('ERROR:', e && e.message ? e.message : e);
    process.exit(1);
  });
}

module.exports = { runDoctor };
