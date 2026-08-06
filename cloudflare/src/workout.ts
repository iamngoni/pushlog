import type {AuthenticatedUser, Env} from './env';
import {HttpError, jsonResponse} from './http';
import {notifyFriendsPassed} from './notifications';
import {ensureProfile} from './profile';

interface WorkoutSessionPayload {
  id: string;
  date: string;
  reps: number;
  source: 'manual' | 'live';
  duration: number | null;
  averageRepDuration: number | null;
  manualAdjustments: number;
}

interface WorkoutSnapshotPayload {
  dayTotals: Record<string, number>;
  sessions: WorkoutSessionPayload[];
  preferences: Record<string, unknown>;
  updatedAt: string | null;
  lastSyncedAt: string | null;
}

interface WorkoutRequestPayload {
  snapshot: WorkoutSnapshotPayload;
  dayKey: string;
  weekKey: string;
}

interface StoredSnapshotRow {
  sync_id: string;
  snapshot_json: string;
  content_hash: string;
  updated_at: string;
}

const maximumSnapshotBytes = 900_000;
const maximumSessions = 5_000;
const maximumDayTotals = 5_000;
const statementBatchSize = 100;

export async function putWorkoutSnapshot(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
  context?: ExecutionContext,
): Promise<Response> {
  const payload = await parseWorkoutRequest(request);
  const {snapshot} = payload;
  const snapshotJson = JSON.stringify(snapshot);
  if (new TextEncoder().encode(snapshotJson).byteLength > maximumSnapshotBytes) {
    throw new HttpError(
      413,
      'snapshot_too_large',
      'The workout snapshot is too large to sync.',
    );
  }

  const contentHash = await sha256(snapshotJson);
  const existing = await env.DB.prepare(
    'SELECT sync_id, content_hash FROM workout_snapshots WHERE uid = ?',
  )
    .bind(user.uid)
    .first<Pick<StoredSnapshotRow, 'sync_id' | 'content_hash'>>();
  if (existing?.content_hash === contentHash) {
    return jsonResponse({
      status: 'unchanged',
      syncId: existing.sync_id,
      contentHash,
    });
  }

  const now = new Date().toISOString();
  const syncId = crypto.randomUUID();
  await ensureProfile(env, user);
  const previousStats = await env.DB.prepare(
    'SELECT today_count, today_key FROM friend_stats WHERE uid = ?',
  )
    .bind(user.uid)
    .first<{today_count: number; today_key: string | null}>();
  const previousTodayCount =
    previousStats?.today_key === payload.dayKey
      ? previousStats.today_count
      : 0;
  const stats = workoutStats(snapshot.dayTotals, payload.dayKey, payload.weekKey);

  const sessionStatements = snapshot.sessions.map((session) =>
    env.DB.prepare(
      `INSERT INTO workout_sessions (
        uid, sync_id, session_id, occurred_at, reps, source,
        duration_us, average_rep_duration_us, manual_adjustments
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      user.uid,
      syncId,
      session.id,
      session.date,
      session.reps,
      session.source,
      session.duration,
      session.averageRepDuration,
      session.manualAdjustments,
    ),
  );
  const dayStatements = Object.entries(snapshot.dayTotals).map(
    ([dayKey, reps]) =>
      env.DB.prepare(
        'INSERT INTO daily_scores (uid, sync_id, day_key, reps) VALUES (?, ?, ?, ?)',
      ).bind(user.uid, syncId, dayKey, reps),
  );
  await runInBatches(env.DB, [...sessionStatements, ...dayStatements]);

  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO workout_snapshots (
        uid, sync_id, snapshot_json, content_hash, source_updated_at,
        last_synced_at, schema_version, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, 1, ?)
      ON CONFLICT(uid) DO UPDATE SET
        sync_id = excluded.sync_id,
        snapshot_json = excluded.snapshot_json,
        content_hash = excluded.content_hash,
        source_updated_at = excluded.source_updated_at,
        last_synced_at = excluded.last_synced_at,
        schema_version = excluded.schema_version,
        updated_at = excluded.updated_at`,
    ).bind(
      user.uid,
      syncId,
      snapshotJson,
      contentHash,
      snapshot.updatedAt,
      snapshot.lastSyncedAt,
      now,
    ),
    env.DB.prepare(
      'DELETE FROM workout_sessions WHERE uid = ? AND sync_id <> ?',
    ).bind(user.uid, syncId),
    env.DB.prepare(
      'DELETE FROM daily_scores WHERE uid = ? AND sync_id <> ?',
    ).bind(user.uid, syncId),
    env.DB.prepare(
      `INSERT INTO friend_stats (
        uid, today_count, today_key, week_count, week_key, best_day,
        total_all_time, streak, source_json, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(uid) DO UPDATE SET
        today_count = excluded.today_count,
        today_key = excluded.today_key,
        week_count = excluded.week_count,
        week_key = excluded.week_key,
        best_day = excluded.best_day,
        total_all_time = excluded.total_all_time,
        streak = excluded.streak,
        source_json = excluded.source_json,
        updated_at = excluded.updated_at`,
    ).bind(
      user.uid,
      stats.todayCount,
      payload.dayKey,
      stats.weekCount,
      payload.weekKey,
      stats.bestDay,
      stats.totalAllTime,
      stats.streak,
      JSON.stringify(stats),
      now,
    ),
  ]);

  const delivery = notifyFriendsPassed(
    env,
    user.uid,
    previousTodayCount,
    stats.todayCount,
    payload.dayKey,
  ).catch((error: unknown) => {
    console.error('Lead-change notification processing failed', {
      uid: user.uid,
      error: error instanceof Error ? error.message : String(error),
    });
  });
  if (context == null) {
    await delivery;
  } else {
    context.waitUntil(delivery);
  }

  return jsonResponse(
    {status: 'stored', syncId, contentHash},
    {status: 202},
  );
}

export async function getWorkoutSnapshot(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const stored = await env.DB.prepare(
    `SELECT sync_id, snapshot_json, content_hash, updated_at
     FROM workout_snapshots WHERE uid = ?`,
  )
    .bind(user.uid)
    .first<StoredSnapshotRow>();
  if (stored == null) {
    throw new HttpError(
      404,
      'snapshot_not_found',
      'No workout snapshot exists for this user.',
    );
  }

  const etag = `"${stored.content_hash}"`;
  if (request.headers.get('if-none-match') === etag) {
    return new Response(null, {
      status: 304,
      headers: {'cache-control': 'private, no-cache', etag},
    });
  }

  return jsonResponse(
    {
      snapshot: JSON.parse(stored.snapshot_json) as unknown,
      meta: {
        syncId: stored.sync_id,
        contentHash: stored.content_hash,
        storedAt: stored.updated_at,
        source: 'd1',
      },
    },
    {headers: {etag}},
  );
}

async function runInBatches(
  db: D1Database,
  statements: D1PreparedStatement[],
): Promise<void> {
  for (let index = 0; index < statements.length; index += statementBatchSize) {
    await db.batch(statements.slice(index, index + statementBatchSize));
  }
}

async function parseWorkoutRequest(
  request: Request,
): Promise<WorkoutRequestPayload> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    throw new HttpError(400, 'invalid_json', 'The request body must be JSON.');
  }
  if (!isObject(body) || !isObject(body.snapshot)) {
    throw new HttpError(
      422,
      'invalid_snapshot',
      'The request body must contain a workout snapshot.',
    );
  }

  const raw = body.snapshot;
  const dayTotals = parseDayTotals(raw.dayTotals);
  const sessions = parseSessions(raw.sessions);
  const preferences = isObject(raw.preferences) ? raw.preferences : {};
  const clientContext = isObject(body.clientContext) ? body.clientContext : {};
  const today = new Date().toISOString().slice(0, 10);
  const dayKey = optionalDayKey(clientContext.dayKey) ?? today;
  const weekKey = optionalDayKey(clientContext.weekKey) ?? weekStart(dayKey);
  return {
    snapshot: {
      dayTotals,
      sessions,
      preferences,
      updatedAt: optionalIsoDate(raw.updatedAt, 'updatedAt'),
      lastSyncedAt: optionalIsoDate(raw.lastSyncedAt, 'lastSyncedAt'),
    },
    dayKey,
    weekKey,
  };
}

function workoutStats(
  dayTotals: Record<string, number>,
  dayKey: string,
  weekKey: string,
): {
  todayCount: number;
  weekCount: number;
  bestDay: number;
  totalAllTime: number;
  streak: number;
} {
  const counts = Object.values(dayTotals);
  const totalAllTime = counts.reduce((total, count) => total + count, 0);
  const weekCount = Object.entries(dayTotals)
    .filter(([key]) => key >= weekKey && key <= dayKey)
    .reduce((total, [, count]) => total + count, 0);
  let streak = 0;
  let cursor = dayKey;
  if ((dayTotals[cursor] ?? 0) === 0) cursor = addDays(cursor, -1);
  while ((dayTotals[cursor] ?? 0) > 0) {
    streak += 1;
    cursor = addDays(cursor, -1);
  }
  return {
    todayCount: dayTotals[dayKey] ?? 0,
    weekCount,
    bestDay: counts.length === 0 ? 0 : Math.max(...counts),
    totalAllTime,
    streak,
  };
}

function optionalDayKey(value: unknown): string | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }
  return Number.isNaN(Date.parse(`${value}T00:00:00.000Z`)) ? null : value;
}

function weekStart(dayKey: string): string {
  const date = new Date(`${dayKey}T00:00:00.000Z`);
  const weekday = date.getUTCDay() === 0 ? 7 : date.getUTCDay();
  date.setUTCDate(date.getUTCDate() - (weekday - 1));
  return date.toISOString().slice(0, 10);
}

function addDays(dayKey: string, days: number): string {
  const date = new Date(`${dayKey}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function parseDayTotals(value: unknown): Record<string, number> {
  if (!isObject(value)) {
    throw invalidSnapshot('dayTotals must be an object.');
  }
  const entries = Object.entries(value);
  if (entries.length > maximumDayTotals) {
    throw invalidSnapshot('dayTotals contains too many days.');
  }

  const result: Record<string, number> = {};
  for (const [dayKey, reps] of entries) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dayKey) || !isCount(reps)) {
      throw invalidSnapshot('dayTotals contains an invalid day or rep count.');
    }
    result[dayKey] = reps;
  }
  return result;
}

function parseSessions(value: unknown): WorkoutSessionPayload[] {
  if (!Array.isArray(value)) {
    throw invalidSnapshot('sessions must be an array.');
  }
  if (value.length > maximumSessions) {
    throw invalidSnapshot('sessions contains too many entries.');
  }

  const ids = new Set<string>();
  return value.map((item) => {
    if (!isObject(item)) throw invalidSnapshot('A session is invalid.');
    const id = item.id;
    const date = item.date;
    const source = item.source;
    if (
      typeof id !== 'string' ||
      id.length === 0 ||
      id.length > 128 ||
      ids.has(id)
    ) {
      throw invalidSnapshot('A session has an invalid or duplicate id.');
    }
    if (typeof date !== 'string' || Number.isNaN(Date.parse(date))) {
      throw invalidSnapshot('A session has an invalid date.');
    }
    if (source !== 'manual' && source !== 'live') {
      throw invalidSnapshot('A session has an invalid source.');
    }
    if (!isCount(item.reps)) {
      throw invalidSnapshot('A session has an invalid rep count.');
    }
    ids.add(id);
    return {
      id,
      date,
      reps: item.reps,
      source,
      duration: optionalNonNegativeInteger(item.duration, 'duration'),
      averageRepDuration: optionalNonNegativeInteger(
        item.averageRepDuration,
        'averageRepDuration',
      ),
      manualAdjustments: boundedInteger(
        item.manualAdjustments ?? 0,
        -100_000,
        100_000,
        'manualAdjustments',
      ),
    };
  });
}

function optionalIsoDate(value: unknown, field: string): string | null {
  if (value == null) return null;
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    throw invalidSnapshot(`${field} must be an ISO-8601 date.`);
  }
  return value;
}

function optionalNonNegativeInteger(
  value: unknown,
  field: string,
): number | null {
  if (value == null) return null;
  return boundedInteger(value, 0, Number.MAX_SAFE_INTEGER, field);
}

function boundedInteger(
  value: unknown,
  minimum: number,
  maximum: number,
  field: string,
): number {
  if (
    typeof value !== 'number' ||
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw invalidSnapshot(`${field} must be a valid integer.`);
  }
  return value;
}

function isCount(value: unknown): value is number {
  return (
    typeof value === 'number' &&
    Number.isSafeInteger(value) &&
    value >= 0 &&
    value <= 1_000_000
  );
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value != null && !Array.isArray(value);
}

function invalidSnapshot(message: string): HttpError {
  return new HttpError(422, 'invalid_snapshot', message);
}

async function sha256(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(bytes)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}
