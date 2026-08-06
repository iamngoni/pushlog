import {verifyFirebaseRequest} from './auth';
import type {AuthVerifier, Env} from './env';
import {
  errorResponse,
  HttpError,
  jsonResponse,
  methodNotAllowed,
} from './http';
import {getWorkoutSnapshot, putWorkoutSnapshot} from './workout';

export async function handleRequest(
  request: Request,
  env: Env,
  verifyAuth: AuthVerifier = verifyFirebaseRequest,
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
        environment: 'staging',
        dataMode: env.DATA_MODE,
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
        return await putWorkoutSnapshot(request, env, user);
      }
      return methodNotAllowed('GET', 'PUT');
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
  fetch(request, env): Promise<Response> {
    return handleRequest(request, env);
  },
} satisfies ExportedHandler<Env>;
