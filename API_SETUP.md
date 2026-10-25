# BackBrain production API setup

The static browser prototype is now wired to server-side Vercel functions. **Do not put provider secrets in `index.html`, Flutter code, or `NEXT_PUBLIC_*` variables.**

## Required Vercel environment variables

| Variable | Purpose |
|---|---|
| `APP_ORIGIN` | Exact deployed origin, e.g. `https://backbrain.example.com`; rejects unexpected browser origins for billing requests. |
| `SUPABASE_URL` | Public Supabase project URL, safe to return to the browser. |
| `SUPABASE_ANON_KEY` | Public Supabase anon key, safe only with RLS enabled; never use the service-role key in the browser. |
| `OPENAI_API_KEY` | Server-only OpenAI key used by `POST /api/ask`. |
| `OPENAI_MODEL` | Optional model override; defaults to `gpt-4o-mini`. |
| `STRIPE_SECRET_KEY` | Server-only Stripe secret key. |
| `STRIPE_PRICE_ID` | Stripe recurring Price ID for the $19/month plan. |
| `STRIPE_WEBHOOK_SECRET` | Signing secret for `POST /api/stripe/webhook`. |
| `AUTH_JWKS_URL` | JWKS URL for the identity provider that signs the browser’s RS256 access tokens. |
| `AUTH_ISSUER` | Optional issuer check for those tokens. |
| `ALLOW_ANONYMOUS_API` | Set to `true` only for a short-lived local development smoke test. Leave unset/false in production. |

Install and deploy:

```bash
npm install
npm run check
vercel env add OPENAI_API_KEY production
vercel env add STRIPE_SECRET_KEY production
vercel env add STRIPE_PRICE_ID production
vercel env add STRIPE_WEBHOOK_SECRET production
vercel env add AUTH_JWKS_URL production
vercel env add APP_ORIGIN production
vercel env add SUPABASE_URL production
vercel env add SUPABASE_ANON_KEY production
vercel --prod
```

## Endpoints

- `GET /api/health` — reports which integrations are configured, without exposing values.
- `POST /api/ask` — requires `Authorization: Bearer <identity-provider-access-token>`. Sends the question and bounded memory context to OpenAI; the key stays server-side.
- `POST /api/stripe/create-checkout-session` — requires an authenticated user and valid billing email; returns a Stripe-hosted Checkout URL.
- `GET /api/stripe/session-status?session_id=...` — verifies a Checkout return on the server.
- `POST /api/stripe/webhook` — verifies Stripe signatures. Connect this in Stripe Dashboard and persist subscription events in your database.

The browser now loads Supabase Auth from the public config endpoint and offers passwordless email-link sign-in/sign-out in Settings. Supabase persists and refreshes the session; the browser sends the resulting access token to protected API routes. Never ask users to paste tokens into BackBrain.

In Supabase Dashboard, enable email magic links and configure the production Site URL plus redirect URL. For API verification, enable asymmetric JWT signing keys and set `AUTH_JWKS_URL=https://<project-ref>.supabase.co/auth/v1/.well-known/jwks.json` and `AUTH_ISSUER=https://<project-ref>.supabase.co/auth/v1`.

## Authentication recommendation

Supabase Auth is now the selected provider. The API verifies Supabase RS256 or ES256 signatures, expiry, and issuer on every protected request. For a higher-assurance release, enable MFA/passkeys in Supabase before storing sensitive data. Do not replace this with a home-grown password table or an in-memory session map.

## Genuine E2EE boundary

The current `/api/ask` route is designed for a server-readable context and is **not** an E2EE memory sync. To market true E2EE, implement the following before syncing sensitive memories:

1. Generate a random per-user data-encryption key in the browser using Web Crypto.
2. Wrap that key with a key-encryption key derived from a user passkey/secret using a memory-hard KDF (Argon2id preferred; WebAuthn PRF when supported).
3. Store only ciphertext, non-sensitive metadata, and the wrapped key on the server.
4. Decrypt on the client; never send plaintext memories, passwords, or medical notes to the API.
5. For AI, use a deliberate “AI access” flow: locally select the minimum context, decrypt it in memory, send only that selection to a provider endpoint, and clearly disclose that the selected text leaves the device. A server cannot both answer from plaintext and honestly claim zero-knowledge E2EE.
6. Add key rotation, recovery/export, device revocation, audit logging, and independent cryptographic review.

Until this layer is implemented, keep the app’s current warning and do not store passwords or medical records.

The encrypted-record schema and RLS policies are in [`supabase/schema.sql`](supabase/schema.sql). Run that SQL in the Supabase SQL editor before adding sync. It stores ciphertext and nonces only; it does not grant the server the ability to decrypt user records.

## Stripe webhook events to persist

Persist `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, and `invoice.paid` keyed to the authenticated user/customer. Make webhook processing idempotent by storing Stripe event IDs. The client-side `isSubscribed` flag is only a display cache and must not grant access.

## Voice and wake word

The web app can use browser `SpeechRecognition` only when the browser supports it, the origin is HTTPS, and the user grants microphone access. Picovoice Porcupine is appropriate for a native Flutter wake-word experience, but its access key and trained `.ppn` model belong in the mobile build configuration. It is not a replacement for authentication or encryption.
