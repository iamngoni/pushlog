export interface Env {
  DB: D1Database;
  FIREBASE_PROJECT_ID: string;
  ENVIRONMENT: string;
  FCM_GATEWAY_URL?: string;
  FCM_GATEWAY_SECRET?: string;
}

export interface AuthenticatedUser {
  uid: string;
  email?: string;
  name?: string;
  picture?: string;
}

export type AuthVerifier = (
  request: Request,
  env: Env,
) => Promise<AuthenticatedUser>;
