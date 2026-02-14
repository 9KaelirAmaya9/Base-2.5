'use strict';

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const { fileExists, readText, parseEnv, applyToTemplate, backupFile, expandEnvContent, findUnresolvedPlaceholders } = require('./lib/envFile');
const { detectPublicIpv4 } = require('./lib/ipDetect');
const { redactEnvMap } = require('./lib/redact');
const { validateEnv, requiredCategories, normalizeEnv, normalizeDeployMode, CATEGORY } = require('./envRules');
const { isPlaceholder } = require('./lib/placeholders');
function printHelp() {
  console.log('Usage: npm run setup:complete -- [--dry-run] [--no-print]');
  console.log('');
  console.log('Validate required configuration, generate missing credentials, and render .env.');
  console.log('');
  console.log('Options:');
  console.log('  --dry-run   Validate and print planned changes without writing files');
  console.log('  --no-print  Do not print any secrets to console');
  console.log('  --help      Show this help');
}

function repoRoot() {
  return path.resolve(__dirname, '..');
}

function envBuildPath(rootDir) {
  return path.join(rootDir, '.env.build');
}

function envExamplePath(rootDir) {
  return path.join(rootDir, '.env.example');
}

function envFinalPath(rootDir) {
  return path.join(rootDir, '.env');
}

function parseArgs(argv) {
  const args = new Set(argv);
  return {
    dryRun: args.has('--dry-run'),
    noPrint: args.has('--no-print'),
    help: args.has('--help') || args.has('-h'),
  };
}

function escapeDollarsPreserveDoubles(value) {
  const s = String(value ?? '');
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (ch !== '$') {
      out += ch;
      continue;
    }

    if (s[i + 1] === '$') {
      out += '$$';
      i++;
      continue;
    }

    out += '$$';
  }
  return out;
}

function makeRandomPassword(randomBytes, lengthBytes = 18) {
  // base64url => URL-safe and reasonably user-friendly
  return randomBytes(lengthBytes).toString('base64url');
}

function createHtpasswdLine({ username, hash }) {
  return `${username}:${escapeDollarsPreserveDoubles(hash)}`;
}

function formatValidationReport(validation) {
  /** @type {Record<string, Array<{key: string, message: string}>>} */
  const byCategory = {};
  for (const it of [...validation.missing, ...validation.placeholders, ...validation.invalid]) {
    byCategory[it.category] = byCategory[it.category] ?? [];
    byCategory[it.category].push({ key: it.key, message: it.message });
  }
  return byCategory;
}

async function ensureAllowlists({ envMap, ipDetector, plannedChanges }) {
  const allowlistKeys = ['DJANGO_ADMIN_ALLOWLIST', 'FLOWER_ALLOWLIST', 'PGADMIN_ALLOWLIST'];
  const tpKey = 'TP_USER_IP_ADDRESS';
  let ip = envMap[tpKey];
  const needsAllowlists = allowlistKeys.filter((k) => isPlaceholder(envMap[k], k));
  const needsIp = isPlaceholder(ip, tpKey);

  if (!needsIp && needsAllowlists.length === 0) return;

  if (needsIp) {
    if (typeof ipDetector !== 'function') {
      plannedChanges.push({ key: tpKey, action: 'ip-detect-skipped' });
      return;
    }
    try {
      const res = await ipDetector();
      ip = res && res.ip ? String(res.ip).trim() : '';
    } catch (e) {
      plannedChanges.push({ key: tpKey, action: `ip-detect-failed:${e && e.message ? e.message : String(e)}` });
      return;
    }
    if (!ip) {
      plannedChanges.push({ key: tpKey, action: 'ip-detect-failed:empty-result' });
      return;
    }
    envMap[tpKey] = ip;
    plannedChanges.push({ key: tpKey, action: 'store-public-ip' });
  }

  for (const k of needsAllowlists) {
    envMap[k] = `\${${tpKey}}/32`;
    plannedChanges.push({ key: k, action: 'set-allowlist-template' });
  }
}

async function ensureBasicAuth({ envMap, hashPassword, randomBytes, plannedChanges }) {
  const primaryKey = 'TRAEFIK_DASH_BASIC_USERS';
  const flowerKey = 'FLOWER_BASIC_USERS';
  const pwKey = 'TRAEFIK_ACTUAL_PW';
  const flowerPwKey = 'FLOWER_ACTUAL_PW';

  const applyUserName = String(envMap.APPLY_USER_NAME_DEFAULTS ?? '').trim().toLowerCase() === 'true';
  const applyUserPassword = String(envMap.APPLY_USER_PASSWORD_DEFAULTS ?? '').trim().toLowerCase() === 'true';

  const userName = String(envMap.USER_MAIN_NAME ?? '').trim();
  const userPassword = String(envMap.USER_MAIN_PASSWORD ?? '').trim();

  const resolvedUserName = applyUserName && userName ? userName : 'admin';
  const resolvedUserPassword = applyUserPassword && userPassword ? userPassword : null;

  let primary = envMap[primaryKey];
  let generatedPassword = null;
  let generatedUser = resolvedUserName;

  if (isPlaceholder(primary, primaryKey)) {
    const password = resolvedUserPassword ?? makeRandomPassword(randomBytes);
    const hash = await hashPassword(password);
    primary = createHtpasswdLine({ username: resolvedUserName, hash });
    envMap[primaryKey] = primary;
    plannedChanges.push({ key: primaryKey, action: 'generate-basic-auth' });

    generatedPassword = password;
    if (isPlaceholder(envMap[pwKey], pwKey)) {
      envMap[pwKey] = password;
      plannedChanges.push({ key: pwKey, action: 'store-generated-password' });
    }
  } else {
    // Ensure $ is properly escaped for Compose without breaking already-escaped values.
    const escaped = escapeDollarsPreserveDoubles(primary);
    if (escaped !== primary) {
      envMap[primaryKey] = escaped;
      plannedChanges.push({ key: primaryKey, action: 'escape-dollars' });
      primary = escaped;
    }
  }

  if (isPlaceholder(envMap[flowerKey], flowerKey)) {
    let flowerPassword = generatedPassword;
    let flowerUsername = generatedUser;

    if (!flowerPassword) {
      const existingTraefikPw = envMap[pwKey];
      if (!isPlaceholder(existingTraefikPw, pwKey)) {
        flowerPassword = String(existingTraefikPw);
        const userPart = String(primary || '').split(':')[0];
        flowerUsername = userPart || resolvedUserName;
      } else if (resolvedUserPassword) {
        flowerPassword = resolvedUserPassword;
      } else {
        flowerPassword = makeRandomPassword(randomBytes);
      }
    }

    const hash = await hashPassword(flowerPassword);
    envMap[flowerKey] = createHtpasswdLine({ username: flowerUsername, hash });
    plannedChanges.push({ key: flowerKey, action: 'generate-basic-auth' });

    if (isPlaceholder(envMap[flowerPwKey], flowerPwKey)) {
      envMap[flowerPwKey] = flowerPassword;
      plannedChanges.push({ key: flowerPwKey, action: 'store-generated-password' });
    }
  }
}

function applySafeDevDefaults({ envMap, plannedChanges }) {
  const env = normalizeEnv(envMap.ENV);
  const optedIn = String(envMap.APPLY_DEV_DEFAULTS ?? '').trim().toLowerCase() === 'true';
  if (env !== 'development' || !optedIn) return;

  // Keep this list intentionally small and explicitly safe.
  if (String(envMap.DJANGO_DEBUG ?? '').trim().toLowerCase() !== 'true') {
    envMap.DJANGO_DEBUG = 'true';
    plannedChanges.push({ key: 'DJANGO_DEBUG', action: 'apply-dev-default' });
  }
}

async function defaultHashPassword(password) {
  let bcrypt;
  try {
    bcrypt = require('bcryptjs');
  } catch (e) {
    const err = new Error('Missing dependency: bcryptjs. Run: npm install');
    err.cause = e;
    throw err;
  }
  return bcrypt.hash(password, 10);
}

/**
 * @param {{
 *  rootDir?: string,
 *  argv?: string[],
 *  stdout?: Function,
 *  stderr?: Function,
 *  ipDetector?: Function,
 *  hashPassword?: (password: string) => Promise<string>,
 *  randomBytes?: (n: number) => Buffer,
 * }} options
 */
async function runCompleteSetup(options = {}) {
  const rootDir = options.rootDir ?? repoRoot();
  const argv = options.argv ?? process.argv.slice(2);
  const stdout = options.stdout ?? console.log;
  const stderr = options.stderr ?? console.error;
  const ipDetector = options.ipDetector ?? null;
  const hashPassword = options.hashPassword ?? defaultHashPassword;
  const randomBytes = options.randomBytes ?? crypto.randomBytes;

  const args = parseArgs(argv);
  if (args.help) {
    printHelp();
    return { changed: false, help: true };
  }

  const example = envExamplePath(rootDir);
  if (!fileExists(example)) {
    throw new Error('Missing .env.example (required).');
  }
  const envFile = envBuildPath(rootDir);
  if (!fileExists(envFile)) {
    throw new Error('Missing .env.build. Run: npm run setup');
  }

  const template = readText(example);
  const envText = readText(envFile);
  const envMap = parseEnv(envText);

  /** @type {Array<{key: string, action: string}>} */
  const plannedChanges = [];

  // 1) Apply safe dev defaults (only if explicitly opted in)
  applySafeDevDefaults({ envMap, plannedChanges });

  // 2) Fill allowlists from public IP when placeholders remain
  await ensureAllowlists({ envMap, ipDetector, plannedChanges });

  // 3) Generate basic-auth + apply fallback behavior
  await ensureBasicAuth({ envMap, hashPassword, randomBytes, plannedChanges });

  // 4) Validate required categories
  const validation = validateEnv(envMap);
  const report = formatValidationReport(validation);

  const required = requiredCategories({ env: envMap.ENV, deployMode: envMap.DEPLOY_MODE });
  let requiredIssues = Object.entries(report).filter(([category, items]) => required.has(category) && items.length > 0);

  const gitKeys = ['GIT_REPO', 'GIT_REPO_BRANCH'];
  const gitMissing = [];
  for (const key of gitKeys) {
    const value = envMap[key];
    if (!value || String(value).trim() === '' || isPlaceholder(value, key)) {
      gitMissing.push({ key, message: `${key} is required before setup:complete`, required: true });
    }
  }

  const deployMode = normalizeDeployMode(envMap.DEPLOY_MODE);
  const doKeys = ['DIGITAL_OCEAN_API_TOKEN', 'DIGITAL_OCEAN_SSH_KEY_ID', 'DIGITAL_OCEAN_API_SSH_KEYS'];
  const doMissing = [];
  if (deployMode === 'digitalocean') {
    for (const key of doKeys) {
      const value = envMap[key];
      if (!value || String(value).trim() === '' || isPlaceholder(value, key)) {
        doMissing.push({ key, message: `${key} is required for DigitalOcean deploys`, required: true });
      }
    }
  }

  if (gitMissing.length > 0) {
    report[CATEGORY.Core] = report[CATEGORY.Core] ?? [];
    for (const item of gitMissing) {
      report[CATEGORY.Core].push(item);
    }
    requiredIssues = requiredIssues.filter(([category]) => category !== CATEGORY.Core);
    requiredIssues.push([CATEGORY.Core, report[CATEGORY.Core]]);
  }

  if (doMissing.length > 0) {
    report[CATEGORY.Core] = report[CATEGORY.Core] ?? [];
    for (const item of doMissing) {
      report[CATEGORY.Core].push(item);
    }
    requiredIssues = requiredIssues.filter(([category]) => category !== CATEGORY.Core);
    requiredIssues.push([CATEGORY.Core, report[CATEGORY.Core]]);
  }

  // Output summary
  stdout('setup:complete report');
  stdout(`- dry-run: ${args.dryRun ? 'true' : 'false'}`);
  stdout(`- no-print: ${args.noPrint ? 'true' : 'false'}`);
  stdout(`- planned changes: ${plannedChanges.length}`);

  if (!args.noPrint && plannedChanges.length > 0) {
    const safe = redactEnvMap(envMap);
    stdout('');
    stdout('Updated values (redacted):');
    for (const ch of plannedChanges) stdout(`- ${ch.key}=${safe[ch.key] ?? ''}`);
  }

  if (requiredIssues.length > 0) {
    stdout('');
    stdout('Validation failed (required categories):');
    for (const [category, items] of requiredIssues) {
      stdout(`- ${category}:`);
      for (const it of items) stdout(`  - ${it.key}: ${it.message}`);
    }
  }

  // 5) Render final .env (unless dry-run)
  const nextEnvText = applyToTemplate(template, envMap);
  const expansionMap = { ...process.env, ...envMap };
  const expanded = expandEnvContent(nextEnvText, expansionMap);
  const unresolved = findUnresolvedPlaceholders(expanded);
  if (unresolved.length > 0) {
    stdout('');
    stdout('Validation failed (unresolved placeholders):');
    for (const item of unresolved) {
      stdout(`- ${item.key}: ${item.placeholders.join(', ')}`);
    }
    return { changed: false, plannedChanges, validation: { report, exitCode: 2 } };
  }

  const envFinalFile = envFinalPath(rootDir);
  const changed = expanded !== envText || !fileExists(envFinalFile);

  if (!args.dryRun && changed) {
    if (fileExists(envFinalFile)) {
      backupFile(envFinalFile, 'pre-complete');
    }
    fs.writeFileSync(envFinalFile, expanded, 'utf8');
    stdout('');
    stdout('✅ Rendered .env');
  } else if (args.dryRun && changed) {
    stdout('');
    stdout('ℹ dry-run: .env would be rendered');
  } else {
    stdout('');
    stdout('✅ No changes needed');
  }

  const exitCode = requiredIssues.length > 0 ? 2 : 0;
  return { changed, plannedChanges, validation: { report, exitCode } };
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    printHelp();
    return;
  }

  const res = await runCompleteSetup({ argv: args });
  if (res && res.validation && typeof res.validation.exitCode === 'number') {
    process.exitCode = res.validation.exitCode;
  }
}

if (require.main === module) {
  main().catch((e) => {
    console.error('ERROR:', e && e.message ? e.message : e);
    process.exit(1);
  });
}

module.exports = {
  runCompleteSetup,
  escapeDollarsPreserveDoubles,
};
