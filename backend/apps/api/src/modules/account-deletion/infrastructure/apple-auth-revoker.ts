import { err, ok, type Clock } from '@stanmieszkania/shared';
import { SignJWT, importPKCS8 } from 'jose';
import { z } from 'zod';
import { externalAuthCleanupFailedError } from '../domain/account-deletion.errors';
import type { AppleTokenRevokerPort } from '../domain/external-auth-cleanup.port';
import {
  APPLE_AUDIENCE,
  APPLE_CLIENT_SECRET_ALG,
  APPLE_CLIENT_SECRET_TTL_SECONDS,
  APPLE_GRANT_TYPE_AUTH_CODE,
  APPLE_REVOKE_ENDPOINT,
  APPLE_TOKEN_ENDPOINT,
  APPLE_TOKEN_HINT_ACCESS,
  APPLE_TOKEN_HINT_REFRESH,
  SECONDS_PER_MILLISECOND,
} from './external-auth.constants';

export type ExternalAuthFetchFn = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export interface AppleAuthRevokerDeps {
  readonly teamId: string;
  readonly clientId: string;
  readonly keyId: string;
  readonly privateKeyPem: string;
  readonly clock: Clock;
  readonly fetchImpl?: ExternalAuthFetchFn;
  readonly tokenEndpoint?: string;
  readonly revokeEndpoint?: string;
}

const appleTokenResponseSchema = z.object({
  refresh_token: z.string().min(1).optional(),
  access_token: z.string().min(1).optional(),
});

function normalizePem(pem: string): string {
  return pem.replaceAll('\\n', '\n').trim();
}

// Decision Q12 & Apple 5.1.1(v): Sign ES256 client_secret, exchange auth code, and revoke Apple token.
export function createAppleAuthRevoker(deps: AppleAuthRevokerDeps): AppleTokenRevokerPort {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const tokenEndpoint = deps.tokenEndpoint ?? APPLE_TOKEN_ENDPOINT;
  const revokeEndpoint = deps.revokeEndpoint ?? APPLE_REVOKE_ENDPOINT;

  return {
    revokeAuthorizationCode: async (authorizationCode) => {
      try {
        const nowSec = Math.floor(deps.clock.nowMs() / SECONDS_PER_MILLISECOND);
        const privateKey = await importPKCS8(
          normalizePem(deps.privateKeyPem),
          APPLE_CLIENT_SECRET_ALG,
        );
        const clientSecret = await new SignJWT({})
          .setProtectedHeader({ alg: APPLE_CLIENT_SECRET_ALG, kid: deps.keyId })
          .setIssuer(deps.teamId)
          .setIssuedAt(nowSec)
          .setExpirationTime(nowSec + APPLE_CLIENT_SECRET_TTL_SECONDS)
          .setAudience(APPLE_AUDIENCE)
          .setSubject(deps.clientId)
          .sign(privateKey);

        const tokenBody = new URLSearchParams({
          client_id: deps.clientId,
          client_secret: clientSecret,
          code: authorizationCode,
          grant_type: APPLE_GRANT_TYPE_AUTH_CODE,
        });
        const tokenRes = await fetchImpl(tokenEndpoint, {
          method: 'POST',
          headers: { 'content-type': 'application/x-www-form-urlencoded' },
          body: tokenBody.toString(),
        });
        if (!tokenRes.ok) {
          return err(externalAuthCleanupFailedError('Apple token exchange failed'));
        }

        const parsedToken = appleTokenResponseSchema.safeParse(await tokenRes.json());
        if (!parsedToken.success) {
          return err(externalAuthCleanupFailedError('Invalid Apple token response'));
        }
        const tokenToRevoke = parsedToken.data.refresh_token ?? parsedToken.data.access_token;
        const tokenTypeHint =
          parsedToken.data.refresh_token !== undefined
            ? APPLE_TOKEN_HINT_REFRESH
            : APPLE_TOKEN_HINT_ACCESS;
        if (tokenToRevoke === undefined) {
          return err(
            externalAuthCleanupFailedError('Apple token response missing revocable token'),
          );
        }

        const revokeBody = new URLSearchParams({
          client_id: deps.clientId,
          client_secret: clientSecret,
          token: tokenToRevoke,
          token_type_hint: tokenTypeHint,
        });
        const revokeRes = await fetchImpl(revokeEndpoint, {
          method: 'POST',
          headers: { 'content-type': 'application/x-www-form-urlencoded' },
          body: revokeBody.toString(),
        });
        if (!revokeRes.ok) {
          return err(externalAuthCleanupFailedError('Apple token revocation failed'));
        }

        return ok();
      } catch {
        return err(externalAuthCleanupFailedError('Apple token revocation failed'));
      }
    },
  };
}
