'use strict';

const fs = require('fs');
const path = require('path');

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function fileExists(filePath) {
  try {
    fs.accessSync(filePath);
    return true;
  } catch {
    return false;
  }
}

/**
 * Parse env lines into a map. Comments are ignored. Does not expand ${VAR}.
 * @param {string} content
 */
function parseEnv(content) {
  /** @type {Record<string, string>} */
  const env = {};
  const lines = content.split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const m = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!m) continue;
    const key = m[1];
    const value = m[2];
    env[key] = value;
  }
  return env;
}

function timestampId(d = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function backupFile(originalPath, tag = 'bak') {
  const dir = path.dirname(originalPath);
  const base = path.basename(originalPath);
  const safeTag = String(tag || 'bak').replace(/[^A-Za-z0-9_.-]+/g, '-');
  const backupName = `${base}.${safeTag}.${timestampId()}`;
  const backupPath = path.join(dir, backupName);
  fs.copyFileSync(originalPath, backupPath);
  return backupPath;
}

/**
 * Apply key/value updates to a template env file (preserving comments/order).
 * Keys not present in the template are appended at the end.
 * @param {string} templateContent
 * @param {Record<string, string>} updates
 */
function applyToTemplate(templateContent, updates) {
  const lines = templateContent.split(/\r?\n/);
  const seen = new Set();
  const missing = [];

  const out = [];
  for (const line of lines) {
    const m = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!m) {
      out.push(line);
      continue;
    }
    const key = m[1];
    if (seen.has(key)) {
      continue;
    }
    if (Object.prototype.hasOwnProperty.call(updates, key)) {
      seen.add(key);
      out.push(`${key}=${updates[key]}`);
      continue;
    }
    seen.add(key);
    out.push(line);
  }

  for (const key of Object.keys(updates)) {
    if (!seen.has(key)) {
      missing.push(key);
    }
  }

  if (missing.length > 0) {
    if (out.length > 0 && out[out.length - 1].trim() !== '') {
      out.push('');
    }
    out.push('# Added by setup tooling');
    for (const key of missing.sort()) {
      out.push(`${key}=${updates[key]}`);
    }
  }

  return removeDuplicateTemplateHeader(out).join('\n');
}

function removeDuplicateTemplateHeader(lines) {
  const header = [
    '# ============================================',
    '# Template Defaults (Sensitive)',
    '# Edit these once; values are referenced in service sections below.',
    '# ============================================',
  ];

  const out = [];
  let lastHeaderIndex = -1;
  let sawKeySinceHeader = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    if (
      line === header[0] &&
      lines[i + 1] === header[1] &&
      lines[i + 2] === header[2] &&
      lines[i + 3] === header[3]
    ) {
      if (lastHeaderIndex >= 0 && !sawKeySinceHeader) {
        i += 3;
        continue;
      }
      lastHeaderIndex = out.length;
      sawKeySinceHeader = false;
      out.push(...header);
      i += 3;
      continue;
    }

    const m = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=/);
    if (m) {
      sawKeySinceHeader = true;
    }

    out.push(line);
  }

  return out;
}

module.exports = {
  readText,
  fileExists,
  parseEnv,
  applyToTemplate,
  backupFile,
};
