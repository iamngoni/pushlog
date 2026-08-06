import type {AuthenticatedUser, Env} from './env';
import {HttpError, jsonResponse} from './http';
import {ensureProfile, profileJson, profileRow} from './profile';

interface FriendRow {
  uid: string;
  email: null;
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

interface RequestRow extends FriendRow {
  request_created_at: string | null;
}

export async function getFriends(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  await ensureProfile(env, user);
  const url = new URL(request.url);
  const dayKey = validDayKey(url.searchParams.get('dayKey')) ??
    new Date().toISOString().slice(0, 10);
  const weekKey = validDayKey(url.searchParams.get('weekKey')) ??
    weekStart(dayKey);
  const result = await env.DB.prepare(
    `SELECT
      friend.uid, NULL AS email, friend.display_name, friend.photo_url,
      friend.username, friend.username_lower, friend.created_at,
      friend.updated_at,
      CASE WHEN stats.today_key = ? THEN stats.today_count ELSE 0 END AS today_count,
      CASE WHEN stats.week_key = ? THEN stats.week_count ELSE 0 END AS week_count,
      stats.total_all_time, stats.best_day, stats.streak
    FROM friend_links links
    JOIN users friend ON friend.uid = links.friend_uid
    LEFT JOIN friend_stats stats ON stats.uid = friend.uid
    WHERE links.owner_uid = ?
    ORDER BY stats.today_count DESC, friend.username_lower ASC`,
  )
    .bind(dayKey, weekKey, user.uid)
    .all<FriendRow>();
  return jsonResponse({
    friends: result.results.map((row) => profileJson(row, false)),
  });
}

function validDayKey(value: string | null): string | null {
  if (value == null || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  return Number.isNaN(Date.parse(`${value}T00:00:00.000Z`)) ? null : value;
}

function weekStart(dayKey: string): string {
  const date = new Date(`${dayKey}T00:00:00.000Z`);
  const weekday = date.getUTCDay() === 0 ? 7 : date.getUTCDay();
  date.setUTCDate(date.getUTCDate() - (weekday - 1));
  return date.toISOString().slice(0, 10);
}

export async function getFriendRequests(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  await ensureProfile(env, user);
  const direction = new URL(request.url).searchParams.get('direction');
  if (direction !== 'incoming' && direction !== 'outgoing') {
    throw new HttpError(
      422,
      'invalid_direction',
      'Direction must be incoming or outgoing.',
    );
  }
  const ownerColumn = direction === 'incoming' ? 'receiver_uid' : 'sender_uid';
  const otherColumn = direction === 'incoming' ? 'sender_uid' : 'receiver_uid';
  const result = await env.DB.prepare(
    `SELECT
      other.uid, NULL AS email, other.display_name, other.photo_url,
      other.username, other.username_lower, other.created_at,
      other.updated_at, stats.today_count, stats.week_count,
      stats.total_all_time, stats.best_day, stats.streak,
      requests.created_at AS request_created_at
    FROM friend_requests requests
    JOIN users other ON other.uid = requests.${otherColumn}
    LEFT JOIN friend_stats stats ON stats.uid = other.uid
    WHERE requests.${ownerColumn} = ? AND requests.status = 'pending'
    ORDER BY requests.created_at DESC`,
  )
    .bind(user.uid)
    .all<RequestRow>();

  return jsonResponse({
    requests: result.results.map((row) => ({
      ...profileJson(row, false),
      createdAt: row.request_created_at,
    })),
  });
}

export async function sendFriendRequest(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const receiverUid = await uidFromBody(request, 'receiverUid');
  if (receiverUid === user.uid) {
    throw new HttpError(422, 'invalid_friend', 'You cannot add yourself.');
  }
  await ensureProfile(env, user);
  if ((await profileRow(env.DB, receiverUid)) == null) {
    throw new HttpError(404, 'profile_not_found', 'That profile no longer exists.');
  }

  const friendship = await env.DB.prepare(
    'SELECT 1 AS found FROM friend_links WHERE owner_uid = ? AND friend_uid = ?',
  )
    .bind(user.uid, receiverUid)
    .first();
  if (friendship != null) return jsonResponse({status: 'already_friends'});

  const reciprocal = await env.DB.prepare(
    `SELECT 1 AS found FROM friend_requests
     WHERE sender_uid = ? AND receiver_uid = ? AND status = 'pending'`,
  )
    .bind(receiverUid, user.uid)
    .first();
  if (reciprocal != null) {
    await accept(env.DB, user.uid, receiverUid);
    return jsonResponse({status: 'accepted'});
  }

  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO friend_requests (
      sender_uid, receiver_uid, status, created_at, updated_at
    ) VALUES (?, ?, 'pending', ?, ?)
    ON CONFLICT(sender_uid, receiver_uid) DO UPDATE SET
      status = 'pending', created_at = excluded.created_at,
      updated_at = excluded.updated_at`,
  )
    .bind(user.uid, receiverUid, now, now)
    .run();
  return jsonResponse({status: 'pending'}, {status: 201});
}

export async function acceptFriendRequest(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const requesterUid = await uidFromBody(request, 'requesterUid');
  const pending = await env.DB.prepare(
    `SELECT 1 AS found FROM friend_requests
     WHERE sender_uid = ? AND receiver_uid = ? AND status = 'pending'`,
  )
    .bind(requesterUid, user.uid)
    .first();
  if (pending == null) {
    throw new HttpError(404, 'request_not_found', 'That friend request is no longer open.');
  }
  await accept(env.DB, user.uid, requesterUid);
  return jsonResponse({status: 'accepted'});
}

export async function declineFriendRequest(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const requesterUid = await uidFromBody(request, 'requesterUid');
  const now = new Date().toISOString();
  await env.DB.prepare(
    `UPDATE friend_requests SET status = 'declined', updated_at = ?
     WHERE sender_uid = ? AND receiver_uid = ? AND status = 'pending'`,
  )
    .bind(now, requesterUid, user.uid)
    .run();
  return new Response(null, {status: 204});
}

export async function cancelFriendRequest(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const receiverUid = await uidFromBody(request, 'receiverUid');
  const now = new Date().toISOString();
  await env.DB.prepare(
    `UPDATE friend_requests SET status = 'cancelled', updated_at = ?
     WHERE sender_uid = ? AND receiver_uid = ? AND status = 'pending'`,
  )
    .bind(now, user.uid, receiverUid)
    .run();
  return new Response(null, {status: 204});
}

export async function removeFriend(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const friendUid = await uidFromBody(request, 'friendUid');
  await env.DB.batch([
    env.DB.prepare(
      `DELETE FROM friend_links
       WHERE (owner_uid = ? AND friend_uid = ?)
          OR (owner_uid = ? AND friend_uid = ?)`,
    ).bind(user.uid, friendUid, friendUid, user.uid),
    env.DB.prepare(
      `UPDATE friend_requests SET status = 'cancelled', updated_at = ?
       WHERE ((sender_uid = ? AND receiver_uid = ?)
          OR (sender_uid = ? AND receiver_uid = ?))
         AND status = 'pending'`,
    ).bind(new Date().toISOString(), user.uid, friendUid, friendUid, user.uid),
  ]);
  return new Response(null, {status: 204});
}

async function accept(
  db: D1Database,
  receiverUid: string,
  requesterUid: string,
): Promise<void> {
  const now = new Date().toISOString();
  await db.batch([
    db.prepare(
      `INSERT INTO friend_links (owner_uid, friend_uid, added_at, source_json)
       VALUES (?, ?, ?, '{}')
       ON CONFLICT(owner_uid, friend_uid) DO UPDATE SET added_at = excluded.added_at`,
    ).bind(receiverUid, requesterUid, now),
    db.prepare(
      `INSERT INTO friend_links (owner_uid, friend_uid, added_at, source_json)
       VALUES (?, ?, ?, '{}')
       ON CONFLICT(owner_uid, friend_uid) DO UPDATE SET added_at = excluded.added_at`,
    ).bind(requesterUid, receiverUid, now),
    db.prepare(
      `UPDATE friend_requests SET status = 'accepted', updated_at = ?
       WHERE ((sender_uid = ? AND receiver_uid = ?)
          OR (sender_uid = ? AND receiver_uid = ?))
         AND status = 'pending'`,
    ).bind(now, requesterUid, receiverUid, receiverUid, requesterUid),
  ]);
}

async function uidFromBody(request: Request, key: string): Promise<string> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    throw new HttpError(400, 'invalid_json', 'The request body must be JSON.');
  }
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    throw new HttpError(400, 'invalid_json', 'The request body must be a JSON object.');
  }
  const uid = (body as Record<string, unknown>)[key];
  if (typeof uid !== 'string' || uid.length === 0 || uid.length > 128) {
    throw new HttpError(422, 'invalid_uid', `${key} is invalid.`);
  }
  return uid;
}
