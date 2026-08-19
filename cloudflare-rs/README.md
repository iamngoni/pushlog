# Pushlog API worker (Rust)

The production implementation of the Pushlog application backend, on
Cloudflare Workers over D1. Replaced a prior TypeScript implementation
(same routes, JSON shapes, status codes, and D1 schema — a wire-compatible
rewrite, not a redesign). The TypeScript source is gone from this repo;
recover it from git history (`git log --diff-filter=D -- cloudflare/`) if
ever needed for comparison.

Live staging/internal-testing API (same URL the app has always used):
<https://pushlog-api-staging.imngonii.workers.dev>

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
- `DELETE /v1/account`

## Verification and deployment

```sh
npm install
npm run db:migrate:local
cargo fmt --all -- --check
cargo clippy --lib --all-targets -- -D warnings
cargo test --lib
cargo build --target wasm32-unknown-unknown --release
npm run db:migrate:staging
npm run deploy:staging
```

`cargo test --lib` runs on the host target and covers every pure
domain function: JWT decode/verify/claims validation (against both
self-signed fixtures and a captured real Google JWKS response), workout
stats and streak arithmetic, day-key parsing, lead-change copy selection,
FCM JWT assertion construction, and every request-body validator. It cannot
exercise the D1-backed route handlers directly — `worker`'s D1/Request/Env
types only exist inside the actual Workers runtime, and Rust has no
equivalent of `@cloudflare/vitest-pool-workers` yet. Route-level behavior
was verified manually against a real local D1 (`npm run dev` after
`db:migrate:local`) with every endpoint exercised end to end, then against
the real Cloudflare edge before this worker took over the production name.
