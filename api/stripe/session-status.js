const Stripe = require('stripe');
const { json, method, env } = require('../_lib/http');
const { requireUser } = require('../_lib/auth');

module.exports = async function handler(req, res) {
  if (!method(req, res, ['GET'])) return;
  const user = await requireUser(req, res, json);
  if (!user) return;
  const id = String(req.query?.session_id || '').trim();
  if (!id || !/^cs_[A-Za-z0-9_]+$/.test(id)) return json(res, 400, { error: 'valid_session_id_required' });
  try {
    const stripe = new Stripe(env('STRIPE_SECRET_KEY'));
    const session = await stripe.checkout.sessions.retrieve(id, { expand: ['subscription'] });
    if (session.metadata?.backbrain_user_id && session.metadata.backbrain_user_id !== user.sub && !user.development) return json(res, 403, { error: 'session_not_owned' });
    return json(res, 200, { paid: session.payment_status === 'paid', status: session.status, subscriptionStatus: session.subscription?.status || null });
  } catch (error) {
    return json(res, 500, { error: 'stripe_status_failed', detail: error.message });
  }
};
