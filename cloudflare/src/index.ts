import {verifyFirebaseRequest} from './auth';
import {registerDevice, unregisterDevice} from './devices';
import type {AuthVerifier, Env} from './env';
import {
  acceptFriendRequest,
  cancelFriendRequest,
  declineFriendRequest,
  getFriendRequests,
  getFriends,
  removeFriend,
  sendFriendRequest,
} from './friends';
import {
  errorResponse,
  HttpError,
  jsonResponse,
  methodNotAllowed,
} from './http';
import {getNotifications, markNotificationsRead} from './notifications';
import {
  claimUsername,
  deleteAccountData,
  getOwnProfile,
  searchProfiles,
} from './profile';
import {getWorkoutSnapshot, putWorkoutSnapshot} from './workout';

export async function handleRequest(
  request: Request,
  env: Env,
  verifyAuth: AuthVerifier = verifyFirebaseRequest,
  context?: ExecutionContext,
): Promise<Response> {
  const requestId = crypto.randomUUID();
  const url = new URL(request.url);

  try {
    if (url.pathname === '/health') {
      if (request.method !== 'GET' && request.method !== 'HEAD') {
        return methodNotAllowed('GET', 'HEAD');
      }
      await env.DB.prepare('SELECT 1').first();
      const response = jsonResponse({
        status: 'ok',
        service: 'pushlog-api',
        environment: env.ENVIRONMENT,
        database: 'd1',
      });
      return request.method === 'HEAD'
        ? new Response(null, {status: response.status, headers: response.headers})
        : response;
    }

    if (url.pathname === '/v1/workout-snapshot') {
      const user = await verifyAuth(request, env);
      if (request.method === 'GET') {
        return await getWorkoutSnapshot(request, env, user);
      }
      if (request.method === 'PUT') {
        return await putWorkoutSnapshot(request, env, user, context);
      }
      return methodNotAllowed('GET', 'PUT');
    }

    if (url.pathname === '/v1/profile') {
      const user = await verifyAuth(request, env);
      if (request.method === 'GET' || request.method === 'PUT') {
        return await getOwnProfile(env, user);
      }
      return methodNotAllowed('GET', 'PUT');
    }

    if (url.pathname === '/v1/profile/username') {
      const user = await verifyAuth(request, env);
      if (request.method === 'PUT') {
        return await claimUsername(request, env, user);
      }
      return methodNotAllowed('PUT');
    }

    if (url.pathname === '/v1/users/search') {
      const user = await verifyAuth(request, env);
      if (request.method === 'GET') {
        return await searchProfiles(request, env, user);
      }
      return methodNotAllowed('GET');
    }

    if (url.pathname === '/v1/friends') {
      const user = await verifyAuth(request, env);
      if (request.method === 'GET') return await getFriends(request, env, user);
      if (request.method === 'DELETE') return await removeFriend(request, env, user);
      return methodNotAllowed('GET', 'DELETE');
    }

    if (url.pathname === '/v1/friend-requests') {
      const user = await verifyAuth(request, env);
      if (request.method === 'GET') {
        return await getFriendRequests(request, env, user);
      }
      if (request.method === 'POST') {
        return await sendFriendRequest(request, env, user);
      }
      return methodNotAllowed('GET', 'POST');
    }

    if (url.pathname === '/v1/friend-requests/accept') {
      const user = await verifyAuth(request, env);
      if (request.method === 'POST') {
        return await acceptFriendRequest(request, env, user);
      }
      return methodNotAllowed('POST');
    }

    if (url.pathname === '/v1/friend-requests/decline') {
      const user = await verifyAuth(request, env);
      if (request.method === 'POST') {
        return await declineFriendRequest(request, env, user);
      }
      return methodNotAllowed('POST');
    }

    if (url.pathname === '/v1/friend-requests/cancel') {
      const user = await verifyAuth(request, env);
      if (request.method === 'POST') {
        return await cancelFriendRequest(request, env, user);
      }
      return methodNotAllowed('POST');
    }

    if (url.pathname === '/v1/devices') {
      const user = await verifyAuth(request, env);
      if (request.method === 'PUT') return await registerDevice(request, env, user);
      if (request.method === 'DELETE') {
        return await unregisterDevice(request, env, user);
      }
      return methodNotAllowed('PUT', 'DELETE');
    }

    if (url.pathname === '/v1/notifications') {
      const user = await verifyAuth(request, env);
      if (request.method === 'GET') {
        return await getNotifications(request, env, user);
      }
      if (request.method === 'POST') {
        return await markNotificationsRead(request, env, user);
      }
      return methodNotAllowed('GET', 'POST');
    }

    if (url.pathname === '/v1/account') {
      const user = await verifyAuth(request, env);
      if (request.method === 'DELETE') return await deleteAccountData(env, user);
      return methodNotAllowed('DELETE');
    }

    throw new HttpError(404, 'not_found', 'Route not found.');
  } catch (error) {
    if (error instanceof HttpError) return errorResponse(error, requestId);
    console.error('Unhandled request error', {
      requestId,
      method: request.method,
      pathname: url.pathname,
      error: error instanceof Error ? error.message : String(error),
    });
    return errorResponse(
      new HttpError(500, 'internal_error', 'An unexpected error occurred.'),
      requestId,
    );
  }
}

export default {
  fetch(request, env, context): Promise<Response> {
    return handleRequest(request, env, verifyFirebaseRequest, context);
  },
} satisfies ExportedHandler<Env>;
