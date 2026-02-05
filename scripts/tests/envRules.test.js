'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { requiredCategories, validateEnv, CATEGORY } = require('../envRules');

test('requiredCategories always includes Core/Secrets/Admin/Access', () => {
  const req = requiredCategories({ env: 'development', deployMode: 'local' });
  for (const c of [CATEGORY.Core, CATEGORY.Secrets, CATEGORY.Admin, CATEGORY.Access]) {
    assert.ok(req.has(c), `expected ${c} to be required`);
  }
  assert.ok(!req.has(CATEGORY.TLS));
  assert.ok(!req.has(CATEGORY.SMTP));
});

test('requiredCategories requires TLS/SMTP for production', () => {
  const req = requiredCategories({ env: 'production', deployMode: 'local' });
  assert.ok(req.has(CATEGORY.TLS));
  assert.ok(req.has(CATEGORY.SMTP));
});

test('requiredCategories requires TLS/SMTP for digitalocean deploy mode', () => {
  const req = requiredCategories({ env: 'development', deployMode: 'digitalocean' });
  assert.ok(req.has(CATEGORY.TLS));
  assert.ok(req.has(CATEGORY.SMTP));
});

test('validateEnv reports missing required keys and placeholders', () => {
  const envMap = {
    PROJECT_NAME: 'myproj',
    ENV: 'development',
    WEBSITE_DOMAIN: 'example.com',
    DEPLOY_MODE: 'local',

    DJANGO_SECRET_KEY: 'change_me',
    JWT_SECRET: 'real',
    TOKEN_PEPPER: 'real',

    DJANGO_SUPERUSER_NAME: 'admin',
    DJANGO_SUPERUSER_PASSWORD: '',
    DJANGO_SUPERUSER_EMAIL: 'admin@example.com',

    TRAEFIK_DASH_BASIC_USERS: 'change_me',
    DJANGO_ADMIN_ALLOWLIST: 'your_ip_address_here/32',
    FLOWER_ALLOWLIST: '1.2.3.4/32',
    PGADMIN_ALLOWLIST: '1.2.3.4/32',
  };

  const res = validateEnv(envMap);
  assert.ok(res.missing.some((m) => m.key === 'DJANGO_SUPERUSER_PASSWORD'));
  assert.ok(res.placeholders.some((p) => p.key === 'DJANGO_SECRET_KEY'));
  assert.ok(res.placeholders.some((p) => p.key === 'TRAEFIK_DASH_BASIC_USERS'));
  assert.ok(res.placeholders.some((p) => p.key === 'DJANGO_ADMIN_ALLOWLIST'));
});
