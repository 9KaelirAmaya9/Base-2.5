'use strict';

const PLACEHOLDER_PATTERNS = [
  /^change[_-]?me/i,
  /^your[_-]?/i,
  /_here$/i,
  /placeholder/i,
  /^example$/i,
  /bcrypt_hash_here/i,
  /generated_password_here/i,
];

function isBlank(value) {
  return value === undefined || value === null || String(value).trim() === '';
}

function isAllowlistPlaceholder(value) {
  if (isBlank(value)) return true;
  const v = String(value).trim();
  if (/your_ip_address_here/i.test(v)) return true;
  if (v === '0.0.0.0/0') return false;
  // Basic CIDR-ish validation (allow comma-separated list)
  const parts = v.split(',').map((s) => s.trim()).filter(Boolean);
  if (parts.length === 0) return true;
  const cidrRe = /^(\d{1,3}\.){3}\d{1,3}\/(\d{1,2})$/;
  for (const p of parts) {
    if (!cidrRe.test(p)) return true;
    const [ip, maskStr] = p.split('/');
    const octets = ip.split('.').map((n) => Number(n));
    if (octets.some((o) => Number.isNaN(o) || o < 0 || o > 255)) return true;
    const mask = Number(maskStr);
    if (mask < 0 || mask > 32) return true;
  }
  return false;
}

/**
 * Treat a value as placeholder/unset.
 * @param {string | undefined | null} value
 * @param {string=} key
 */
function isPlaceholder(value, key) {
  if (isBlank(value)) return true;
  const v = String(value).trim();

  if (key && /ALLOWLIST$/i.test(key)) {
    return isAllowlistPlaceholder(v);
  }

  for (const re of PLACEHOLDER_PATTERNS) {
    if (re.test(v)) return true;
  }

  // Common explicit placeholders used in env examples
  if (v === 'your' || v === 'your_username_here' || v === 'your_email_here') return true;

  return false;
}

module.exports = { isPlaceholder };
