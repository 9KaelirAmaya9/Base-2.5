'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { scanLegacyIdentifiers } = require('../lib/legacyIdentifierScan');

test('scanLegacyIdentifiers finds matches and ignores excluded paths', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'legacy-scan-test-'));

  fs.mkdirSync(path.join(root, 'docs'), { recursive: true });
  fs.writeFileSync(path.join(root, 'docs', 'readme.md'), 'Hello legacytoken world\n', 'utf8');

  fs.mkdirSync(path.join(root, 'node_modules'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'node_modules', 'ignored.txt'),
    'legacytoken should be ignored\n',
    'utf8'
  );

  const res = scanLegacyIdentifiers({ rootDir: root, tokens: ['legacytoken'] });

  assert.ok(res.some((r) => r.path === 'docs/readme.md'));
  assert.ok(!res.some((r) => r.path.startsWith('node_modules/')));
});
