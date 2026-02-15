'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { parseEnv, applyToTemplate, backupFile } = require('../lib/envFile');

test('parseEnv parses simple KEY=value pairs', () => {
  const env = parseEnv('# comment\nA=1\nB=two words\n\nC=3');
  assert.equal(env.A, '1');
  assert.equal(env.B, 'two words');
  assert.equal(env.C, '3');
});

test('applyToTemplate preserves comments/order and appends missing keys', () => {
  const template = ['# Header comment', 'A=old', '', '# Section', 'B=keep'].join('\n');

  const out = applyToTemplate(template, { A: 'new', Z: 'zzz' });

  assert.match(out, /# Header comment/);
  assert.match(out, /^A=new$/m);
  assert.match(out, /^B=keep$/m);
  assert.match(out, /# Added by setup tooling/);
  assert.match(out, /^Z=zzz$/m);
});

test('backupFile writes a timestamped backup next to file', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'envfile-test-'));
  const envPath = path.join(dir, '.env');
  fs.writeFileSync(envPath, 'A=1\n', 'utf8');

  const backupPath = backupFile(envPath, 'pre-setup');

  assert.ok(fs.existsSync(backupPath));
  assert.match(path.basename(backupPath), /^\.env\.pre-setup\.\d{8}_\d{6}$/);
});
