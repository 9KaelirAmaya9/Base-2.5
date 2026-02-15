'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { runDoctor } = require('../doctor');

test('doctor --json payload matches contract shape (basic)', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'doctor-json-'));

  // Minimal env that still fails validation (fine for shape test)
  fs.writeFileSync(
    path.join(root, '.env'),
    [
      'PROJECT_NAME=alpha',
      'ENV=development',
      'WEBSITE_DOMAIN=example.com',
      'DEPLOY_MODE=local',
      'APPLY_DEV_DEFAULTS=false',
    ].join('\n'),
    'utf8'
  );

  const { exitCode, payload } = runDoctor({
    rootDir: root,
    argv: ['--json', '--strict'],
    now: () => new Date('2020-01-01T00:00:00.000Z'),
    scan: () => [],
    check: () => ({ ok: true, message: 'ok' }),
  });

  assert.equal(typeof payload.version, 'string');
  assert.equal(payload.timestamp, '2020-01-01T00:00:00.000Z');
  assert.equal(payload.strict, true);
  assert.ok(['local', 'digitalocean', 'unknown'].includes(payload.deployMode));
  assert.ok(['development', 'staging', 'production', 'unknown'].includes(payload.env));

  assert.equal(typeof payload.ok, 'boolean');
  assert.equal(typeof payload.recommendation.command, 'string');
  assert.equal(typeof payload.recommendation.reason, 'string');

  for (const k of ['placeholders', 'missing', 'invalid', 'hardcodedIdentifiers', 'prerequisites']) {
    assert.ok(Array.isArray(payload.findings[k]), `expected findings.${k} to be an array`);
  }

  // strict mode should return nonzero because config is incomplete
  assert.equal(exitCode, 2);
});
