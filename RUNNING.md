# Running Pushlog Locally

Pushlog has two independently runnable halves:

| Half | Location | What it is |
| --- | --- | --- |
| Flutter client | `lib/`, `ios/`, `android/` | The iOS and Android app |
| Workers backend | `cloudflare-rs/` | Rust Cloudflare Worker + D1 application API |

**You do not need the backend to run the app.** The client defaults to the
deployed staging Worker, so `flutter run` works on its own. Run the backend
locally only when you are changing the API or the D1 schema.

---

## 1. Prerequisites

| Tool | Required version | Needed for | Install |
| --- | --- | --- | --- |
| Flutter SDK | **3.44.8** (pinned by CI) | Everything Flutter | See [§3](#3-install-flutter) |
| Dart | Ships inside Flutter | Everything Flutter | — (bundled) |
| Node.js | 20+ | Workers backend (wrangler CLI) | `brew install node` |
| npm | 10+ | Workers backend (wrangler CLI) | Bundled with Node |
| Rust | stable, `wasm32-unknown-unknown` target | Workers backend | `rustup target add wasm32-unknown-unknown` |
| Xcode | 16+ | iOS builds & simulators | Mac App Store |
| CocoaPods | 1.15+ | iOS native dependencies | `brew install cocoapods` |
| JDK | 17 or 21 | Android Gradle build | `brew install openjdk@21` |
| Android SDK | Platform 35+, build-tools 35+ | Android builds | Android Studio |
| Android cmdline-tools | latest | `sdkmanager`, license acceptance | Android Studio → SDK Manager → SDK Tools |
| Android NDK | **28.2.13676358** (r28c) | Android builds — see below | `sdkmanager --install "ndk;28.2.13676358"` |

`pubspec.yaml` declares `sdk: ^3.11.0` / `flutter: ^3.41.0`, but **3.44.8** is
the version actually pinned in `.github/scripts/setup_flutter.sh` and
`ios/ci_scripts/ci_post_clone.sh`. Match CI unless you have a reason not to.

### Not required

- **Firebase CLI / FlutterFire CLI** — the generated config is committed
  (`lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`,
  `android/app/google-services.json`). You only need these if you are
  regenerating Firebase config.
- **A global `wrangler`** — it is a local devDependency in
  `cloudflare-rs/package.json` and runs through the npm scripts.
- **A Cloudflare account or `wrangler login`** — local dev and local
  migrations run offline against Miniflare. Login is required only to deploy
  or to migrate the remote staging database.

---

## 2. Preflight check

Run this to see what your machine is missing before you start:

```sh
for c in flutter dart node npm java xcodebuild pod adb sdkmanager; do
  command -v "$c" >/dev/null 2>&1 \
    && printf 'OK   %-12s %s\n' "$c" "$(command -v "$c")" \
    || printf 'MISS %-12s\n' "$c"
done
```

Then, once Flutter is installed, the authoritative check is:

```sh
flutter doctor -v
```

Resolve every ✗ in the Flutter and platform-toolchain sections. A ✗ under
"Connected device" just means nothing is booted yet.

---

## 3. Install Flutter

Use the same method CI uses — a shallow clone of the pinned tag. This works on
Apple Silicon and avoids SDK-archive drift.

```sh
git clone --branch 3.44.8 --depth 1 \
  https://github.com/flutter/flutter.git "$HOME/flutter"
```

Add it to your `PATH` (append to `~/.zshrc` so it survives new shells):

```sh
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
export PATH="$HOME/flutter/bin:$PATH"
```

Verify and warm the caches:

```sh
flutter --version          # expect 3.44.8
flutter config --no-analytics
flutter precache --ios --android
flutter doctor -v
```

Budget roughly 3–5 GB of disk for the SDK plus its artifact caches.

### Accepting Android licenses

`flutter doctor` will flag missing Android licenses or missing command-line
tools. Install the tools first, via **Android Studio → Settings → Languages &
Frameworks → Android SDK → SDK Tools → Android SDK Command-line Tools
(latest)**, then:

```sh
flutter doctor --android-licenses
```

---

### The NDK is a hard requirement — install it before your first build

Flutter 3.44.8 pins `flutter.ndkVersion` to **28.2.13676358**, and
`android/app/build.gradle.kts` passes that straight to AGP via
`ndkVersion = flutter.ndkVersion`. If that exact NDK is absent, Gradle tries to
auto-download it during the build. That auto-installer is unreliable: it can
die mid-download and leave the build **hung indefinitely with no error** — the
daemon log simply stops at:

```text
Preparing "Install NDK (Side by side) 28.2.13676358".
```

Having NDK 27.x installed does not help; the version must match exactly.
Install it up front, which is also much faster and resumable:

```sh
sdkmanager --install "ndk;28.2.13676358"
```

It is a ~2.8 GB install. If a build has already hung this way, kill it and
clear the abandoned download state before retrying:

```sh
rm -rf "$ANDROID_HOME/ndk/28.2.13676358" \
       "$ANDROID_HOME/.downloadIntermediates" \
       "$ANDROID_HOME/.temp"
```

---

## 4. Run the Flutter app

Install Dart dependencies. This also generates the localizations in
`lib/l10n/gen/` (because `pubspec.yaml` sets `generate: true`) and writes
`android/local.properties` with your Flutter and Android SDK paths, so it must
run before any platform build:

```sh
flutter pub get
```

For iOS, install the native pods. `flutter pub get` must have run first —
the `Podfile` reads `ios/Flutter/Generated.xcconfig`, which that step creates:

```sh
cd ios && pod install && cd ..
```

Pick a device, then run a flavor. There are three flavors, each with its own
entrypoint; the flavor and the target must always agree:

```sh
flutter devices

flutter run --flavor development --target lib/main_development.dart
flutter run --flavor staging     --target lib/main_staging.dart
flutter run --flavor production  --target lib/main_production.dart
```

VS Code users can use the equivalent **Launch development / staging /
production** configurations in `.vscode/launch.json`.

Android installs these side by side — `development` and `staging` apply
`.dev` and `.stg` application-ID suffixes and show as `[DEV] Pushlog` and
`[STG] Pushlog`.

### Booting a device

```sh
# iOS simulator
open -a Simulator

# Android emulator (list AVDs, then boot one)
emulator -list-avds
emulator -avd <avd-name> &
```

---

## 5. Run the backend locally

```sh
cd cloudflare-rs
npm install
npm run db:migrate:local              # applies migrations/ to the local D1 in .wrangler/state
cargo fmt --all -- --check
cargo clippy --lib --all-targets -- -D warnings
cargo test --lib                      # host-run unit tests — see cloudflare-rs/README.md
npm run dev                           # wrangler dev, serves on http://localhost:8787
```

`npm run dev` runs fully local — no Cloudflare login, no network calls to
your account. State persists under `cloudflare-rs/.wrangler/state`.

`GET /health` is public. Every `/v1/*` route needs a real Firebase ID token in
`Authorization: Bearer <token>`, and the verified token UID owns the
operation — a UID in the request body is never trusted. That means exercising
`/v1/*` by hand requires a token from a signed-in client.

### Optional environment variables

`FCM_SERVICE_ACCOUNT_JSON` enables immediate push delivery (FCM HTTP v1,
which also reaches iOS via APNs on Google's side). It is optional: the D1
notification inbox works without it — see `cloudflare-rs/README.md` for how
to obtain it. To set it locally, create `cloudflare-rs/.dev.vars` (gitignored):

```ini
FCM_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"pushlog-app",...}
```

`FIREBASE_PROJECT_ID` and `ENVIRONMENT` are already set in `wrangler.toml`.

### Deploying (explicit, separate operations)

These hit real infrastructure and require `wrangler login`:

```sh
npm run db:migrate:staging
npm run deploy:staging
```

A passing local migration, build, or test is **not** proof that staging or
production was deployed.

---

## 6. Point the app at a local Worker

The client reads a single compile-time define, `PUSHLOG_API_URL`, defaulting
to `https://pushlog-api-staging.imngonii.workers.dev`
(`lib/core/services/pushlog_api_client.dart`). Override it at run time:

```sh
# iOS simulator — reaches the host directly
flutter run --flavor development --target lib/main_development.dart \
  --dart-define=PUSHLOG_API_URL=http://localhost:8787

# Android emulator — 10.0.2.2 is the host loopback alias
flutter run --flavor development --target lib/main_development.dart \
  --dart-define=PUSHLOG_API_URL=http://10.0.2.2:8787
```

It is a `const String.fromEnvironment`, so it is baked in at build time — a
change requires a rebuild, not a hot reload.

---

## 7. Full verification gate

Run this after changes, in order. It mirrors CI plus the backend checks:

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

GitHub Actions (`.github/workflows/main.yaml`, self-hosted runner) covers
formatting, analysis, and Flutter tests only. The Android build, the Bloc
lint, and the Workers checks are local responsibilities.

### Device checks CI cannot cover

iOS platform changes additionally need a simulator build plus, on a physical
device: Apple and Google sign-in, HealthKit authorization and saved-workout
verification, TrueDepth pre-flight / tracking-loss / pause / manual-fallback,
Apple Watch launch and workout ownership, and notifications in foreground,
background, and terminated states.

Android changes need an emulator or device check for authentication, manual
sessions, reminders, notifications, data sync, and honest unavailable states
for the iOS-only capabilities.

---

## 8. Troubleshooting

**`flutter.sdk not set in local.properties`**
`android/local.properties` is generated by the Flutter tool, not committed.
Run `flutter pub get` from the repo root before invoking Gradle by hand or
opening `android/` directly in Android Studio.

**`Generated.xcconfig must exist` when running `pod install`**
Run `flutter pub get` first, then `cd ios && pod install`.

**Pods fail to compile against the wrong iOS SDK**
The `Podfile` pins a 15.5 floor because ML Kit pose detection needs it, and
only ever raises a pod's deployment target. After changing dependencies:
`cd ios && rm -rf Pods Podfile.lock && pod install`.

**Build hangs forever with no output, or stops after "Preparing Install NDK"**
The pinned NDK (28.2.13676358) is missing and Gradle's auto-download stalled.
Kill the build, then install the NDK explicitly — see
[§3](#the-ndk-is-a-hard-requirement--install-it-before-your-first-build).
Diagnose a suspected hang by checking whether anything is actually moving:
`find "$ANDROID_HOME" -newermt '-2 minutes' | wc -l` and
`tail ~/.gradle/daemon/*/daemon-*.log`. Zero file activity plus a daemon log
showing only "periodic daemon health check" means hung, not slow.

**`sdkmanager: command not found`**
Android command-line tools are not installed. Install them from Android
Studio's SDK Manager (SDK Tools tab), then reopen your shell.

**Gradle or Kotlin JVM target mismatch**
The build targets Java 11 bytecode but needs a JDK 17+ toolchain to run.
Point Flutter at a specific JDK with
`flutter config --jdk-dir=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home`.

**`flutter run` fails with a flavor error**
Flavor and target must match. `--flavor development` requires
`--target lib/main_development.dart`. iOS flavors are backed by the
`development`, `staging`, and `production` schemes in `ios/Runner.xcodeproj`.

**Worker tests emit `EPERM ... .wrangler` noise**
Wrangler tries to write a debug log under `~/Library/Preferences/.wrangler`.
If the tests still report passing, the errors are cosmetic.

**Reset the local D1 database**
```sh
cd cloudflare-rs && rm -rf .wrangler/state && npm run db:migrate:local
```
