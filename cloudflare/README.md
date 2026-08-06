# Pushlog Workers backend

This Worker is Pushlog's application data backend. D1 stores profiles,
workouts, leaderboard statistics, friendships, friend requests, devices, and
notification events. Firebase Auth continues to issue identity tokens and FCM
continues to deliver native push notifications; Firestore is not used by the
Flutter app.

Staging/internal-testing API:
<https://pushlog-api-staging.imngonii.workers.dev>

## API

`GET /health` is public. Every `/v1/*` route requires a current Firebase ID
token in `Authorization: Bearer <token>`. The verified token UID—not a UID in
the request body—owns the operation.

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
npm run check
npm test
npm run db:migrate:staging
npm run deploy:staging
```

The Flutter client uses this endpoint by default. A different internal API can
be selected at build time with:

```sh
--dart-define=PUSHLOG_API_URL=https://example.workers.dev
```

Lead changes are generated and stored by the Worker. The app reads unread D1
events from `/v1/notifications` and displays them through the native local
notification surface. `FCM_GATEWAY_URL` and `FCM_GATEWAY_SECRET` are optional:
when configured, the Worker also delivers the same event immediately through
FCM. They are not required for profiles, workouts, friends, leaderboards, or
the notification inbox.
