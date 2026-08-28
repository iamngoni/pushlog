# Pushlog API worker (Rust)

The production implementation of the Pushlog application backend, on
Cloudflare Workers over D1. Replaced a prior TypeScript implementation
(same routes, JSON shapes, status codes, and D1 schema — a wire-compatible
rewrite, not a redesign). The TypeScript source is gone from this repo;
recover it from git history (`git log --diff-filter=D -- cloudflare/`) if
ever needed for comparison.

Live staging/internal-testing API (same URL the app has always used):
<https://pushlog-api-staging.imngonii.workers.dev>

Production API (isolated Worker and D1 database):
<https://pushlog-api.imngonii.workers.dev>

## Why Rust, and why this changed push delivery

The rewrite is a straight port with one real behavior change: push
notifications used to proxy through a Firebase Cloud Function
(`deliverPushlogNotification`) that was never actually deployed (its source
existed only as build output, untracked, 404ing in production). This worker
sends directly to FCM's HTTP v1 API instead — see `src/push/`. FCM v1 is also
how iOS is reached: Google forwards a message carrying an `apns` block to
APNs on the project's behalf, so one send path (`push::deliver_to_user`)
covers both platforms and the Flutter client's existing `firebase_messaging`
token registration needs no change.

Firebase Auth stays exactly as it was: this worker verifies Firebase ID
tokens against Google's public JWKS (`src/jwks.rs`) — no Firebase project
credentials, no Admin SDK, no Cloud Function.

## Activating live push delivery

Push delivery degrades gracefully without configuration — exactly like the
old worker did without `FCM_GATEWAY_SECRET` — falling back to the existing
30-second client-side notification poll. To enable instant delivery via FCM:

1. Firebase Console → Project settings → Service accounts → **Generate new
   private key** for the `pushlog-app` project. This downloads a JSON file.
2. `wrangler secret put FCM_SERVICE_ACCOUNT_JSON` and paste the file's
   contents.

No other configuration is needed; the worker reads `project_id`,
`client_email`, and `private_key` out of that one JSON secret.

## Lead-change notification copy

Lead-change pushes use the Wrangler `AI` binding to generate fresh,
structured title and body copy with Workers AI. Generated copy is validated
for push length, actor attribution, and the exact reps needed to retake the
lead. If the binding or model is unavailable, or its output fails validation,
the worker uses one of the curated variants in `src/lead_change_copy.rs`;
copy generation can never block notification delivery.

Before delivery, the worker re-reads both competitors' scores after inference
and drops notifications when the lead no longer exists or the event is over
60 seconds old. If the gap changed during inference, it uses fresh curated
copy. A source-snapshot uniqueness constraint prevents background retries from
sending the same lead change twice. An atomic per-friend/per-actor cooldown
also limits lead-change pushes to one per 60 seconds, even when several
snapshot updates or background tasks race.

The worker's 15-minute Cron Trigger also evaluates opt-in engagement
reminders in each user's current IANA timezone. It sends a streak-at-risk
warning after 21:00, a next-day missed-session reminder, and comeback nudges
after 3, 7, and 14 inactive days. Every reminder is deduplicated by its source
event, revalidated after AI inference and immediately before FCM delivery, and
collapsed into one reminder thread. Opening the app updates `last_active_at`;
the 14-day reminder is the final nudge until activity resumes. Streak alerts
and comeback nudges are separate opt-ins; disabling smart copy keeps these
reminders on curated fallback text instead of invoking AI.

## API

`GET /health` is public. Every `/v1/*` route requires a current Firebase ID
token in `Authorization: Bearer <token>`. The verified token's UID — never a
UID supplied in the request body — owns the operation.

- `GET|PUT /v1/profile`
- `PUT /v1/profile/username`
- `GET /v1/users/search`
- `GET|DELETE /v1/friends`
- `GET|POST /v1/friend-requests`
- `POST /v1/friend-requests/{accept,decline,cancel}`
- `GET|PUT /v1/workout-snapshot`
- `PUT|DELETE /v1/devices`
- `GET|POST /v1/notifications`
- `POST /v1/reports` (reports and immediately blocks the account)
- `DELETE /v1/account`

## Verification and deployment

```sh
npm install
npm run db:migrate:local
cargo fmt --all -- --check
cargo clippy --lib --all-targets -- -D warnings
cargo test --lib
cargo build --target wasm32-unknown-unknown --release
npm run test:coverage
npm run test:integration
npm run db:migrate:staging
npm run deploy:staging

# Production promotion uses the isolated config and database.
npm run db:migrate:production
npm run deploy:production
```

`cargo test --lib` runs on the host target and covers pure domain
functions: JWT decode/verify/claims validation (against both
self-signed fixtures and a captured real Google JWKS response), workout
stats and streak arithmetic, day-key parsing, lead-change copy selection,
FCM JWT assertion construction, and every request-body validator. It cannot
exercise the D1-backed route handlers directly — `worker`'s D1/Request/Env
types only exist inside the actual Workers runtime, and Rust has no
equivalent of `@cloudflare/vitest-pool-workers` yet.

`npm run test:coverage` enforces at least 95% line coverage on the
runtime-independent security and domain modules. Its explicit exclusions are
the Worker/D1/AI adapter modules that LLVM cannot execute outside the Workers
runtime; their pure validators still have unit tests. `npm run test:integration`
covers the HTTP/D1 boundary instead: it compiles a feature-gated local-only
verifier, starts workerd with a disposable D1, and exercises authenticated
success, validation failure, caching, persistence, and deletion routes. The
production build does not contain the test verifier.
