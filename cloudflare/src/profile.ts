import type {AuthenticatedUser, Env} from './env';
import {HttpError, jsonResponse} from './http';

interface ProfileRow {
  uid: string;
  email: string | null;
  display_name: string | null;
  photo_url: string | null;
  username: string | null;
  username_lower: string | null;
  created_at: string | null;
  updated_at: string;
  today_count: number | null;
  week_count: number | null;
  total_all_time: number | null;
  best_day: number | null;
  streak: number | null;
}

const usernamePattern = /^[a-z0-9_]{3,20}$/;

export async function ensureProfile(
  env: Env,
  user: AuthenticatedUser,
): Promise<ProfileRow> {
  const existing = await profileRow(env.DB, user.uid);
  const now = new Date().toISOString();
  const displayName =
    cleanOptional(user.name) ??
    cleanOptional(existing?.display_name) ??
    cleanOptional(existing?.username) ??
    'Pusher';
  const photoUrl = cleanOptional(user.picture) ?? existing?.photo_url ?? null;
  const email = cleanOptional(user.email) ?? existing?.email ?? null;
  const createdAt = existing?.created_at ?? now;
  const privateJson = JSON.stringify({
    uid: user.uid,
    email,
    displayName,
    photoUrl,
    username: existing?.username ?? null,
    usernameLower: existing?.username_lower ?? null,
    createdAt,
    updatedAt: now,
  });
  const publicJson = JSON.stringify({
    uid: user.uid,
    displayName,
    photoUrl,
    username: existing?.username ?? null,
    usernameLower: existing?.username_lower ?? null,
    createdAt,
    updatedAt: now,
  });

  await env.DB.prepare(
    `INSERT INTO users (
      uid, email, display_name, photo_url, username, username_lower,
      private_json, public_json, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(uid) DO UPDATE SET
      email = excluded.email,
      display_name = excluded.display_name,
      photo_url = excluded.photo_url,
      private_json = excluded.private_json,
      public_json = excluded.public_json,
      updated_at = excluded.updated_at`,
  )
    .bind(
      user.uid,
      email,
      displayName,
      photoUrl,
      existing?.username ?? null,
      existing?.username_lower ?? null,
      privateJson,
      publicJson,
      createdAt,
      now,
    )
    .run();

  return (await profileRow(env.DB, user.uid))!;
}

export async function getOwnProfile(
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const row = await ensureProfile(env, user);
  return jsonResponse({profile: profileJson(row, true)});
}

export async function claimUsername(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const body = await jsonObject(request);
  const rawUsername = body.username;
  if (typeof rawUsername !== 'string') {
    throw new HttpError(422, 'invalid_username', 'A username is required.');
  }
  const username = rawUsername.trim();
  const normalized = username.toLowerCase();
  if (!usernamePattern.test(normalized)) {
    throw new HttpError(
      422,
      'invalid_username',
      'Use 3-20 letters, numbers, or underscores.',
    );
  }

  const current = await ensureProfile(env, user);
  const owner = await env.DB.prepare(
    'SELECT uid FROM username_claims WHERE username_lower = ?',
  )
    .bind(normalized)
    .first<{uid: string}>();
  if (owner != null && owner.uid !== user.uid) {
    throw new HttpError(409, 'username_taken', 'That username is already taken.');
  }

  const now = new Date().toISOString();
  const displayName = cleanOptional(user.name) ?? current.display_name ?? username;
  const privateJson = JSON.stringify({
    uid: user.uid,
    email: current.email,
    displayName,
    photoUrl: current.photo_url,
    username,
    usernameLower: normalized,
    createdAt: current.created_at,
    updatedAt: now,
  });
  const publicJson = JSON.stringify({
    uid: user.uid,
    displayName,
    photoUrl: current.photo_url,
    username,
    usernameLower: normalized,
    createdAt: current.created_at,
    updatedAt: now,
  });

  const statements: D1PreparedStatement[] = [];
  if (
    current.username_lower != null &&
    current.username_lower !== normalized
  ) {
    statements.push(
      env.DB.prepare(
        'DELETE FROM username_claims WHERE username_lower = ? AND uid = ?',
      ).bind(current.username_lower, user.uid),
    );
  }
  const claimJson = JSON.stringify({
    uid: user.uid,
    username,
    usernameLower: normalized,
  });
  statements.push(
    owner == null
      ? env.DB.prepare(
          `INSERT INTO username_claims (
            username_lower, uid, username, source_json, updated_at
          ) VALUES (?, ?, ?, ?, ?)`,
        ).bind(normalized, user.uid, username, claimJson, now)
      : env.DB.prepare(
          `UPDATE username_claims
           SET username = ?, source_json = ?, updated_at = ?
           WHERE username_lower = ? AND uid = ?`,
        ).bind(username, claimJson, now, normalized, user.uid),
    env.DB.prepare(
      `UPDATE users SET
        display_name = ?, username = ?, username_lower = ?,
        private_json = ?, public_json = ?, updated_at = ?
      WHERE uid = ?`,
    ).bind(
      displayName,
      username,
      normalized,
      privateJson,
      publicJson,
      now,
      user.uid,
    ),
  );

  try {
    await env.DB.batch(statements);
  } catch (error) {
    if (String(error).includes('UNIQUE constraint failed')) {
      throw new HttpError(409, 'username_taken', 'That username is already taken.');
    }
    throw error;
  }

  const updated = await profileRow(env.DB, user.uid);
  return jsonResponse({profile: profileJson(updated!, true)});
}

export async function searchProfiles(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const query = new URL(request.url).searchParams.get('q')?.trim().toLowerCase();
  if (query == null || query.length < 2) return jsonResponse({profiles: []});
  if (query.length > 20 || !/^[a-z0-9_]+$/.test(query)) {
    return jsonResponse({profiles: []});
  }

  const result = await env.DB.prepare(
    `${profileSelect()}
     WHERE u.uid <> ? AND u.username_lower >= ? AND u.username_lower < ?
     ORDER BY u.username_lower ASC
     LIMIT 8`,
  )
    .bind(user.uid, query, `${query}\uf8ff`)
    .all<ProfileRow>();
  return jsonResponse({
    profiles: result.results.map((row) => profileJson(row, false)),
  });
}

export async function deleteAccountData(
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  await env.DB.prepare('DELETE FROM users WHERE uid = ?').bind(user.uid).run();
  return new Response(null, {status: 204});
}

export async function profileRow(
  db: D1Database,
  uid: string,
): Promise<ProfileRow | null> {
  return db
    .prepare(`${profileSelect()} WHERE u.uid = ?`)
    .bind(uid)
    .first<ProfileRow>();
}

export function profileJson(
  row: ProfileRow,
  includeEmail: boolean,
): Record<string, unknown> {
  return {
    uid: row.uid,
    ...(includeEmail ? {email: row.email} : {}),
    displayName: row.display_name,
    photoUrl: row.photo_url,
    username: row.username,
    usernameLower: row.username_lower,
    todayCount: row.today_count ?? 0,
    weekCount: row.week_count ?? 0,
    totalAllTime: row.total_all_time ?? 0,
    bestDay: row.best_day ?? 0,
    streak: row.streak ?? 0,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function profileSelect(): string {
  return `SELECT
    u.uid, u.email, u.display_name, u.photo_url, u.username,
    u.username_lower, u.created_at, u.updated_at,
    fs.today_count, fs.week_count, fs.total_all_time, fs.best_day, fs.streak
  FROM users u
  LEFT JOIN friend_stats fs ON fs.uid = u.uid`;
}

async function jsonObject(request: Request): Promise<Record<string, unknown>> {
  try {
    const value: unknown = await request.json();
    if (value != null && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, unknown>;
    }
  } catch {
    // Converted to a stable API error below.
  }
  throw new HttpError(400, 'invalid_json', 'The request body must be a JSON object.');
}

function cleanOptional(value: string | null | undefined): string | null {
  const cleaned = value?.trim();
  return cleaned == null || cleaned.length === 0 ? null : cleaned;
}
