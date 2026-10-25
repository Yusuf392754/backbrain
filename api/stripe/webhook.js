const Stripe = require('stripe');
const { json, method, env } = require('../_lib/http');

async function rawBody(req) {
  if (Buffer.isBuffer(req.body)) return req.body;
  if (typeof req.body === 'string') return Buffer.from(req.body);
  const chunks = [];
  for await (const chunk of req) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

module.exports = async function handler(req, res) {
  if (!method(req, res, ['POST'])) return;
  const signature = req.headers['stripe-signature'];
  if (!signature) return json(res, 400, { error: 'stripe_signature_required' });
  try {
    const stripe = new Stripe(env('STRIPE_SECRET_KEY'));
    const raw = await rawBody(req);
    const event = stripe.webhooks.constructEvent(raw, signature, env('STRIPE_WEBHOOK_SECRET'));
    // Persist these events in the production database keyed by user_id/customer_id.
    // Logging is intentionally minimal; never log payment details or raw payloads.
    console.info(`stripe_event_received type=${event.type} id=${event.id}`);
    return json(res, 200, { received: true });
  } catch (error) {
    return json(res, 400, { error: 'invalid_stripe_webhook', detail: error.message });
  }
};

module.exports.config = { api: { bodyParser: false } };
