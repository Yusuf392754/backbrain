const { json, method } = require('./_lib/http');

module.exports = function handler(req, res) {
  if (!method(req, res, ['GET'])) return;
  return json(res, 200, {
    ok: true,
    service: 'backbrain-api',
    integrations: {
      openai: Boolean(process.env.OPENAI_API_KEY),
      stripe: Boolean(process.env.STRIPE_SECRET_KEY && process.env.STRIPE_PRICE_ID),
      authentication: Boolean(process.env.AUTH_JWKS_URL),
      anonymousDevelopmentMode: process.env.ALLOW_ANONYMOUS_API === 'true'
    }
  });
};
