import {createRemoteJWKSet, jwtVerify} from 'jose';

import type {AuthenticatedUser, AuthVerifier} from './env';
import {HttpError} from './http';

const firebaseJwks = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/' +
      'securetoken@system.gserviceaccount.com',
  ),
);

export const verifyFirebaseRequest: AuthVerifier = async (request, env) => {
  const authorization = request.headers.get('authorization');
  const match = authorization?.match(/^Bearer\s+(.+)$/i);
  if (match == null) {
    throw new HttpError(
      401,
      'authentication_required',
      'A Firebase ID token is required.',
    );
  }

  try {
    const {payload} = await jwtVerify(match[1], firebaseJwks, {
      audience: env.FIREBASE_PROJECT_ID,
      issuer: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,
    });
    if (payload.sub == null || payload.sub.length === 0) {
      throw new Error('Token subject is missing.');
    }

    return {
      uid: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
      name: typeof payload.name === 'string' ? payload.name : undefined,
      picture:
        typeof payload.picture === 'string' ? payload.picture : undefined,
    } satisfies AuthenticatedUser;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(
      401,
      'invalid_token',
      'The Firebase ID token is invalid or expired.',
    );
  }
};
