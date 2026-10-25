const ALLOWED_METHODS = ['POST', 'GET'];

function json(res, status, payload) {
  res.status(status).setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  return res.status(status).end(JSON.stringify(payload));
}

function method(req, res, allowed = ALLOWED_METHODS) {
  if (!allowed.includes(req.method)) {
    res.setHeader('Allow', allowed.join(', '));
    json(res, 405, { error: 'method_not_allowed' });
    return false;
  }
  return true;
}

function env(name, { required = true } = {}) {
  const value = process.env[name];
  if (required && !value) throw new Error(`Missing server configuration: ${name}`);
  return value;
}

function requestOrigin(req) {
  const origin = req.headers.origin;
  const configured = process.env.APP_ORIGIN;
  if (configured && origin && origin !== configured) return null;
  return origin || configured || `https://${req.headers.host}`;
}

function body(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  try { return JSON.parse(req.body || '{}'); } catch { return null; }
}

module.exports = { json, method, env, requestOrigin, body };
