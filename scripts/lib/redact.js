'use strict';

const DEFAULT_SECRET_KEYWORDS = ['SECRET', 'PASSWORD', 'TOKEN', 'KEY', 'PEPPER'];

function shouldRedact(key, secretKeywords = DEFAULT_SECRET_KEYWORDS) {
  const upper = String(key ?? '').toUpperCase();
  return secretKeywords.some((k) => upper.includes(k));
}

function redactEnvMap(envMap, secretKeywords = DEFAULT_SECRET_KEYWORDS) {
  /** @type {Record<string, string>} */
  const out = {};
  for (const [k, v] of Object.entries(envMap)) {
    if (shouldRedact(k, secretKeywords)) out[k] = '<redacted>';
    else out[k] = v;
  }
  return out;
}

module.exports = { shouldRedact, redactEnvMap, DEFAULT_SECRET_KEYWORDS };
