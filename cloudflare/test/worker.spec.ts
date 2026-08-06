import {env} from 'cloudflare:workers';
import {describe, expect, it} from 'vitest';

import type {AuthenticatedUser, AuthVerifier, Env} from '../src/env';
import {handleRequest} from '../src/index';

const testEnv = env as unknown as Env;

function auth(uid: string): AuthVerifier {
  return async (): Promise<AuthenticatedUser> => ({
    uid,
    email: `${uid}@example.test`,
    name: 'Test Pusher',
  });
}

function snapshot(reps = 12) {
  return {
    dayTotals: {'2026-08-06': reps},
    sessions: [
      {
        id: 'session-1',
        date: '2026-08-06T08:00:00.000Z',
        reps,
        source: 'manual',
        duration: null,
        averageRepDuration: null,
        manualAdjustments: 0,
      },
    ],
    preferences: {
      remindersEnabled: false,
      competitionNotificationsEnabled: true,
    },
    updatedAt: '2026-08-06T08:01:00.000Z',
    lastSyncedAt: '2026-08-06T08:01:00.000Z',
  };
}

describe('Pushlog Worker', () => {
  it('reports D1 as the primary database', async () => {
    const response = await handleRequest(
      new Request('https://pushlog.test/health'),
      testEnv,
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      status: 'ok',
      database: 'd1',
    });
  });

  it('stores and retrieves an authenticated workout snapshot', async () => {
    const uid = 'store-and-read';
    const write = await handleRequest(
      new Request('https://pushlog.test/v1/workout-snapshot', {
        method: 'PUT',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({snapshot: snapshot()}),
      }),
      testEnv,
      auth(uid),
    );
    expect(write.status).toBe(202);

    const read = await handleRequest(
      new Request('https://pushlog.test/v1/workout-snapshot'),
      testEnv,
      auth(uid),
    );
    expect(read.status).toBe(200);
    await expect(read.json()).resolves.toMatchObject({
      snapshot: snapshot(),
      meta: {source: 'd1'},
    });
  });

  it('is idempotent and only exposes the active generation', async () => {
    const uid = 'generation-test';
    const firstRequest = () =>
      new Request('https://pushlog.test/v1/workout-snapshot', {
        method: 'PUT',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({snapshot: snapshot(10)}),
      });
    const first = await handleRequest(firstRequest(), testEnv, auth(uid));
    const unchanged = await handleRequest(firstRequest(), testEnv, auth(uid));
    expect(first.status).toBe(202);
    expect(unchanged.status).toBe(200);
    await expect(unchanged.json()).resolves.toMatchObject({status: 'unchanged'});

    const replacement = snapshot(20);
    replacement.sessions[0].id = 'session-2';
    const replaced = await handleRequest(
      new Request('https://pushlog.test/v1/workout-snapshot', {
        method: 'PUT',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({snapshot: replacement}),
      }),
      testEnv,
      auth(uid),
    );
    expect(replaced.status).toBe(202);

    const activeSessions = await testEnv.DB.prepare(
      `SELECT session_id FROM workout_sessions
       WHERE uid = ? AND sync_id = (
         SELECT sync_id FROM workout_snapshots WHERE uid = ?
       )`,
    )
      .bind(uid, uid)
      .all<{session_id: string}>();
    expect(activeSessions.results).toEqual([{session_id: 'session-2'}]);

    const allGenerations = await testEnv.DB.prepare(
      'SELECT COUNT(*) AS count FROM workout_sessions WHERE uid = ?',
    )
      .bind(uid)
      .first<{count: number}>();
    expect(allGenerations?.count).toBe(1);
  });

  it('rejects malformed snapshots without writing data', async () => {
    const response = await handleRequest(
      new Request('https://pushlog.test/v1/workout-snapshot', {
        method: 'PUT',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({snapshot: {dayTotals: [], sessions: []}}),
      }),
      testEnv,
      auth('invalid-snapshot'),
    );

    expect(response.status).toBe(422);
    await expect(response.json()).resolves.toMatchObject({
      error: {code: 'invalid_snapshot'},
    });
  });

  it('owns profiles, friendships, leaderboards, and lead-change events', async () => {
    const alpha = auth('primary-alpha');
    const beta = auth('primary-beta');
    for (const [verify, username] of [
      [alpha, 'alpha_lifter'],
      [beta, 'beta_lifter'],
    ] as const) {
      const profile = await handleRequest(
        new Request('https://pushlog.test/v1/profile', {method: 'PUT'}),
        testEnv,
        verify,
      );
      expect(profile.status).toBe(200);
      const claim = await handleRequest(
        new Request('https://pushlog.test/v1/profile/username', {
          method: 'PUT',
          headers: {'content-type': 'application/json'},
          body: JSON.stringify({username}),
        }),
        testEnv,
        verify,
      );
      expect(claim.status).toBe(200);
    }

    const sent = await handleRequest(
      new Request('https://pushlog.test/v1/friend-requests', {
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({receiverUid: 'primary-beta'}),
      }),
      testEnv,
      alpha,
    );
    expect(sent.status).toBe(201);
    const accepted = await handleRequest(
      new Request('https://pushlog.test/v1/friend-requests/accept', {
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({requesterUid: 'primary-alpha'}),
      }),
      testEnv,
      beta,
    );
    expect(accepted.status).toBe(200);

    const writeScore = async (
      verify: AuthVerifier,
      reps: number,
      sessionId: string,
    ) => {
      const body = snapshot(reps);
      body.sessions[0].id = sessionId;
      return handleRequest(
        new Request('https://pushlog.test/v1/workout-snapshot', {
          method: 'PUT',
          headers: {'content-type': 'application/json'},
          body: JSON.stringify({
            snapshot: body,
            clientContext: {
              dayKey: '2026-08-06',
              weekKey: '2026-08-03',
            },
          }),
        }),
        testEnv,
        verify,
      );
    };
    expect((await writeScore(beta, 15, 'beta-score')).status).toBe(202);
    expect((await writeScore(alpha, 10, 'alpha-behind')).status).toBe(202);
    expect((await writeScore(alpha, 20, 'alpha-passes')).status).toBe(202);

    const board = await handleRequest(
      new Request('https://pushlog.test/v1/friends'),
      testEnv,
      beta,
    );
    expect(board.status).toBe(200);
    await expect(board.json()).resolves.toMatchObject({
      friends: [{uid: 'primary-alpha', totalAllTime: 20}],
    });
    const nextDayBoard = await handleRequest(
      new Request(
        'https://pushlog.test/v1/friends?dayKey=2026-08-07&weekKey=2026-08-03',
      ),
      testEnv,
      beta,
    );
    await expect(nextDayBoard.json()).resolves.toMatchObject({
      friends: [{uid: 'primary-alpha', todayCount: 0, weekCount: 20}],
    });
    const event = await testEnv.DB.prepare(
      `SELECT actor_uid, delivery_status FROM notification_events
       WHERE uid = ? AND type = 'lead_change'`,
    )
      .bind('primary-beta')
      .first<{actor_uid: string; delivery_status: string}>();
    expect(event).toEqual({
      actor_uid: 'primary-alpha',
      delivery_status: 'no_devices',
    });

    const inbox = await handleRequest(
      new Request('https://pushlog.test/v1/notifications'),
      testEnv,
      beta,
    );
    expect(inbox.status).toBe(200);
    const inboxBody = (await inbox.json()) as {
      notifications: {notificationId: string; actorUid: string}[];
    };
    expect(inboxBody.notifications).toHaveLength(1);
    expect(inboxBody.notifications[0].actorUid).toBe('primary-alpha');

    const acknowledged = await handleRequest(
      new Request('https://pushlog.test/v1/notifications', {
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({
          notificationIds: [inboxBody.notifications[0].notificationId],
        }),
      }),
      testEnv,
      beta,
    );
    expect(acknowledged.status).toBe(200);
    const emptyInbox = await handleRequest(
      new Request('https://pushlog.test/v1/notifications'),
      testEnv,
      beta,
    );
    await expect(emptyInbox.json()).resolves.toEqual({notifications: []});
  });

  it('registers and removes notification devices without trusting a body uid', async () => {
    const verify = auth('device-owner');
    const token = 'test-device-token-that-is-long-enough';
    await handleRequest(
      new Request('https://pushlog.test/v1/devices', {
        method: 'PUT',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({token, platform: 'android'}),
      }),
      testEnv,
      auth('previous-device-owner'),
    );
    const registered = await handleRequest(
      new Request('https://pushlog.test/v1/devices', {
        method: 'PUT',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({uid: 'someone-else', token, platform: 'android'}),
      }),
      testEnv,
      verify,
    );
    expect(registered.status).toBe(200);
    const row = await testEnv.DB.prepare(
      'SELECT uid FROM devices WHERE token = ?',
    )
      .bind(token)
      .first<{uid: string}>();
    expect(row?.uid).toBe('device-owner');

    const removed = await handleRequest(
      new Request('https://pushlog.test/v1/devices', {
        method: 'DELETE',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({token}),
      }),
      testEnv,
      verify,
    );
    expect(removed.status).toBe(204);
  });
});
