# Pushlog

Pushlog is a push-up logging app being migrated from the previous native iOS
codebase to Flutter so the core experience works for iOS and Android users.

The migration target is parity with the old iOS app first, then cross-platform
enhancements. Do not delete `old_ios/` until the Flutter app has verified
replacements for the iOS-only capabilities it currently preserves.

## Product Scope

- Manual rep logging with quick actions for `+1`, `+10`, and `+25`.
- Daily, weekly, monthly, streak, best-day, and all-time totals.
- Live session flow with setup, tracking, pause, summary, save, and discard.
- Firebase sign-in with Apple and Google.
- Username claiming, friend search, friend management, and daily leaderboard.
- Firestore sync for profile, friends, and workout state.
- Daily local reminders with configurable time and rotating copy.
- JSON export and full local/cloud reset.

## Parity Targets From `old_ios/`

The old iOS implementation still owns these reference behaviors:

- ARKit TrueDepth live rep tracking.
- HealthKit workout export for saved live sessions.
- Apple Watch live workout coordination through WatchConnectivity.
- Watch-side heart-rate/workout handling.
- iCloud-era data behavior that informs the current sync expectations.

Keep `old_ios/` until those areas are implemented or intentionally replaced in
Flutter and verified on device.

## Run The App

This project contains three flavors:

```sh
flutter run --flavor development --target lib/main_development.dart
flutter run --flavor staging --target lib/main_staging.dart
flutter run --flavor production --target lib/main_production.dart
```

Firebase is configured for Android and iOS through `firebase.json`,
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, and
`lib/firebase_options.dart`.

## Verification

Run these before considering a migration slice complete:

```sh
flutter test
flutter analyze
dart run bloc_tools:bloc lint .
flutter build apk --debug --flavor development --target lib/main_development.dart
```

iOS-specific parity work also needs an iOS simulator build and real-device
checks for Apple Sign-In, Google Sign-In, HealthKit, camera access, and watch
coordination.

## Migration Plan

The active parity plan is in:

```text
docs/superpowers/plans/2026-05-30-pushlog-flutter-parity.md
```

The final migration step is deleting `old_ios/`, but only after the plan's
parity gates are complete.
