import { isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock } from '@stanmieszkania/testing';
import { exportPKCS8, generateKeyPair, jwtVerify } from 'jose';
import { describe, expect, it } from 'vitest';
import { ACCOUNT_DELETION_ERROR_CODES } from '../domain/account-deletion.errors';
import { createAppleAuthRevoker, type ExternalAuthFetchFn } from './apple-auth-revoker';
import {
  APPLE_AUDIENCE,
  APPLE_REVOKE_ENDPOINT,
  APPLE_TOKEN_ENDPOINT,
} from './external-auth.constants';

const NOW_ISO = '2026-11-19T10:00:00.000Z';

describe('AppleAuthRevoker', () => {
  it('signs ES256 client_secret JWT, exchanges auth code, and revokes refresh token', async () => {
    const keyPair = await generateKeyPair('ES256', { extractable: true });
    const privateKeyPem = await exportPKCS8(keyPair.privateKey);
    const calls: { url: string; params: URLSearchParams }[] = [];

    const fetchMock: ExternalAuthFetchFn = (input, init) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
      const bodyStr = typeof init?.body === 'string' ? init.body : '';
      calls.push({ url, params: new URLSearchParams(bodyStr) });

      if (url === APPLE_TOKEN_ENDPOINT) {
        return Promise.resolve(
          new Response(JSON.stringify({ refresh_token: 'apple-refresh-tok-1' }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          }),
        );
      }
      return Promise.resolve(new Response('', { status: 200 }));
    };

    const clock = new FixedClock(NOW_ISO);
    const revoker = createAppleAuthRevoker({
      teamId: 'TEAM123456',
      clientId: 'pl.stanmieszkania.app',
      keyId: 'KEY9876543',
      privateKeyPem: privateKeyPem.replaceAll('\n', '\\n'),
      clock,
      fetchImpl: fetchMock,
    });

    const result = await revoker.revokeAuthorizationCode('apple-auth-code-xyz');
    expect(isOk(result)).toBe(true);
    expect(calls).toHaveLength(2);
    expect(calls[0]?.url).toBe(APPLE_TOKEN_ENDPOINT);
    expect(calls[0]?.params.get('code')).toBe('apple-auth-code-xyz');
    expect(calls[0]?.params.get('grant_type')).toBe('authorization_code');
    expect(calls[0]?.params.get('client_id')).toBe('pl.stanmieszkania.app');

    const clientSecret = calls[0]?.params.get('client_secret') ?? '';
    const verified = await jwtVerify(clientSecret, keyPair.publicKey, {
      algorithms: ['ES256'],
      issuer: 'TEAM123456',
      audience: APPLE_AUDIENCE,
      subject: 'pl.stanmieszkania.app',
      currentDate: new Date(NOW_ISO),
    });
    expect(verified.protectedHeader.kid).toBe('KEY9876543');

    expect(calls[1]?.url).toBe(APPLE_REVOKE_ENDPOINT);
    expect(calls[1]?.params.get('token')).toBe('apple-refresh-tok-1');
    expect(calls[1]?.params.get('token_type_hint')).toBe('refresh_token');
    expect(calls[1]?.params.get('client_secret')).toBe(clientSecret);
  });

  it('returns EXTERNAL_AUTH_CLEANUP_FAILED on Apple token exchange, revoke, or network error', async () => {
    const keyPair = await generateKeyPair('ES256', { extractable: true });
    const privateKeyPem = await exportPKCS8(keyPair.privateKey);
    const clock = new FixedClock(NOW_ISO);

    const tokenFailRevoker = createAppleAuthRevoker({
      teamId: 'TEAM123456',
      clientId: 'pl.stanmieszkania.app',
      keyId: 'KEY9876543',
      privateKeyPem,
      clock,
      fetchImpl: () => Promise.resolve(new Response('bad_grant', { status: 400 })),
    });
    const r1 = await tokenFailRevoker.revokeAuthorizationCode('expired-code');
    expect(isErr(r1) && r1.error.code).toBe(
      ACCOUNT_DELETION_ERROR_CODES.EXTERNAL_AUTH_CLEANUP_FAILED,
    );

    const revokeFailRevoker = createAppleAuthRevoker({
      teamId: 'TEAM123456',
      clientId: 'pl.stanmieszkania.app',
      keyId: 'KEY9876543',
      privateKeyPem,
      clock,
      fetchImpl: (input) => {
        const url =
          typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
        if (url === APPLE_TOKEN_ENDPOINT) {
          return Promise.resolve(
            new Response(JSON.stringify({ access_token: 'apple-access-tok' }), { status: 200 }),
          );
        }
        return Promise.resolve(new Response('server_error', { status: 503 }));
      },
    });
    const r2 = await revokeFailRevoker.revokeAuthorizationCode('valid-code');
    expect(isErr(r2) && r2.error.code).toBe(
      ACCOUNT_DELETION_ERROR_CODES.EXTERNAL_AUTH_CLEANUP_FAILED,
    );

    const netFailRevoker = createAppleAuthRevoker({
      teamId: 'TEAM123456',
      clientId: 'pl.stanmieszkania.app',
      keyId: 'KEY9876543',
      privateKeyPem,
      clock,
      fetchImpl: () => Promise.reject(new Error('network down')),
    });
    const r3 = await netFailRevoker.revokeAuthorizationCode('valid-code');
    expect(isErr(r3) && r3.error.code).toBe(
      ACCOUNT_DELETION_ERROR_CODES.EXTERNAL_AUTH_CLEANUP_FAILED,
    );
  });
});
