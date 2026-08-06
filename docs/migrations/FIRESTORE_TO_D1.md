# Firestore to D1 migration

Pushlog's existing Firestore data was copied into `pushlog-staging` before the
Flutter client moved to the Workers API. The importer is deterministic,
idempotent, and records every Firestore source path with a SHA-256 checksum in
`migration_ledger`.

Covered source collections:

- `users`, including workout state, friends, requests, tokens, and notifications
- `publicProfiles`
- `friendStats`
- `usernames`

## Inventory

From `cloudflare`, Application Default Credentials with Firestore read access
are required:

```sh
npm run migrate:firestore
```

The default command prints counts only. It does not print document contents,
email addresses, usernames, or device tokens.

## Backfill

```sh
CLOUDFLARE_ACCOUNT_ID=... \
CLOUDFLARE_D1_DATABASE_ID=... \
CLOUDFLARE_API_TOKEN=... \
npm run migrate:firestore -- --apply
```

## Reconciliation

```sh
CLOUDFLARE_ACCOUNT_ID=... \
CLOUDFLARE_D1_DATABASE_ID=... \
CLOUDFLARE_API_TOKEN=... \
npm run reconcile:firestore
```

The backfill gate passes only with zero missing, mismatched, or extra ledger
entries. The imported staging run matched all 41 Firestore source documents.

## Current ownership

D1 is the application database. The Worker owns workout snapshots, normalized
sessions, profiles, usernames, friend graphs, leaderboard totals, device
registrations, and competition notification events. The Flutter client keeps a
local workout snapshot for offline continuity, while Firebase remains only for
authentication and its native messaging SDK. The D1 notification inbox works
without a server-side FCM credential; immediate background push delivery is an
optional transport and is not part of database ownership.

The internal-testing endpoint is:
`https://pushlog-api-staging.imngonii.workers.dev`.

## Recovery

D1 migrations are versioned. Before a production resource switch, export the
database and rehearse Time Travel restore. Firestore should be retained as a
read-only historical archive until the internal builds have passed profile,
friend, workout, account deletion, and real-device notification acceptance.
