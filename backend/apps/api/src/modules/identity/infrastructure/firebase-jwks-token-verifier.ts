import { err, ok, type Clock } from '@stanmieszkania/shared';
import { createLocalJWKSet, jwtVerify, type JSONWebKeySet, type JWTVerifyGetKey } from 'jose';
import { z } from 'zod';
import { authTokenInvalidError } from '../domain/identity.errors';
import type { TokenVerifierPort, VerifiedIdentityClaims } from '../domain/token-verifier.port';
import {
  DEFAULT_JWKS_CACHE_TTL_MS,
  FIREBASE_CLOCK_TOLERANCE_SECONDS,
  FIREBASE_ISSUER_PREFIX,
  FIREBASE_JWKS_URL,
  FIREBASE_JWT_ALGORITHM,
  FIREBASE_UID_MAX_LENGTH,
  MAX_AGE_RADIX,
  SECONDS_PER_MILLISECOND,
} from './firebase-jwks.constants';

export type FetchFn = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export interface FirebaseJwksTokenVerifierDeps {
  readonly firebaseProjectId: string | undefined;
  readonly clock: Clock;
  readonly jwksResolver?: JWTVerifyGetKey;
  readonly fetchImpl?: FetchFn;
  readonly jwksUrl?: string;
}

const jwksResponseSchema = z.object({
  keys: z.array(z.record(z.string(), z.unknown())).min(1),
});

function parseCacheControlMaxAgeMs(cacheControl: string | null): number {
  if (cacheControl === null) {
    return DEFAULT_JWKS_CACHE_TTL_MS;
  }
  const match = /max-age=(\d+)/i.exec(cacheControl);
  if (match?.[1] === undefined) {
    return DEFAULT_JWKS_CACHE_TTL_MS;
  }
  const secondsValue = Number.parseInt(match[1], MAX_AGE_RADIX);
  return Number.isFinite(secondsValue) && secondsValue > 0
    ? secondsValue * SECONDS_PER_MILLISECOND
    : DEFAULT_JWKS_CACHE_TTL_MS;
}

function createCachedJwksResolver(
  jwksUrl: string,
  fetchImpl: FetchFn,
  clock: Clock,
): JWTVerifyGetKey {
  let cachedResolver: JWTVerifyGetKey | null = null;
  let expiresAtMs = 0;

  const loadJwks = async (): Promise<JWTVerifyGetKey> => {
    const response = await fetchImpl(jwksUrl, { method: 'GET' });
    if (!response.ok) {
      throw new Error(`JWKS fetch failed with status ${String(response.status)}`);
    }
    const parsed = jwksResponseSchema.safeParse(await response.json());
    if (!parsed.success) {
      throw new Error('Invalid JWKS payload');
    }
    const jwkSet: JSONWebKeySet = { keys: parsed.data.keys };
    cachedResolver = createLocalJWKSet(jwkSet);
    expiresAtMs = clock.nowMs() + parseCacheControlMaxAgeMs(response.headers.get('cache-control'));
    return cachedResolver;
  };

  return async (protectedHeader, token) => {
    const resolver =
      cachedResolver !== null && clock.nowMs() < expiresAtMs ? cachedResolver : await loadJwks();
    try {
      return await resolver(protectedHeader, token);
    } catch {
      const refreshed = await loadJwks();
      return refreshed(protectedHeader, token);
    }
  };
}

// Decision Q12 & 6.4: Verify RS256 Firebase ID tokens via SecureToken JWKS and enforce iss/aud/exp/iat/sub.
export function createFirebaseJwksTokenVerifier(
  deps: FirebaseJwksTokenVerifierDeps,
): TokenVerifierPort {
  const projectId = deps.firebaseProjectId?.trim() ?? '';
  if (projectId.length === 0) {
    return {
      verifyIdToken: () =>
        Promise.resolve(err(authTokenInvalidError('FIREBASE_PROJECT_ID is not configured'))),
    };
  }

  const expectedIssuer = `${FIREBASE_ISSUER_PREFIX}${projectId}`;
  const keyResolver =
    deps.jwksResolver ??
    createCachedJwksResolver(
      deps.jwksUrl ?? FIREBASE_JWKS_URL,
      deps.fetchImpl ?? fetch,
      deps.clock,
    );

  return {
    verifyIdToken: async (idToken) => {
      if (idToken.trim().length === 0) {
        return err(authTokenInvalidError('Missing Firebase ID token'));
      }

      try {
        const nowMs = deps.clock.nowMs();
        const nowSec = Math.floor(nowMs / SECONDS_PER_MILLISECOND);
        const { payload } = await jwtVerify(idToken, keyResolver, {
          algorithms: [FIREBASE_JWT_ALGORITHM],
          issuer: expectedIssuer,
          audience: projectId,
          currentDate: new Date(nowMs),
          clockTolerance: FIREBASE_CLOCK_TOLERANCE_SECONDS,
        });

        const sub = typeof payload.sub === 'string' ? payload.sub.trim() : '';
        if (sub.length === 0 || sub.length > FIREBASE_UID_MAX_LENGTH) {
          return err(authTokenInvalidError('Firebase ID token missing valid sub claim'));
        }
        if (
          typeof payload.exp !== 'number' ||
          typeof payload.iat !== 'number' ||
          payload.iat > nowSec + FIREBASE_CLOCK_TOLERANCE_SECONDS
        ) {
          return err(authTokenInvalidError('Firebase ID token has invalid exp/iat claims'));
        }

        const rawName = payload['name'];
        const displayName = typeof rawName === 'string' ? rawName.trim() : '';
        const claims: VerifiedIdentityClaims = {
          firebaseUid: sub,
          ...(displayName.length > 0 ? { displayName } : {}),
        };
        return ok(claims);
      } catch {
        return err(authTokenInvalidError('Invalid Firebase ID token'));
      }
    },
  };
}
