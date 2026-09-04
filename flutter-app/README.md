# BackBrain (Flutter app)

This folder is already a git repo with one commit on `main`, ready to push
to GitHub:

1. Create a new, empty repo on GitHub (github.com/new — **don't** check
   "add a README," this project already has one, and an extra one will
   cause the push below to conflict).
2. In this folder:
   ```
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
   git push -u origin main
   ```
   (swap in the SSH URL instead if that's how your GitHub is set up)

That's the whole thing — the commit and `.gitignore` are already in place.

Everything Dart-side is now in **one file**: `lib/main.dart` (~1,900 lines —
it's long because it's genuinely a full app: 7 screens, 4 external APIs,
local persistence, and local notifications, all in one place). This is the
app only — the marketing landing page is a separate deliverable.

## Why this isn't *literally* one file

Four things can't be merged into `lib/main.dart`, and it's worth knowing why
rather than treating it as an oversight:

- **`pubspec.yaml`** — Flutter's own config format; there's no way to
  declare dependencies from inside a `.dart` file.
- **`assets/hey_backbrain.ppn`** — a trained binary wake-word model from
  Picovoice's console. Code can't generate this; it has to be downloaded.
- **`backend/server.js`** — a Node server holding your Stripe *secret* key.
  This is the one truly unavoidable split: Stripe subscriptions require a
  secret key to create, and a secret key can never sit inside a mobile app's
  code (the binary can be decompiled and the key extracted). Every real app
  that takes payments has this same split, not just this one.
- The generated `android/`, `ios/`, etc. folders from `flutter create` —
  standard for any Flutter project, not specific to this app.

## What's in main.dart

Roughly in file order: app entry + navigation, theme, data models
(`InboxItem`, `CalendarEvent`, `Person`, etc.), a time-parsing helper,
`StorageService` (persistence), `NotificationService` (local reminders),
`ChatService` (OpenAI), `PaymentService` (Stripe), `VoiceService`
(Picovoice + speech-to-text), `AppState` (all app logic, in one
`ChangeNotifier`), then the 7 screens and 2 small reusable widgets.

## Setup

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Inside this folder:
   ```
   flutter create --project-name backbrain --org com.yourteam .
   ```
   This adds `android/`, `ios/`, etc. around your existing `lib/main.dart`,
   `pubspec.yaml`, and `assets/` — say yes if it asks to overwrite anything.
3. ```
   flutter pub get
   ```
4. Permissions — **Android** (`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`):
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```
   **iOS** (`ios/Runner/Info.plist`):
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>BackBrain listens for "hey backbrain" so you can ask it things.</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>BackBrain uses speech recognition to understand your questions.</string>
   ```
5. Get the four things below, then run with all four keys:
   ```
   flutter run \
     --dart-define=OPENAI_API_KEY=sk-... \
     --dart-define=PICOVOICE_ACCESS_KEY=... \
     --dart-define=STRIPE_PUBLISHABLE_KEY=pk_... \
     --dart-define=BACKBRAIN_BACKEND_URL=https://your-deployed-backend.com
   ```

## The four things you need to get yourself

| # | What | Where | Cost |
|---|------|-------|------|
| 1 | OpenAI API key | platform.openai.com/api-keys | paid, per request |
| 2 | Picovoice AccessKey + a custom "hey backbrain" `.ppn` file (replace the placeholder at `assets/hey_backbrain.ppn`) | console.picovoice.ai | free tier available |
| 3 | Stripe publishable key + a $19/month Price | dashboard.stripe.com | free to set up, Stripe takes a cut per transaction |
| 4 | The payments backend running somewhere | deploy `backend/` (Render, Railway, Fly.io, a VPS — anywhere that runs Node) | hosting cost, often free tier |

**Never hardcode any of these directly into `lib/main.dart`.** CAC
submissions are often public GitHub repos — a key sitting in plain text
means anyone who finds the repo can spend money on your account. All four
are wired to read from `--dart-define` flags instead, and the app tells you
plainly if one's missing rather than silently failing.

## What's real vs. what's still a simplification

**Fully real:** persistence (shared_preferences), local notifications,
the calendar (real dates, week navigation), the people directory,
onboarding, settings, "ask backbrain" via actual ChatGPT, "hey backbrain"
via actual Picovoice wake-word detection, and Stripe subscriptions via
an actual PaymentIntent flow.

**Still simplified, worth knowing:**
- "Sarah's day" / the moments feed is sample data — no real
  activity-capture pipeline behind it.
- Caregiver sharing is a toggle with no real second-device sync — that
  needs the backend to grow beyond just handling payments (e.g. storing
  the actual app data too, not just Stripe subscriptions).
- The subscription state lives only on the device (`shared_preferences`)
  — reinstalling the app currently means re-subscribing, since nothing
  checks "does this email already have an active Stripe subscription"
  on launch. A production version would have the backend look that up.

## Package version note

Six external packages here (`speech_to_text`, `flutter_tts`,
`flutter_local_notifications`, `porcupine_flutter`, `flutter_stripe`,
`http`) each version independently and occasionally change their APIs.
This was written against the versions pinned in `pubspec.yaml`. If
`flutter pub get` pulls something newer and a call doesn't compile, it's
almost always a small, one-line fix — check that package's current docs.

## Continuation notes

The current source persists the latest 20 ask/answer exchanges locally, allowing the home screen to show recent answers after an app restart. Calendar entries now include a delete action; deleting one also cancels its matching local notification. The browser prototype in the parent folder mirrors these two behaviors.

Full Dart compilation still requires the Flutter SDK and generated platform folders. After running `flutter create --project-name backbrain --org com.yourteam .`, use `flutter analyze` and `flutter test` before targeting a device.
