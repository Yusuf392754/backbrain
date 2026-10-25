const Stripe = require('stripe');
const { json, method, env, body, requestOrigin } = require('../_lib/http');
const { requireUser } = require('../_lib/auth');

module.exports = async function handler(req, res) {
  if (!method(req, res, ['POST'])) return;
  const user = await requireUser(req, res, json);
  if (!user) return;
  const input = body(req);
  const email = typeof input?.email === 'string' ? input.email.trim().toLowerCase() : '';
  if (!/^\S+@\S+\.\S+$/.test(email)) return json(res, 400, { error: 'valid_email_required' });
  try {
    const stripe = new Stripe(env('STRIPE_SECRET_KEY'));
    const origin = requestOrigin(req);
    if (!origin) return json(res, 403, { error: 'origin_not_allowed' });
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer_email: email,
      line_items: [{ price: env('STRIPE_PRICE_ID'), quantity: 1 }],
      success_url: `${origin}/?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/?checkout=cancelled`,
      metadata: { backbrain_user_id: user.sub || 'unknown' },
      allow_promotion_codes: true,
      billing_address_collection: 'auto'
    });
    return json(res, 200, { url: session.url, sessionId: session.id });
  } catch (error) {
    return json(res, 500, { error: 'stripe_checkout_failed', detail: error.message });
  }
};
