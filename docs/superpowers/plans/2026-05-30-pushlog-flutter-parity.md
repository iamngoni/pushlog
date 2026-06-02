# Pushlog Flutter Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter app to functional parity with the previous native iOS app, add cross-platform guardrails for Android, then delete `old_ios` only after parity is proven.

**Architecture:** Keep Flutter as the product shell and shared domain layer. Use focused platform services for capabilities that cannot be shared directly, starting with HealthKit and later adding ARKit face tracking and WatchConnectivity through iOS method/event channels while Android receives honest availability states and manual/live-session fallbacks.

**Tech Stack:** Flutter, Bloc, Firebase Auth, Cloud Firestore, SharedPreferences, local notifications, Share Plus, iOS Swift platform channels, HealthKit, ARKit, WatchConnectivity.

---

## File Structure

- `lib/app.dart`: canonical app root; remove generated counter routing and keep auth-gated root.
- `lib/app/view/app.dart`: remove generated counter app root.
- `lib/counter/**`: remove generated sample code and tests once no imports reference it.
- `lib/workout/models/data/**`: make sessions the durable source of truth and normalize derived totals.
- `lib/workout/state/workout/**`: keep all workout mutations routed through events; make handlers private.
- `lib/platform/**`: add platform capability services for health, live tracking, and watch state.
- `lib/live/views/live_session_page.dart`: replace placeholder live flow with platform-aware setup, preflight, tracking, and summary states.
- `lib/settings/views/pages/settings_page.dart`: request real platform permissions, expose real availability, and export actual JSON files.
- `ios/Runner/**`: add Swift platform channel implementations for HealthKit first, then ARKit and WatchConnectivity.
- `android/app/**`: keep Android buildable, expose manual live mode, and avoid iOS-only claims.
- `firestore.rules`: separate public leaderboard profile data from private email/account state.
- `test/**`: replace counter coverage with domain, auth, friends, repository, settings, live-session, and platform-service tests.
- `README.md`: replace template docs with Pushlog-specific setup, Firebase, platform capability, and verification docs.

## Migration Tasks

### Task 1: Remove Scaffold Leftovers

**Files:**
- Delete: `lib/app/view/app.dart`
- Delete: `lib/counter/counter.dart`
- Delete: `lib/counter/cubit/counter_cubit.dart`
- Delete: `lib/counter/view/counter_page.dart`
- Delete: `test/counter/cubit/counter_cubit_test.dart`
- Delete: `test/counter/view/counter_page_test.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/l10n/arb/app_es.arb`
- Modify: `README.md`

- [ ] Remove generated counter source and tests after confirming `rg "Counter|counterAppBarTitle|pushlog/counter"` only points to files being deleted.
- [ ] Regenerate or simplify localization so app strings are not counter-specific.
- [ ] Replace the README with product-specific setup, Firebase, test, and migration notes.
- [ ] Run `flutter test` and `flutter analyze`.

### Task 2: Make Workout Storage Session-First

**Files:**
- Modify: `lib/workout/models/data/workout_snapshot.dart`
- Modify: `lib/workout/state/workout/workout_bloc.dart`
- Modify: `lib/workout/models/repos/impl/cloud_workout_repository.dart`
- Test: `test/workout/models/workout_snapshot_test.dart`
- Test: `test/workout/state/workout_bloc_test.dart`

- [ ] Write failing tests showing `WorkoutSnapshot.fromJson` rebuilds `dayTotals` from sessions when totals are missing or stale.
- [ ] Write failing tests showing remote/local merges preserve sessions from both snapshots when IDs differ.
- [ ] Implement `WorkoutSnapshot.normalized()` and repository merge behavior.
- [ ] Run targeted workout tests, then the full test suite.

### Task 3: Restore Real HealthKit Export On iOS

**Files:**
- Create: `lib/platform/health/health_service.dart`
- Create: `test/platform/health/health_service_test.dart`
- Modify: `lib/settings/views/pages/settings_page.dart`
- Modify: `lib/live/views/live_session_page.dart`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/Runner.entitlements`
- Modify: `ios/Runner/Info.plist`

- [ ] Write failing Dart tests for health availability, authorization labels, denied authorization, and successful live-session export calls.
- [ ] Add a MethodChannel-backed `HealthService` with Android returning unavailable and iOS returning real HealthKit status.
- [ ] Add Swift HealthKit channel code based on `old_ios/pushlog/Services/HealthKitManager.swift`.
- [ ] Save live sessions to HealthKit when `healthSyncEnabled` is true and the platform owns the workout write.
- [ ] Verify iOS build settings include HealthKit entitlement and usage descriptions.

### Task 4: Restore Live Tracking Parity

**Files:**
- Create: `lib/platform/live_tracking/live_tracking_service.dart`
- Create: `lib/platform/live_tracking/live_tracking_state.dart`
- Modify: `lib/live/views/live_session_page.dart`
- Modify: `ios/Runner/AppDelegate.swift`
- Create: `ios/Runner/PushlogFaceTrackingController.swift`
- Test: `test/platform/live_tracking/live_tracking_state_test.dart`

- [ ] Write failing tests for live setup states: unsupported, camera denied, ready, preflight lock, countdown, active, lost, paused, summary.
- [ ] Port the ARKit face-distance algorithm from `old_ios/pushlog/Services/FaceTrackingSessionController.swift` into a Swift event-channel controller.
- [ ] Update Flutter live UI to consume real native tracking events on iOS.
- [ ] Keep Android honest: manual live session mode remains available, and camera-auto copy is not shown as implemented.

### Task 5: Restore Watch Session Parity

**Files:**
- Create: `lib/platform/watch/watch_service.dart`
- Modify: `lib/live/views/live_session_page.dart`
- Modify: `ios/Runner/AppDelegate.swift`
- Create: `ios/Runner/PushlogWatchSessionManager.swift`
- Preserve until parity: `old_ios/pushlog watch Watch App/**`

- [ ] Write tests for watch availability labels and phone fallback state.
- [ ] Port WatchConnectivity message shapes from `old_ios/pushlog/Services/PhoneSessionManager.swift`.
- [ ] Show watch status in live setup/tracking when iOS has a paired watch app.
- [ ] Do not delete old watch source until the Flutter iOS host embeds a replacement watch target or the product explicitly drops watchOS support.

### Task 6: Harden Auth, Friends, Privacy, and Firestore Rules

**Files:**
- Modify: `lib/auth/models/user_profile.dart`
- Modify: `lib/auth/services/profile_service.dart`
- Modify: `lib/friends/state/friends_cubit.dart`
- Modify: `firestore.rules`
- Test: `test/auth/**`
- Test: `test/friends/**`

- [ ] Split public leaderboard fields from private account fields so signed-in users do not read every user's email.
- [ ] Add tests for username normalization, duplicate username handling, profile shell errors, friend add/remove, and leaderboard sorting.
- [ ] Update Firestore reads and rules to use public profile documents for friends/search.
- [ ] Document required Firebase indexes and rule deployment.

### Task 7: Accessibility, Analysis, and Build Gate

**Files:**
- Modify: `lib/today/views/widgets/action_strip.dart`
- Modify: `lib/today/views/widgets/friends_leaderboard.dart`
- Modify: `lib/today/views/pages/today_page.dart`
- Modify: `lib/settings/views/pages/settings_page.dart`
- Modify: `lib/live/views/live_session_page.dart`
- Modify: `lib/workout/state/workout/workout_bloc.dart`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/gradle.properties`

- [ ] Replace text-only `GestureDetector` controls with accessible button semantics or `InkWell` surfaces.
- [ ] Fix `flutter analyze` issues and `bloc_tools` warnings.
- [ ] Update Android Gradle configuration for the current Flutter/AGP behavior.
- [ ] Run `flutter test`, `flutter analyze`, `dart run bloc_tools:bloc lint .`, Android debug build, and iOS simulator build.

### Task 8: Delete Old iOS Codebase After Parity

**Files:**
- Delete: `old_ios/**`
- Modify: `README.md`

- [ ] Confirm Tasks 1-7 are complete.
- [ ] Confirm Flutter iOS has HealthKit, live tracking, and watch behavior or explicitly documented replacements.
- [ ] Confirm Android has honest feature availability and build verification.
- [ ] Delete `old_ios`.
- [ ] Run full verification again.
