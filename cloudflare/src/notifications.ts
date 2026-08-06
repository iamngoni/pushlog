import type {Env} from './env';
import type {AuthenticatedUser} from './env';
import {HttpError, jsonResponse} from './http';

interface FriendScoreRow {
  uid: string;
  today_count: number;
  today_key: string | null;
}

interface ActorRow {
  display_name: string | null;
  username: string | null;
}

interface GatewayResponse {
  successCount?: number;
  failureCount?: number;
  invalidTokens?: string[];
}

interface NotificationRow {
  notification_id: string;
  type: string;
  title: string | null;
  body: string | null;
  actor_uid: string | null;
  competitor_uid: string | null;
  day_key: string | null;
  payload_json: string;
  created_at: string | null;
}

export async function getNotifications(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const url = new URL(request.url);
  const requestedLimit = Number.parseInt(url.searchParams.get('limit') ?? '25', 10);
  const limit = Number.isFinite(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 100)
    : 25;
  const notifications = await env.DB.prepare(
    `SELECT notification_id, type, title, body, actor_uid, competitor_uid,
            day_key, payload_json, created_at
     FROM notification_events
     WHERE uid = ? AND read_at IS NULL
     ORDER BY created_at ASC
     LIMIT ?`,
  )
    .bind(user.uid, limit)
    .all<NotificationRow>();

  return jsonResponse({
    notifications: notifications.results.map((notification) => ({
      notificationId: notification.notification_id,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      actorUid: notification.actor_uid,
      competitorUid: notification.competitor_uid,
      dayKey: notification.day_key,
      payload: safeJson(notification.payload_json),
      createdAt: notification.created_at,
    })),
  });
}

export async function markNotificationsRead(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const body = await notificationBody(request);
  const notificationIds = body.notificationIds;
  if (
    !Array.isArray(notificationIds) ||
    notificationIds.length === 0 ||
    notificationIds.length > 100 ||
    notificationIds.some(
      (notificationId) =>
        typeof notificationId !== 'string' ||
        notificationId.length === 0 ||
        notificationId.length > 128,
    )
  ) {
    throw new HttpError(
      422,
      'invalid_notifications',
      'notificationIds must contain between 1 and 100 notification IDs.',
    );
  }
  const placeholders = notificationIds.map(() => '?').join(', ');
  await env.DB.prepare(
    `UPDATE notification_events
     SET read_at = COALESCE(read_at, ?)
     WHERE uid = ? AND notification_id IN (${placeholders})`,
  )
    .bind(new Date().toISOString(), user.uid, ...notificationIds)
    .run();
  return jsonResponse({status: 'read'});
}

export async function notifyFriendsPassed(
  env: Env,
  actorUid: string,
  previousCount: number,
  currentCount: number,
  dayKey: string,
): Promise<void> {
  if (currentCount <= previousCount) return;
  const scores = await env.DB.prepare(
    `SELECT stats.uid, stats.today_count, stats.today_key
     FROM friend_links links
     JOIN friend_stats stats ON stats.uid = links.friend_uid
     WHERE links.owner_uid = ?`,
  )
    .bind(actorUid)
    .all<FriendScoreRow>();
  const passed = scores.results.filter((friend) => {
    const friendCount = friend.today_key === dayKey ? friend.today_count : 0;
    return previousCount <= friendCount && currentCount > friendCount;
  });
  if (passed.length === 0) return;

  const actor = await env.DB.prepare(
    'SELECT display_name, username FROM users WHERE uid = ?',
  )
    .bind(actorUid)
    .first<ActorRow>();
  const actorName = actor?.username ?? actor?.display_name ?? 'A friend';
  await Promise.all(
    passed.map(async (friend) => {
      const friendCount = friend.today_key === dayKey ? friend.today_count : 0;
      const notificationId = crypto.randomUUID();
      const title = `@${actorName.replace(/^@/, '')} passed you`;
      const lead = currentCount - friendCount;
      const body = `Log ${lead + 1} reps to take the lead back.`;
      const now = new Date().toISOString();
      await env.DB.prepare(
        `INSERT INTO notification_events (
          uid, notification_id, type, title, body, actor_uid,
          competitor_uid, day_key, delivery_status, payload_json, created_at
        ) VALUES (?, ?, 'lead_change', ?, ?, ?, ?, ?, 'pending', ?, ?)`,
      )
        .bind(
          friend.uid,
          notificationId,
          title,
          body,
          actorUid,
          actorUid,
          dayKey,
          JSON.stringify({score: currentCount, previousLead: friendCount}),
          now,
        )
        .run();

      const deliveryStatus = await deliverToUser(env, friend.uid, {
        notificationId,
        title,
        body,
        data: {
          type: 'lead_change',
          notificationId,
          actorUid,
          competitorUid: actorUid,
          dayKey,
          score: String(currentCount),
        },
      });
      await env.DB.prepare(
        `UPDATE notification_events
         SET delivery_status = ?, delivered_at = ?
         WHERE uid = ? AND notification_id = ?`,
      )
        .bind(
          deliveryStatus,
          deliveryStatus === 'delivered' ? new Date().toISOString() : null,
          friend.uid,
          notificationId,
        )
        .run();
    }),
  );
}

async function notificationBody(
  request: Request,
): Promise<Record<string, unknown>> {
  try {
    const body = (await request.json()) as unknown;
    if (body != null && typeof body === 'object' && !Array.isArray(body)) {
      return body as Record<string, unknown>;
    }
  } catch {
    // Converted to a stable API error below.
  }
  throw new HttpError(400, 'invalid_json', 'The request body must be JSON.');
}

function safeJson(value: string): unknown {
  try {
    return JSON.parse(value) as unknown;
  } catch {
    return {};
  }
}

async function deliverToUser(
  env: Env,
  uid: string,
  notification: {
    notificationId: string;
    title: string;
    body: string;
    data: Record<string, string>;
  },
): Promise<string> {
  const devices = await env.DB.prepare(
    'SELECT token FROM devices WHERE uid = ? ORDER BY updated_at DESC',
  )
    .bind(uid)
    .all<{token: string}>();
  if (devices.results.length === 0) return 'no_devices';
  if (env.FCM_GATEWAY_URL == null || env.FCM_GATEWAY_SECRET == null) {
    console.error('FCM gateway is not configured', {
      notificationId: notification.notificationId,
    });
    return 'not_configured';
  }

  try {
    const response = await fetch(env.FCM_GATEWAY_URL, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${env.FCM_GATEWAY_SECRET}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        tokens: devices.results.map((device) => device.token),
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data,
      }),
    });
    if (!response.ok) {
      console.error('FCM gateway request failed', {
        notificationId: notification.notificationId,
        status: response.status,
      });
      return 'failed';
    }
    const result = (await response.json()) as GatewayResponse;
    const invalidTokens = Array.isArray(result.invalidTokens)
      ? result.invalidTokens
      : [];
    for (const token of invalidTokens) {
      await env.DB.prepare('DELETE FROM devices WHERE uid = ? AND token = ?')
        .bind(uid, token)
        .run();
    }
    return (result.successCount ?? 0) > 0 ? 'delivered' : 'failed';
  } catch (error) {
    console.error('FCM gateway delivery failed', {
      notificationId: notification.notificationId,
      error: error instanceof Error ? error.message : String(error),
    });
    return 'failed';
  }
}
