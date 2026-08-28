# Pushlog

Pushlog is a focused push-up training app for iOS and Android. It turns a
longer-term goal into an adjustable training plan, keeps daily logging fast,
and adds optional competition without turning the workout into a noisy game.

The Flutter app is now the primary product. It uses a Cloudflare Worker and D1
for application data, while Firebase remains responsible for authentication
and native messaging.

## Current Standing

| Area | Current state |
| --- | --- |
| Flutter client | Active primary client at `1.1.0+22`, with development, staging, and production flavors. |
| Product flows | Training-plan onboarding, Today, History, Friends, You, reminders, export, reset, manual logging, and counted sessions are implemented. |
| Application data | The client reads and writes profiles, workouts, friends, leaderboards, devices, and notifications through the Workers API backed by D1. It does not use Firestore at runtime. |
| Backend environment | Internal testing uses `pushlog-api-staging` / `pushlog-staging`. Production uses the isolated `pushlog-api` / `pushlog-production` resources. |
| Firebase | Firebase Auth issues identity tokens. Firebase Messaging remains available for native push delivery; Firestore is retained only as a historical migration source. |
| iOS platform work | Flutter-to-native bridges exist for HealthKit workout export, ARKit/TrueDepth rep tracking, and WatchConnectivity. These capabilities still require real-device acceptance after relevant changes. |
| Android platform work | Manual logging and manual counted sessions are supported. The app reports iOS-only camera, HealthKit, and watch capabilities as unavailable instead of presenting false parity. |
| Apple Watch | The Flutter iPhone host contains the WatchConnectivity bridge, but the replacement watchOS app is not embedded in the current Runner project. The old watch source remains the reference implementation. |
| Legacy iOS app | `old_ios/` is intentionally retained until Flutter parity and device verification are complete. |
| Distribution | Repository state, CI configuration, store uploads, internal testing, and real-device behavior are separate proof layers. Confirm live TestFlight and Google Play status independently. |

## Product Scope

- Guided onboarding for different ability levels, goals, schedules, and
  coaching styles.
- Adjustable 8-, 12-, or 16-week training plans with planned rest days and
  periodic reassessment.
- Quick manual logging, including suggested sets and `+1`, `+10`, and `+25`
  actions.
- Counted sessions with setup, tracking, pause, summary, save, and discard
  states.
- Daily, weekly, monthly, streak, best-day, and all-time progress.
- Apple and Google sign-in, username claiming, friend requests, search, and
  daily, weekly, and all-time leaderboards.
- Training-day reminders and competition notification events.
- JSON export plus local, cloud, and account reset controls.

The product direction is documented in [`PRODUCT.md`](PRODUCT.md). The visual
system is documented in [`DESIGN.md`](DESIGN.md).

## Architecture

The app keeps a local workout snapshot for fast startup and offline continuity.
Signed-in data is merged with the remote snapshot through the Workers API.

| Layer | Responsibility |
| --- | --- |
| Flutter | UI, Bloc state, training plans, local preferences, offline workout snapshot, reminders, and platform-service adapters. |
| Firebase Auth | Apple and Google identity plus Firebase ID tokens used to authorize API requests. |
| Cloudflare Worker | Authenticated profile, friend, workout, device, notification, leaderboard, and account APIs. |
| D1 | Profiles, usernames, workout snapshots and sessions, scores, friendships, devices, notification events, and migration records. |
| Firebase Messaging | Native push transport. The D1 notification inbox works without an FCM gateway; immediate background delivery is optional. |

Every `/v1/*` request uses the verified Firebase token UID as its owner. The
Worker does not trust a UID supplied in a request body.

Development and staging use:

```text
https://pushlog-api-staging.imngonii.workers.dev
```

Production uses:

```text
https://pushlog-api.imngonii.workers.dev
```

Override it for another environment with:

```sh
--dart-define=PUSHLOG_API_URL=https://example.workers.dev
```

## Run the App

The repository currently targets Dart `3.11` and Flutter `3.41` or newer
compatible releases.

Install dependencies:

```sh
flutter pub get
```

Run a flavor:

```sh
flutter run --flavor development --target lib/main_development.dart
flutter run --flavor staging --target lib/main_staging.dart
flutter run --flavor production --target lib/main_production.dart
```

Firebase Auth and Messaging are configured through `firebase.json`, the
platform service files, and `lib/firebase_options.dart`. Each entry point picks
its matching Workers environment unless `PUSHLOG_API_URL` overrides it.

## Run the Backend Locally

The Worker lives in `cloudflare-rs/` (Rust, on Cloudflare Workers over D1).

```sh
cd cloudflare-rs
npm install
npm run db:migrate:local
cargo fmt --all -- --check
cargo clippy --lib --all-targets -- -D warnings
cargo test --lib
npm run dev
```

Staging migration and deployment are explicit operations:

```sh
npm run db:migrate:staging
npm run deploy:staging
```

Do not treat a local migration, build, or test result as proof that staging or
production was deployed.

## Verification

The current source passes `flutter analyze`, Bloc lint across 88 files, 58
Flutter tests, the Rust worker's Clippy gate, and its unit test suite. Re-run
the complete gate after changes:

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
dart run bloc_tools:bloc lint .
flutter build apk --debug --flavor development --target lib/main_development.dart
cd cloudflare-rs
cargo clippy --lib --all-targets -- -D warnings
cargo test --lib
```

The GitHub Actions workflow runs formatting, analysis, and Flutter tests on a
self-hosted runner. Xcode Cloud manifests and a post-clone script are present,
but CI configuration alone does not prove a current successful archive or
store upload.

iOS platform changes also need:

- an iOS simulator build;
- Apple and Google sign-in checks on a physical device;
- HealthKit authorization and saved-workout verification;
- TrueDepth pre-flight, tracking-loss, pause, and manual-fallback checks;
- Apple Watch launch, workout ownership, heart-rate, save, and discard checks;
- notification checks in foreground, background, and terminated states.

Android changes need an emulator or device check for authentication, manual
sessions, reminders, notifications, data sync, and honest unavailable states
for iOS-only capabilities.

## Migration Boundaries

### Firestore to D1

The Flutter client has completed the direct Workers/D1 cutover. The recorded
staging migration reconciled all 41 historical Firestore source documents with
D1 checksums. Keep Firestore as a read-only historical archive until internal
builds pass profile, friend, workout, account-deletion, and notification
acceptance against the intended D1 environment.

See [`docs/migrations/FIRESTORE_TO_D1.md`](docs/migrations/FIRESTORE_TO_D1.md)
for the inventory, backfill, reconciliation, and recovery procedures.

### Native iOS parity

The Flutter iOS host now contains native HealthKit, TrueDepth, and
WatchConnectivity implementations. `old_ios/` still preserves the reference
native app and watch app behavior. Delete it only after the Flutter client and
an embedded replacement watch target have passed the real-device parity gates,
or after those capabilities are explicitly removed from product scope.

The older implementation plan in
[`docs/superpowers/plans/2026-05-30-pushlog-flutter-parity.md`](docs/superpowers/plans/2026-05-30-pushlog-flutter-parity.md)
is useful as historical context, but some architecture notes predate the
Workers/D1 cutover. The current source and this README are authoritative for
the present architecture.

## Repository Map

```text
lib/                 Flutter product, state, services, and platform adapters
test/                Flutter unit and widget tests
cloudflare-rs/       Rust Workers API, D1 migrations, and tests
ios/Runner/          Current iOS host and native platform bridges
android/             Current Android host and flavor configuration
old_ios/             Legacy native iOS and watchOS parity reference
docs/migrations/     Backend migration and recovery documentation
docs/superpowers/    Historical implementation plans
```
