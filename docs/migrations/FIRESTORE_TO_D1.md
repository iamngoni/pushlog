# Firestore to D1 migration

## Safety boundary

Firestore remains Pushlog's source of truth throughout backfill and shadow
testing. The migration does not delete or mutate Firestore documents. D1 gets
separate staging and production databases, and the app keeps its local workout
snapshot as its offline source.

Current source collections covered by the migration:

- `users`, including friends, incoming/outgoing requests, private workout
  state, push tokens, and notifications
- `publicProfiles`
- `friendStats`
- `usernames`

Each Firestore document is serialized deterministically and recorded in
`migration_ledger` with a SHA-256 checksum. D1 also stores normalized sessions,
daily scores, profiles, friend links, requests, devices, and notifications.

## Rollout phases

### 1. Staging schema and API

Apply `cloudflare/migrations` to `pushlog-staging`, deploy
`pushlog-api-staging`, and verify `/health`. Only the authenticated workout
snapshot shadow endpoint is enabled initially. Firebase Auth continues issuing
identity tokens; no Firebase Admin secret is embedded in the app or Worker.

Current staging endpoint:
`https://pushlog-api-staging.imngonii.workers.dev`.

### 2. Inventory and dry run

Use Google Application Default Credentials with read access to the Firebase
project, then run from `cloudflare`:

```sh
npm run migrate:firestore
```

The default is inventory-only. It prints counts, never document contents,
email addresses, usernames, or device tokens. Save the counts in the release
record.

### 3. Idempotent staging backfill

Create a narrowly scoped Cloudflare API token that can query only the staging
D1 database, export it only for this command, and run:

```sh
CLOUDFLARE_ACCOUNT_ID=... \
CLOUDFLARE_D1_DATABASE_ID=... \
CLOUDFLARE_API_TOKEN=... \
npm run migrate:firestore -- --apply
```

The importer upserts by stable source keys, so retrying is safe. A failed run
stays incomplete in `migration_runs`; it never makes a partial workout
generation active. Revoke the migration token after the production backfill.

### 4. Reconciliation

Run the same inventory against Firestore and compare every source path and
checksum with D1:

```sh
CLOUDFLARE_ACCOUNT_ID=... \
CLOUDFLARE_D1_DATABASE_ID=... \
CLOUDFLARE_API_TOKEN=... \
npm run reconcile:firestore
```

The gate passes only with zero missing, mismatched, or extra ledger entries.
Also compare normalized table counts and manually spot-check two test accounts:
total reps, session history, training plan, username, friends, pending requests,
all-time best, and notification/device counts.

### 5. Shadow writes in internal builds

Add the staging Worker URL as a build-time value. A successful local +
Firestore write attempts a best-effort D1 write; D1 failures are logged but do
not fail a workout. Reads still come from local storage and Firestore. Run this
for at least one iOS and one Android internal build while scheduled
reconciliation stays clean.

The build-time value is:

```sh
--dart-define=PUSHLOG_SHADOW_API_URL=https://pushlog-api-staging.imngonii.workers.dev
```

### 6. Production backfill and read canary

Create `pushlog-production` and `pushlog-api-production` as new resources,
apply the same migrations, repeat dry-run/backfill/reconciliation, then enable
D1 reads for a small tester allowlist. On a D1 miss or integrity mismatch, fall
back to Firestore and record the event. Expand only after restore, friend board,
and competition notification acceptance tests pass on real devices.

### 7. Cutover and retirement

Switch all testers to D1 reads, retain dual writes for at least one release,
then stop Firestore writes. Keep Firestore read-only for a defined rollback
window and export a final archive before removing app access. Firebase Auth and
FCM stay in place until separate replacements are deliberately chosen.

## Rollback

Before read cutover, rollback is simply disabling the Worker build-time URL.
During the read canary, disable the D1 read flag and return to Firestore. Do not
delete Firestore data as part of rollback. D1 schema changes are versioned, and
Cloudflare Time Travel/export is an additional recovery layer rather than the
only copy.

## Required proof before Firestore retirement

- Firestore-to-D1 checksum reconciliation passes twice, including once after
  the last dual-write build has been active.
- Local, Firestore, and D1 totals match for every current user.
- Sign-in, restore, onboarding plan, history, friends, all-time leaderboard,
  crossed friend requests, account deletion, and lead-change notifications pass
  on internal iOS and Android builds.
- A D1 outage test proves that local workout logging still succeeds and the
  retry path catches up without duplicate sessions.
- Production D1 export/restore and Worker rollback are rehearsed.
