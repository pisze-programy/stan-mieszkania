import { err, ok, type Clock } from '@stanmieszkania/shared';
import { SignJWT, importPKCS8 } from 'jose';
import { z } from 'zod';
import { externalAuthCleanupFailedError } from '../domain/account-deletion.errors';
import type { IdentityProviderDeleterPort } from '../domain/external-auth-cleanup.port';
import type { ExternalAuthFetchFn } from './apple-auth-revoker';
import {
  FIREBASE_IDENTITY_TOOLKIT_BASE,
  FIREBASE_IDENTITY_TOOLKIT_SCOPE,
  FIREBASE_USER_NOT_FOUND_CODE,
  GOOGLE_ASSERTION_TTL_SECONDS,
  GOOGLE_JWT_GRANT_TYPE,
  GOOGLE_OAUTH_TOKEN_ENDPOINT,
  GOOGLE_SERVICE_ACCOUNT_ALG,
  SECONDS_PER_MILLISECOND,
} from './external-auth.constants';

export interface FirebaseIdentityDeleterDeps {
  readonly clientEmail: string;
  readonly privateKeyPem: string;
  readonly projectId?: string;
  readonly clock: Clock;
  readonly fetchImpl?: ExternalAuthFetchFn;
  readonly oauthTokenEndpoint?: string;
  readonly deleteAccountEndpoint?: string;
}

const googleTokenResponseSchema = z.object({
  access_token: z.string().min(1),
});

const identityToolkitErrorSchema = z.object({
  error: z
    .object({
      message: z.string().optional(),
    })
    .optional(),
});

function normalizePem(pem: string): string {
  return pem.replaceAll('\\n', '\n').trim();
}

function resolveDeleteEndpoint(deps: FirebaseIdentityDeleterDeps): string {
  if (deps.deleteAccountEndpoint !== undefined) {
    return deps.deleteAccountEndpoint;
  }
  const projectId = deps.projectId?.trim() ?? '';
  if (projectId.length > 0) {
    return `${FIREBASE_IDENTITY_TOOLKIT_BASE}/projects/${encodeURIComponent(projectId)}/accounts:delete`;
  }
  return `${FIREBASE_IDENTITY_TOOLKIT_BASE}/accounts:delete`;
}

// Decision Q12: Mint RS256 Google OAuth2 access token and call Identity Toolkit accounts:delete idempotently.
export function createFirebaseIdentityDeleter(
  deps: FirebaseIdentityDeleterDeps,
): IdentityProviderDeleterPort {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const oauthTokenEndpoint = deps.oauthTokenEndpoint ?? GOOGLE_OAUTH_TOKEN_ENDPOINT;
  const deleteAccountEndpoint = resolveDeleteEndpoint(deps);

  return {
    deleteProviderUser: async (firebaseUid) => {
      try {
        const nowSec = Math.floor(deps.clock.nowMs() / SECONDS_PER_MILLISECOND);
        const privateKey = await importPKCS8(
          normalizePem(deps.privateKeyPem),
          GOOGLE_SERVICE_ACCOUNT_ALG,
        );
        const assertion = await new SignJWT({ scope: FIREBASE_IDENTITY_TOOLKIT_SCOPE })
          .setProtectedHeader({ alg: GOOGLE_SERVICE_ACCOUNT_ALG, typ: 'JWT' })
          .setIssuer(deps.clientEmail)
          .setSubject(deps.clientEmail)
          .setAudience(oauthTokenEndpoint)
          .setIssuedAt(nowSec)
          .setExpirationTime(nowSec + GOOGLE_ASSERTION_TTL_SECONDS)
          .sign(privateKey);

        const oauthBody = new URLSearchParams({
          grant_type: GOOGLE_JWT_GRANT_TYPE,
          assertion,
        });
        const oauthRes = await fetchImpl(oauthTokenEndpoint, {
          method: 'POST',
          headers: { 'content-type': 'application/x-www-form-urlencoded' },
          body: oauthBody.toString(),
        });
        if (!oauthRes.ok) {
          return err(externalAuthCleanupFailedError('Google OAuth token exchange failed'));
        }

        const parsedOauth = googleTokenResponseSchema.safeParse(await oauthRes.json());
        if (!parsedOauth.success) {
          return err(externalAuthCleanupFailedError('Invalid Google OAuth token response'));
        }

        const deleteRes = await fetchImpl(deleteAccountEndpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${parsedOauth.data.access_token}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({ localId: firebaseUid }),
        });
        if (deleteRes.ok) {
          return ok();
        }

        let errorBody: unknown;
        try {
          errorBody = await deleteRes.json();
        } catch {
          errorBody = undefined;
        }
        const parsedError = identityToolkitErrorSchema.safeParse(errorBody);
        if (
          parsedError.success &&
          parsedError.data.error?.message === FIREBASE_USER_NOT_FOUND_CODE
        ) {
          return ok();
        }

        return err(externalAuthCleanupFailedError('Firebase user deletion failed'));
      } catch {
        return err(externalAuthCleanupFailedError('Firebase user deletion failed'));
      }
    },
  };
}
