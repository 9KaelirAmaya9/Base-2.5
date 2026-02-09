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
  if (process.stdin && process.stdin.isTTY === false) {
    throw new Error('Interactive prompt requires a TTY. Run from an interactive terminal.');
  }
  const prompt =
    options.prompt ??
    (() => {
      try {
        // Lazy-load so unit tests can run without installed deps.
        const inquirer = require('inquirer');
        const resolved =
          inquirer.prompt ||
          (inquirer.default && inquirer.default.prompt) ||
          inquirer.default;
        if (typeof resolved !== 'function') {
          throw new Error('inquirer prompt export not found');
        }
        return resolved;
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
    stdout('==> .env already exists; asking whether to overwrite');
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

  stdout('==> Gathering required settings for .env');
  const {
    projectName,
    websiteDomain,
    userMainEmail,
    applyEmailDefaults,
    userMainPassword,
    applyPasswordDefaults,
    userMainName,
    applyUserDefaults,
    gitRepo,
    gitRepoBranch,
    env,
    deployMode,
    applyDevDefaults,
  } = await prompt([
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
      type: 'input',
      name: 'userMainEmail',
      message: 'Primary email for certs/notifications (optional):',
      validate: (v) => {
        const value = String(v || '').trim();
        if (!value) return true;
        return value.includes('@') ? true : 'Enter a valid email address or leave blank.';
      },
    },
    {
      type: 'confirm',
      name: 'applyEmailDefaults',
      message: 'Apply primary email to all email fields by default?',
      default: true,
      when: (a) => String(a.userMainEmail || '').trim() !== '',
    },
    {
      type: 'password',
      name: 'userMainPassword',
      message: 'Primary user password (optional, leave blank to set later):',
      mask: '*',
    },
    {
      type: 'confirm',
      name: 'applyPasswordDefaults',
      message: 'Apply primary password to all default password fields?',
      default: false,
      when: (a) => String(a.userMainPassword || '').trim() !== '',
    },
    {
      type: 'input',
      name: 'userMainName',
      message: 'Primary username (optional, leave blank to set later):',
    },
    {
      type: 'confirm',
      name: 'applyUserDefaults',
      message: 'Apply primary username to all default username fields?',
      default: false,
      when: (a) => String(a.userMainName || '').trim() !== '',
    },
    {
      type: 'input',
      name: 'gitRepo',
      message: 'Git repo URL (optional, used for deploy automation):',
    },
    {
      type: 'input',
      name: 'gitRepoBranch',
      message: 'Git repo branch (optional, used for deploy automation):',
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

  const emailValue = String(userMainEmail || '').trim();
  const passwordValue = String(userMainPassword || '').trim();
  const nameValue = String(userMainName || '').trim();
  const gitRepoValue = String(gitRepo || '').trim();
  const gitRepoBranchValue = String(gitRepoBranch || '').trim();

  const updates = {
    ...existingEnv,
    ...identifiers,
    WEBSITE_DOMAIN: websiteDomain.trim(),
    ENV: env,
    DEPLOY_MODE: deployMode,
    APPLY_DEV_DEFAULTS: applyDevDefaults ? 'true' : 'false',
  };

  if (typeof applyEmailDefaults === 'boolean') {
    updates.APPLY_USER_EMAIL_DEFAULTS = applyEmailDefaults ? 'true' : 'false';
  }

  if (emailValue) {
    updates.USER_MAIN_EMAIL = emailValue;
    if (applyEmailDefaults) {
      updates.TRAEFIK_CERT_EMAIL = emailValue;
      updates.DJANGO_SUPERUSER_EMAIL = emailValue;
      updates.PGADMIN_DEFAULT_EMAIL = emailValue;
      updates.DEFAULT_FROM_EMAIL = emailValue;
      updates.EMAIL_FROM = emailValue;
      updates.SEED_ADMIN_EMAIL = emailValue;
      updates.EMAIL_HOST_USER = emailValue;
      updates.EMAIL_USER = emailValue;
      updates.DO_ALERT_EMAIL = emailValue;
    }
  }

  if (typeof applyPasswordDefaults === 'boolean') {
    updates.APPLY_USER_PASSWORD_DEFAULTS = applyPasswordDefaults ? 'true' : 'false';
  }

  if (passwordValue) {
    updates.USER_MAIN_PASSWORD = passwordValue;
    if (applyPasswordDefaults) {
      updates.TP_REDIS_PASSWORD = passwordValue;
      updates.TP_POSTGRES_PASSWORD = passwordValue;
      updates.TP_PGADMIN_PASSWORD = passwordValue;
      updates.TP_DJANGO_SUPERUSER_PASSWORD = passwordValue;
      updates.TP_SEED_ADMIN_PASSWORD = passwordValue;
      updates.TP_SEED_DEMO_PASSWORD = passwordValue;
      updates.TP_FLOWER_PASSWORD = passwordValue;
      updates.TP_TRAEFIK_PASSWORD = passwordValue;
      updates.EMAIL_HOST_PASSWORD = passwordValue;
      updates.EMAIL_PASSWORD = passwordValue;
    }
  }

  if (typeof applyUserDefaults === 'boolean') {
    updates.APPLY_USER_NAME_DEFAULTS = applyUserDefaults ? 'true' : 'false';
  }

  if (nameValue) {
    updates.USER_MAIN_NAME = nameValue;
    if (applyUserDefaults) {
      updates.POSTGRES_USER = nameValue;
      updates.DB_USER = nameValue;
      updates.DJANGO_SUPERUSER_NAME = nameValue;
      updates.FLOWER_USER = nameValue;
      updates.TRAEFIK_DASH_USER = nameValue;
      updates.FLOWER_USER_NAME = nameValue;
      updates.TRAEFIK_USER_NAME = nameValue;
    }
  }

  if (gitRepoValue) {
    updates.GIT_REPO = gitRepoValue;
    updates.GIT_REMOTE = gitRepoValue;
    updates.DO_GIT_REPO = gitRepoValue;
  }

  if (gitRepoBranchValue) {
    updates.GIT_REPO_BRANCH = gitRepoBranchValue;
    updates.DO_APP_BRANCH = gitRepoBranchValue;
  }

  updates.DO_TAGS = `${projectName},automation`;

  const out = applyToTemplate(templateContent, updates);
  fs.writeFileSync(envFile, out, 'utf8');

  const merged = parseEnv(out);

  stdout('OK: Wrote .env');
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
