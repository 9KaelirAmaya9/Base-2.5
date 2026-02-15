#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const specIndex = args.indexOf('--spec');
const verifyFiles = args.includes('--verify-files');
const specPath =
  specIndex >= 0 && args[specIndex + 1]
    ? args[specIndex + 1]
    : 'specs/004-scripting-update/spec.md';

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

function parseTable(lines) {
  const headerIndex = lines.findIndex((line) => line.startsWith('| Command name |'));
  if (headerIndex === -1) {
    fail('Command matrix header not found.');
  }

  const rows = [];
  for (let i = headerIndex + 2; i < lines.length; i += 1) {
    const line = lines[i];
    if (!line.startsWith('|')) {
      break;
    }
    const columns = line
      .split('|')
      .slice(1, -1)
      .map((col) => col.trim());

    if (columns.length < 7) {
      continue;
    }

    rows.push({
      command: columns[0],
      bash: columns[1],
      powershell: columns[2],
      shared: columns[3],
      flags: columns[4],
      exits: columns[5],
      notes: columns[6],
    });
  }

  return rows;
}

function hasPlaceholder(value) {
  return /populate during audit/i.test(value || '');
}

const absoluteSpecPath = path.resolve(process.cwd(), specPath);
if (!fs.existsSync(absoluteSpecPath)) {
  fail(`Spec file not found: ${absoluteSpecPath}`);
}

const content = fs.readFileSync(absoluteSpecPath, 'utf8');
const lines = content.split(/\r?\n/);
const rows = parseTable(lines);

if (rows.length === 0) {
  fail('No command matrix rows found.');
}

const errors = [];
for (const row of rows) {
  if (!row.command) {
    errors.push('Missing command name in matrix row.');
    continue;
  }
  if (!row.bash || hasPlaceholder(row.bash)) {
    errors.push(`Missing Bash entrypoint for ${row.command}.`);
  }
  if (!row.powershell || hasPlaceholder(row.powershell)) {
    errors.push(`Missing PowerShell entrypoint for ${row.command}.`);
  }

  if (verifyFiles) {
    const bashPath = row.bash && row.bash !== 'N' ? row.bash : '';
    const psPath = row.powershell && row.powershell !== 'N' ? row.powershell : '';
    if (bashPath) {
      const fullBashPath = path.resolve(process.cwd(), bashPath);
      if (!fs.existsSync(fullBashPath)) {
        errors.push(`Bash entrypoint missing on disk for ${row.command}: ${bashPath}`);
      }
    }
    if (psPath) {
      const fullPsPath = path.resolve(process.cwd(), psPath);
      if (!fs.existsSync(fullPsPath)) {
        errors.push(`PowerShell entrypoint missing on disk for ${row.command}: ${psPath}`);
      }
    }
  }
}

if (errors.length > 0) {
  errors.forEach((err) => console.error(`- ${err}`));
  process.exit(1);
}

console.log('Command matrix validation passed.');
