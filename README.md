# BackBrain — handoff package

Two things in here, built together but separately runnable:

## preview.html

A single, self-contained HTML file — open it directly in a browser, no
build step, no dependencies. It's a working click-through prototype of
the app: home, timeline, calendar, people, settings, and a subscription
screen, all with real in-browser interactivity (adding/editing/confirming
reminders, calendar events, people, and a keyword-matched "ask backbrain"
you can type into or speak to via "hey backbrain" in Chrome).

**This is a parallel JS reimplementation of the UI, not a compiled output
of the Flutter app.** The two were built to look and behave the same, but
they're separate codebases. Use this one for fast UI iteration — no
Flutter toolchain needed, just edit and refresh.

## flutter-app/

The real thing — a Flutter app meant to ship, not just demo. Everything
is in `flutter-app/lib/main.dart` (one file, ~1,900 lines) plus a
required `backend/` (a small Node server — Stripe's secret key can't
live in the app itself, see `flutter-app/README.md` for why).

Fully wired to four external APIs:
- **OpenAI ChatGPT** — answers "ask backbrain" questions for real (needs
  your own API key)
- **Picovoice Porcupine** — real "hey backbrain" wake-word detection
  (needs your own account + a trained keyword file)
- **Stripe** — the $19/month subscription (needs your own account + the
  backend deployed somewhere)
- Local persistence (shared_preferences) and local notifications
  (flutter_local_notifications) — no account needed for these two.

`flutter-app/README.md` has full setup steps, all four things you need
to get yourself, and honest notes on what's still simplified (no
real caregiver-sharing sync, no activity-capture pipeline behind the
sample "moments" data, subscription status doesn't survive a
reinstall yet).

## Suggested split of labor

If you're handing pieces of this to different tools/people: **preview.html**
is the right thing to iterate on for UI/UX changes fast. **flutter-app/**
is the right thing to iterate on for real functionality, the four API
integrations, or anything that needs to actually run on a phone. Changes
made to one won't automatically show up in the other — they'd need to be
ported by hand (or by whoever/whatever is iterating).

## Continued in this handoff

The app now keeps the most recent 20 “ask backbrain” exchanges in local device storage, so recent answers remain available after an app restart. Calendar entries can also be removed from the selected day; removing an entry cancels its scheduled local notification as well. The browser preview mirrors both behaviors with localStorage-backed ask history and removable calendar rows.

The Flutter source remains the source of truth for the shipping app. Flutter is not installed in the handoff environment, so the Dart changes should be compiled with `flutter analyze` and exercised on Android/iOS after the Flutter toolchain and platform folders are generated.

## Suggested next product slice

The next substantial feature is a persisted, user-authored memory capture flow to replace the static sample moments feed. That should introduce a timestamped memory model, storage, create/edit/delete UI, and a backend sync contract before caregiver sharing is marketed as a real multi-device feature.

## Verification completed here

The browser preview JavaScript was syntax-checked after the parity changes. The Flutter code was reviewed statically and kept dependency-compatible with the existing pinned packages; full compilation remains a local Flutter-toolchain step.

## Vercel deployment

The deployable web experience is now `index.html`, a production-named copy of the self-contained browser prototype. Vercel can serve it as a static site with no build command and no environment variables. `preview.html` remains as the explicit local prototype filename, while `flutter-app/` remains the mobile source and payment backend.

The repository is configured with `vercel.json` for clean URLs and basic browser security headers. The GitHub repository is the canonical source for future Vercel deployments; the current Vercel project is being deployed directly because the available Vercel account has no team identifier for automatic Git linking.

## Web app completion pass

The Vercel-compatible web version now stores the complete mutable demo state in a versioned browser snapshot named `backbrain_state_v1`. Reminders, calendar events, people, notification and caregiver settings, mock subscription state, and ask history all survive reloads. The reset action restores the full sample state rather than only clearing one screen.

The web entry point has been exercised over local HTTP, which matches static hosting behavior: ask/answer, reminder add/edit/confirm, calendar add/delete, people add/edit/delete, settings toggles, subscription validation and cancellation, reload persistence, and reset all passed. The browser prototype and root `index.html` are kept identical to prevent deployment drift.
