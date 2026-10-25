const crypto = require('node:crypto');

function base64urlDecode(value) {
  return Buffer.from(value.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - value.length % 4) % 4), 'base64');
}

async function verifyJwt(token) {
  const jwksUrl = process.env.AUTH_JWKS_URL;
  if (!jwksUrl) return null;
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('invalid_token');
  const header = JSON.parse(base64urlDecode(parts[0]).toString('utf8'));
  const payload = JSON.parse(base64urlDecode(parts[1]).toString('utf8'));
  if (!['RS256', 'ES256'].includes(header.alg) || !header.kid) throw new Error('unsupported_token');
  const jwksResponse = await fetch(jwksUrl, { headers: { Accept: 'application/json' } });
  if (!jwksResponse.ok) throw new Error('jwks_unavailable');
  const jwks = await jwksResponse.json();
  const jwk = (jwks.keys || []).find(key => key.kid === header.kid);
  if (!jwk) throw new Error('signing_key_not_found');
  const algorithm = header.alg === 'ES256'
    ? { name: 'ECDSA', namedCurve: 'P-256' }
    : { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' };
  const publicKey = await crypto.webcrypto.subtle.importKey('jwk', jwk, algorithm, false, ['verify']);
  const verifyAlgorithm = header.alg === 'ES256'
    ? { name: 'ECDSA', hash: 'SHA-256' }
    : 'RSASSA-PKCS1-v1_5';
  const valid = await crypto.webcrypto.subtle.verify(
    verifyAlgorithm, publicKey, base64urlDecode(parts[2]),
    Buffer.from(`${parts[0]}.${parts[1]}`)
  );
  if (!valid) throw new Error('invalid_signature');
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) throw new Error('expired_token');
  if (process.env.AUTH_ISSUER && payload.iss !== process.env.AUTH_ISSUER) throw new Error('invalid_issuer');
  return payload;
}

async function requireUser(req, res, json) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!process.env.AUTH_JWKS_URL && process.env.ALLOW_ANONYMOUS_API === 'true') {
    return { sub: 'anonymous-development-user', development: true };
  }
  if (!token) { json(res, 401, { error: 'authentication_required' }); return null; }
  try {
    const user = await verifyJwt(token);
    if (!user) throw new Error('auth_not_configured');
    return user;
  } catch (error) {
    json(res, 401, { error: 'invalid_authentication', detail: error.message });
    return null;
  }
}

module.exports = { requireUser };
