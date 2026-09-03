import * as Sentry from "@sentry/cloudflare";
import RustWorker from "../build/worker/shim.mjs";

function scrubRequest(event) {
  if (!event.request) return event;

  delete event.request.cookies;
  delete event.request.data;
  delete event.request.headers;
  delete event.request.query_string;
  if (event.request.url) {
    try {
      const url = new URL(event.request.url);
      event.request.url = `${url.origin}${url.pathname}`;
    } catch {
      delete event.request.url;
    }
  }
  return event;
}

const handler = {
  async fetch(request, env, context) {
    const worker = new RustWorker(context, env);
    const response = await worker.fetch(request);
    if (response.status >= 500) {
      const url = new URL(request.url);
      Sentry.captureMessage(`Worker returned HTTP ${response.status}`, {
        level: "error",
        tags: {
          method: request.method,
          request_id: response.headers.get("x-request-id") ?? "missing",
          route: url.pathname,
          status: `${response.status}`,
        },
      });
    }
    return response;
  },

  async scheduled(controller, env, context) {
    const worker = new RustWorker(context, env);
    return worker.scheduled(controller);
  },
};

export default Sentry.withSentry(
  (env) => ({
    dsn: env.SENTRY_DSN,
    environment: env.ENVIRONMENT,
    release: env.CF_VERSION_METADATA?.id
      ? `pushlog-worker@${env.CF_VERSION_METADATA.id}`
      : "pushlog-worker@local",
    sendDefaultPii: false,
    tracesSampleRate: env.ENVIRONMENT === "production" ? 0.1 : 1,
    beforeSend: scrubRequest,
  }),
  handler,
);
