import { isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock } from '@stanmieszkania/testing';
import { exportPKCS8, generateKeyPair, jwtVerify } from 'jose';
import { describe, expect, it } from 'vitest';
import { ACCOUNT_DELETION_ERROR_CODES } from '../domain/account-deletion.errors';
import type { ExternalAuthFetchFn } from './apple-auth-revoker';
import {
  FIREBASE_IDENTITY_TOOLKIT_SCOPE,
  GOOGLE_JWT_GRANT_TYPE,
  GOOGLE_OAUTH_TOKEN_ENDPOINT,
} from './external-auth.constants';
import { createFirebaseIdentityDeleter } from './firebase-identity-deleter';

const NOW_ISO = '2026-11-19T10:00:00.000Z';
const CLIENT_EMAIL = 'firebase-admin@stan-mieszkania.iam.gserviceaccount.com';

describe('FirebaseIdentityDeleter', () => {
  it('mints RS256 Google OAuth token and deletes Firebase user via Identity Toolkit', async () => {
    const keyPair = await generateKeyPair('RS256', { extractable: true });
    const privateKeyPem = await exportPKCS8(keyPair.privateKey);
    const calls: { url: string; auth: string | null; body: string }[] = [];

    const fetchMock: ExternalAuthFetchFn = (input, init) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
      const headers = new Headers(init?.headers);
      const body = typeof init?.body === 'string' ? init.body : '';
      calls.push({ url, auth: headers.get('Authorization'), body });

      if (url === GOOGLE_OAUTH_TOKEN_ENDPOINT) {
        return Promise.resolve(
          new Response(JSON.stringify({ access_token: 'google-access-tok-99' }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          }),
        );
      }
      return Promise.resolve(
        new Response(JSON.stringify({ kind: 'identitytoolkit#DeleteAccountResponse' }), {
          status: 200,
        }),
      );
    };

    const deleter = createFirebaseIdentityDeleter({
      clientEmail: CLIENT_EMAIL,
      privateKeyPem: privateKeyPem.replaceAll('\n', '\\n'),
      projectId: 'stan-mieszkania-prod',
      clock: new FixedClock(NOW_ISO),
      fetchImpl: fetchMock,
    });

    const result = await deleter.deleteProviderUser('fb-uid-777');
    expect(isOk(result)).toBe(true);
    expect(calls).toHaveLength(2);
    expect(calls[0]?.url).toBe(GOOGLE_OAUTH_TOKEN_ENDPOINT);

    const oauthParams = new URLSearchParams(calls[0]?.body ?? '');
    expect(oauthParams.get('grant_type')).toBe(GOOGLE_JWT_GRANT_TYPE);
    const assertion = oauthParams.get('assertion') ?? '';
    const verified = await jwtVerify(assertion, keyPair.publicKey, {
      algorithms: ['RS256'],
      issuer: CLIENT_EMAIL,
      subject: CLIENT_EMAIL,
      audience: GOOGLE_OAUTH_TOKEN_ENDPOINT,
      currentDate: new Date(NOW_ISO),
    });
    expect(verified.payload['scope']).toBe(FIREBASE_IDENTITY_TOOLKIT_SCOPE);

    expect(calls[1]?.url).toBe(
      'https://identitytoolkit.googleapis.com/v1/projects/stan-mieszkania-prod/accounts:delete',
    );
    expect(calls[1]?.auth).toBe('Bearer google-access-tok-99');
    expect(JSON.parse(calls[1]?.body ?? '{}')).toEqual({ localId: 'fb-uid-777' });
  });

  it('treats Identity Toolkit USER_NOT_FOUND as idempotent success and fails on upstream errors', async () => {
    const keyPair = await generateKeyPair('RS256', { extractable: true });
    const privateKeyPem = await exportPKCS8(keyPair.privateKey);
    const clock = new FixedClock(NOW_ISO);

    const notFoundDeleter = createFirebaseIdentityDeleter({
      clientEmail: CLIENT_EMAIL,
      privateKeyPem,
      clock,
      fetchImpl: (input) => {
        const url =
          typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
        if (url === GOOGLE_OAUTH_TOKEN_ENDPOINT) {
          return Promise.resolve(
            new Response(JSON.stringify({ access_token: 'tok-1' }), { status: 200 }),
          );
        }
        return Promise.resolve(
          new Response(JSON.stringify({ error: { code: 400, message: 'USER_NOT_FOUND' } }), {
            status: 400,
          }),
        );
      },
    });
    expect(isOk(await notFoundDeleter.deleteProviderUser('already-deleted-uid'))).toBe(true);

    const errorDeleter = createFirebaseIdentityDeleter({
      clientEmail: CLIENT_EMAIL,
      privateKeyPem,
      clock,
      fetchImpl: (input) => {
        const url =
          typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
        if (url === GOOGLE_OAUTH_TOKEN_ENDPOINT) {
          return Promise.resolve(
            new Response(JSON.stringify({ access_token: 'tok-1' }), { status: 200 }),
          );
        }
        return Promise.resolve(
          new Response(JSON.stringify({ error: { code: 500, message: 'INTERNAL' } }), {
            status: 500,
          }),
        );
      },
    });
    const failed = await errorDeleter.deleteProviderUser('fb-uid-500');
    expect(isErr(failed) && failed.error.code).toBe(
      ACCOUNT_DELETION_ERROR_CODES.EXTERNAL_AUTH_CLEANUP_FAILED,
    );

    const oauthFailDeleter = createFirebaseIdentityDeleter({
      clientEmail: CLIENT_EMAIL,
      privateKeyPem,
      clock,
      fetchImpl: () => Promise.reject(new Error('dns timeout')),
    });
    const netFailed = await oauthFailDeleter.deleteProviderUser('fb-uid-net');
    expect(isErr(netFailed) && netFailed.error.code).toBe(
      ACCOUNT_DELETION_ERROR_CODES.EXTERNAL_AUTH_CLEANUP_FAILED,
    );
  });
});
