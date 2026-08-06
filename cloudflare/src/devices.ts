import type {AuthenticatedUser, Env} from './env';
import {HttpError, jsonResponse} from './http';
import {ensureProfile} from './profile';

export async function registerDevice(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const {token, platform} = await devicePayload(request);
  await ensureProfile(env, user);
  const now = new Date().toISOString();
  await env.DB.batch([
    env.DB.prepare('DELETE FROM devices WHERE token = ? AND uid <> ?').bind(
      token,
      user.uid,
    ),
    env.DB.prepare(
      `INSERT INTO devices (uid, token, platform, updated_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(uid, token) DO UPDATE SET
         platform = excluded.platform, updated_at = excluded.updated_at`,
    ).bind(user.uid, token, platform, now),
  ]);
  return jsonResponse({status: 'registered'});
}

export async function unregisterDevice(
  request: Request,
  env: Env,
  user: AuthenticatedUser,
): Promise<Response> {
  const {token} = await devicePayload(request, false);
  await env.DB.prepare('DELETE FROM devices WHERE uid = ? AND token = ?')
    .bind(user.uid, token)
    .run();
  return new Response(null, {status: 204});
}

async function devicePayload(
  request: Request,
  requirePlatform = true,
): Promise<{token: string; platform: string | null}> {
  let value: unknown;
  try {
    value = await request.json();
  } catch {
    throw new HttpError(400, 'invalid_json', 'The request body must be JSON.');
  }
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpError(400, 'invalid_json', 'The request body must be a JSON object.');
  }
  const body = value as Record<string, unknown>;
  if (
    typeof body.token !== 'string' ||
    body.token.length < 16 ||
    body.token.length > 4_096
  ) {
    throw new HttpError(422, 'invalid_token', 'The device token is invalid.');
  }
  const allowedPlatforms = new Set(['android', 'ios', 'macos']);
  const platform =
    typeof body.platform === 'string' && allowedPlatforms.has(body.platform)
      ? body.platform
      : null;
  if (requirePlatform && platform == null) {
    throw new HttpError(422, 'invalid_platform', 'The device platform is invalid.');
  }
  return {token: body.token, platform};
}
