'use strict';

function sanitizeProjectName(projectName) {
  const v = String(projectName ?? '').trim();
  if (!/^[a-z0-9-]+$/.test(v)) {
    throw new Error('PROJECT_NAME must match /^[a-z0-9-]+$/ (lowercase letters, digits, hyphen)');
  }
  return v;
}

function deriveIdentifiers({ projectName }) {
  const pn = sanitizeProjectName(projectName);
  return {
    PROJECT_NAME: pn,
    COMPOSE_PROJECT_NAME: pn,
    NETWORK_NAME: `${pn}_network`,
    JWT_ISSUER: pn,
    JWT_AUDIENCE: pn,
    SESSION_COOKIE_NAME: `${pn}_session`,
    CSRF_COOKIE_NAME: `${pn}_csrf`,
    DO_APP_NAME: `${pn}-app`,
    DO_REGISTRY_NAME: `${pn}-registry`,
  };
}

module.exports = { sanitizeProjectName, deriveIdentifiers };
