// Minimal backend for BackBrain's $19/month subscription.
//
// This CANNOT be avoided or merged into the Flutter app: Stripe
// requires your SECRET key to create a subscription, and a secret key
// must never sit in client-side code (mobile app binaries can be
// decompiled). This tiny server is the one piece that has to run
// somewhere other than the phone.
//
// Setup:
//   1. npm install
//   2. Create a $19/month Price in your Stripe dashboard, copy its ID
//   3. Set environment variables: STRIPE_SECRET_KEY, STRIPE_PRICE_ID
//   4. node server.js
//   5. Deploy this somewhere reachable (Render, Railway, Fly.io, a
//      small VPS — anywhere that can run Node) and point the Flutter
//      app's --dart-define=BACKBRAIN_BACKEND_URL at it.

const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();
app.use(express.json());

const PRICE_ID = process.env.STRIPE_PRICE_ID || 'price_REPLACE_ME';

app.post('/create-subscription', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'email is required' });
    }

    const customer = await stripe.customers.create({ email });

    const subscription = await stripe.subscriptions.create({
      customer: customer.id,
      items: [{ price: PRICE_ID }],
      payment_behavior: 'default_incomplete',
      payment_settings: { save_default_payment_method: 'on_subscription' },
      expand: ['latest_invoice.payment_intent'],
    });

    const clientSecret =
      subscription.latest_invoice.payment_intent.client_secret;

    res.json({
      clientSecret,
      subscriptionId: subscription.id,
      customerId: customer.id,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

const port = process.env.PORT || 4000;
app.listen(port, () => {
  console.log(`backbrain payments backend running on port ${port}`);
});
