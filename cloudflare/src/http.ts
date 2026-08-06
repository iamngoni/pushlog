export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export function jsonResponse(
  value: unknown,
  init: ResponseInit = {},
): Response {
  const headers = new Headers(init.headers);
  headers.set('content-type', 'application/json; charset=utf-8');
  headers.set('cache-control', 'no-store');
  headers.set('x-content-type-options', 'nosniff');
  return new Response(JSON.stringify(value), {...init, headers});
}

export function errorResponse(error: HttpError, requestId: string): Response {
  return jsonResponse(
    {
      error: {
        code: error.code,
        message: error.message,
        requestId,
      },
    },
    {status: error.status},
  );
}

export function methodNotAllowed(...methods: string[]): Response {
  return jsonResponse(
    {
      error: {
        code: 'method_not_allowed',
        message: 'Method not allowed.',
      },
    },
    {
      status: 405,
      headers: {allow: methods.join(', ')},
    },
  );
}
