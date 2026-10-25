# BackBrain

BackBrain is a calm memory assistant prototype for Yusuf. It combines reminders, a personal calendar, relationships, spoken interaction, and an interactive spatial “You” knowledge graph.

## What is included

- `index.html` — Vercel-compatible web application with local persistence, calendar, reminders, people, themes, voice controls, and the interactive Canvas knowledge graph.
- `api/` — server-side Vercel functions for OpenAI, Supabase configuration/authentication boundaries, health checks, and Stripe Checkout/webhooks.
- `supabase/schema.sql` — encrypted-record tables, caregiver grants, subscription records, and Row Level Security policies.
- `backbrain-logo-mark.png` and `backbrain-logo-lockup.png` — finalized transparent logo assets.
- `BACKBRAIN_FLOWCHART.mmd` and `BACKBRAIN_FLOWCHART.png` — explanation of the speech-to-memory workflow.
- `packages/` — standalone offline builds for iPhone Safari and Lenovo Chrome.
- `API_SETUP.md` — provider setup instructions for a future connected deployment.

## Run the web app locally

The web application is dependency-free in the browser. To preview it over local HTTP:

```bash
python3 -m http.server 4173 --bind 127.0.0.1
```

Then open `http://127.0.0.1:4173/` in Chrome. Microphone features require a secure origin such as HTTPS in a real browser deployment.

For server-side API syntax checks:

```bash
npm install
npm run check
```

## Offline presentation packages

For iPhone Safari, send [`packages/backbrain-iphone-safari.zip`](packages/backbrain-iphone-safari.zip), extract it in Files, and open `BackBrain.html` in Safari. For a Lenovo computer, send [`packages/backbrain-lenovo-chrome.zip`](packages/backbrain-lenovo-chrome.zip), extract it, and open `BackBrain.html` in Google Chrome.

These local packages are personalized for Yusuf, age 13, with Aakash and Rishan as best friends, Dr. Baumfolk as doctor, Syed and Afsheen as parents, Yusra and Yunus as siblings, and studying, swim practice, and taekwondo in the schedule. They do not require a URL, account, API key, or internet connection.

## Competition demo behavior

The offline presentation builds demonstrate the interface reliably without external services. Pressing **Ask** waits eight seconds and says, “Your best friends are Aakash and Rishan.” Pressing **Start listening** waits eight seconds and says the same response. This scripted behavior is intentionally separate from the planned production speech-to-command pipeline.

## Production boundary

The production API structure is prepared for Supabase Auth, OpenAI, and Stripe. Provider credentials belong in deployment environment variables and must never be placed in the browser. The current static/local builds use browser storage and are not a secure vault, full zero-knowledge E2EE system, or multi-device synchronization service. Do not enter real passwords, medical records, payment details, or sensitive constituent information.

## Main competition technologies

The project uses HTML, CSS, JavaScript, Canvas, browser speech APIs, local state persistence, a planned Supabase authentication/database boundary, a planned server-side OpenAI route, and Vercel-compatible serverless functions. See [`API_SETUP.md`](API_SETUP.md) for the connected architecture and [`BACKBRAIN_FLOWCHART.png`](BACKBRAIN_FLOWCHART.png) for the speech-to-memory process.

## Verification

The final repository checks include JavaScript syntax validation for the frontend and API routes, ZIP integrity checks for both offline packages, and validation that the offline packages contain no external CDN dependency. The offline files are designed for presentation; full production E2EE, live multi-device sync, real speech intent extraction, background notifications, and live billing require the connected implementation work described in the setup documentation.
