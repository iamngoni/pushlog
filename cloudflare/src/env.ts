export interface Env {
  DB: D1Database;
  FIREBASE_PROJECT_ID: string;
  DATA_MODE: string;
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
