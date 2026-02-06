'use strict';

const https = require('https');

const DEFAULT_ENDPOINTS = [
  'https://api.ipify.org',
  'https://ifconfig.me/ip',
  'https://checkip.amazonaws.com',
];

function isIpv4(value) {
  const v = String(value ?? '').trim();
  const m = v.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!m) return false;
  const nums = m.slice(1).map((n) => Number(n));
  return nums.every((n) => Number.isInteger(n) && n >= 0 && n <= 255);
}

function fetchText(url, timeoutMs = 4000) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { timeout: timeoutMs }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => resolve(data));
    });
    req.on('timeout', () => {
      req.destroy(new Error('timeout'));
    });
    req.on('error', reject);
  });
}

async function detectPublicIpv4({ endpoints = DEFAULT_ENDPOINTS } = {}) {
  const errors = [];
  for (const url of endpoints) {
    try {
      const text = await fetchText(url);
      const candidate = String(text).trim();
      if (isIpv4(candidate)) return { ip: candidate, source: url };
      errors.push(`${url}: invalid response`);
    } catch (e) {
      errors.push(`${url}: ${e && e.message ? e.message : String(e)}`);
    }
  }
  const err = new Error('Unable to detect public IPv4 from configured endpoints');
  err.details = errors;
  throw err;
}

module.exports = { detectPublicIpv4, isIpv4, DEFAULT_ENDPOINTS };
