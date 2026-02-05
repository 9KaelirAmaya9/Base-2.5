'use strict';

const path = require('path');
const fs = require('fs');

const { fileExists, readText, parseEnv, applyToTemplate, backupFile } = require('./lib/envFile');
const { deriveIdentifiers, sanitizeProjectName } = require('./lib/derived');
const { validateEnv, CATEGORY } = require('./envRules');

function repoRoot() {
  return path.resolve(__dirname, '..');
}

function envPath(rootDir) {
  return path.join(rootDir, '.env');
}

function envExamplePath(rootDir) {
  return path.join(rootDir, '.env.example');
}

function printChecklist({ envMap, stdout = console.log }) {
  const { required, missing, placeholders, invalid } = validateEnv(envMap);

  const byCategory = new Map();
  for (const c of required) byCategory.set(c, []);

  for (const item of [...missing, ...placeholders, ...invalid]) {
    const arr = byCategory.get(item.category) ?? [];
    arr.push(item);
    byCategory.set(item.category, arr);
  }

  stdout('');
  stdout('Next steps checklist (required categories):');

  const order = [CATEGORY.Core, CATEGORY.Secrets, CATEGORY.Admin, CATEGORY.Access, CATEGORY.TLS, CATEGORY.SMTP];
  for (const category of order) {
    if (!required.has(category)) continue;
    const issues = byCategory.get(category) ?? [];
    if (issues.length === 0) stdout(`- ${category}: OK`);
    else {
      stdout(`- ${category}: ${issues.length} item(s) to fix`);
      for (const it of issues) stdout(`  - ${it.key}: ${it.message}`);
    }
  }
}

/**
 * @param {{ rootDir?: string, prompt?: Function, stdout?: Function, stderr?: Function }} options
 */
async function runSetup(options = {}) {
  const rootDir = options.rootDir ?? repoRoot();
  const prompt =
    options.prompt ??
    (() => {
      try {
        // Lazy-load so unit tests can run without installed deps.
        return require('inquirer').prompt;
      } catch (e) {
        const err = new Error('Missing dependency: inquirer. Run: npm install');
        err.cause = e;
        throw err;
      }
    })();
  const stdout = options.stdout ?? console.log;
  const stderr = options.stderr ?? console.error;

  const example = envExamplePath(rootDir);
  if (!fileExists(example)) {
    stderr('ERROR: .env.example is required but was not found.');
    process.exit(2);
  }

  const envFile = envPath(rootDir);
  const hasEnv = fileExists(envFile);

  if (hasEnv) {
    const { overwrite } = await prompt([
      {
        type: 'confirm',
        name: 'overwrite',
        default: false,
        message: '.env already exists. Overwrite it (a timestamped backup will be created)?',
      },
    ]);
    if (!overwrite) {
      stdout('No changes made.');
      return { changed: false };
    }
    const backup = backupFile(envFile, 'pre-setup');
    stdout(`Backup created: ${path.basename(backup)}`);
  }

  const { projectName, websiteDomain, env, deployMode, applyDevDefaults } = await prompt([
    {
      type: 'input',
      name: 'projectName',
      message: 'Project name (lowercase letters, digits, hyphen):',
      validate: (v) => {
        try {
          sanitizeProjectName(v);
          return true;
        } catch (e) {
          return e.message;
        }
      },
    },
    {
      type: 'input',
      name: 'websiteDomain',
      message: 'Website domain (e.g. example.com):',
      validate: (v) => (String(v || '').trim() ? true : 'WEBSITE_DOMAIN is required'),
    },
    {
      type: 'list',
      name: 'env',
      message: 'Environment:',
      choices: ['development', 'staging', 'production'],
      default: 'development',
    },
    {
      type: 'list',
      name: 'deployMode',
      message: 'Deploy mode:',
      choices: [
        { name: 'Local (Docker Compose)', value: 'local' },
        { name: 'DigitalOcean', value: 'digitalocean' },
      ],
      default: 'local',
    },
    {
      type: 'confirm',
      name: 'applyDevDefaults',
      message: 'Apply safe development defaults (development only)?',
      default: true,
      when: (a) => a.env === 'development',
    },
  ]);

  const identifiers = deriveIdentifiers({ projectName });

  const templateContent = readText(example);
  const existingEnv = hasEnv ? parseEnv(readText(envFile)) : {};

  const updates = {
    ...existingEnv,
    ...identifiers,
    WEBSITE_DOMAIN: websiteDomain.trim(),
    ENV: env,
    DEPLOY_MODE: deployMode,
    APPLY_DEV_DEFAULTS: applyDevDefaults ? 'true' : 'false',
  };

  const out = applyToTemplate(templateContent, updates);
  fs.writeFileSync(envFile, out, 'utf8');

  const merged = parseEnv(out);

  stdout('✅ Wrote .env');
  printChecklist({ envMap: merged, stdout });

  stdout('');
  stdout('Recommended commands:');
  stdout('  - npm run setup:complete');
  stdout('  - npm run doctor');

  return { changed: true, envPath: envFile };
}

async function main() {
  await runSetup();
}

if (require.main === module) {
  main().catch((e) => {
    console.error('ERROR:', e && e.message ? e.message : e);
    process.exit(1);
  });
}

module.exports = { runSetup };
