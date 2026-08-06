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
  it('reports D1-backed shadow health', async () => {
    const response = await handleRequest(
      new Request('https://pushlog.test/health'),
      testEnv,
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      status: 'ok',
      dataMode: 'shadow',
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
      meta: {dataMode: 'shadow'},
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
});
