# Pushlog Cloudflare staging backend

This Worker is a shadow backend for the Firestore-to-D1 migration. Firestore
remains the production source of truth until the reconciliation and test-build
gates in `docs/migrations/FIRESTORE_TO_D1.md` pass.

Staging health: <https://pushlog-api-staging.imngonii.workers.dev/health>

## Local verification

```sh
npm install
npm run db:migrate:local
npm run check
npm test
npm run dev
```

`GET /health` is public. `GET` and `PUT /v1/workout-snapshot` require a current
Firebase ID token in an `Authorization: Bearer <token>` header. The token UID,
not a request-body UID, selects the D1 record.

## Staging deployment

```sh
npm run db:migrate:staging
npm run deploy:staging
```

The checked-in configuration only names the staging Worker and staging D1
database. Create separate production resources and bindings after shadow
reconciliation passes; do not repoint the staging binding at a production
database.

After staging backfill and reconciliation pass, enable shadow writes in a test
build with:

```sh
flutter run --dart-define=PUSHLOG_SHADOW_API_URL=https://pushlog-api-staging.imngonii.workers.dev
```
