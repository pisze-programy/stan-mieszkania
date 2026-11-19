import { isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock } from '@stanmieszkania/testing';
import { SignJWT, exportJWK, generateKeyPair } from 'jose';
import { describe, expect, it } from 'vitest';
import { IDENTITY_ERROR_CODES } from '../domain/identity.errors';
import { createFirebaseJwksTokenVerifier, type FetchFn } from './firebase-jwks-token-verifier';

const PROJECT_ID = 'stan-mieszkania-prod';
const ISSUER = `https://securetoken.google.com/${PROJECT_ID}`;
const NOW_ISO = '2026-11-19T10:00:00.000Z';
const NOW_SEC = Math.floor(Date.parse(NOW_ISO) / 1_000);

describe('FirebaseJwksTokenVerifier', () => {
  it('verifies valid RS256 Firebase ID tokens via cached JWKS and refreshes on key rotation', async () => {
    const key1 = await generateKeyPair('RS256');
    const key2 = await generateKeyPair('RS256');
    const jwk1 = { ...(await exportJWK(key1.publicKey)), kid: 'kid-1', use: 'sig', alg: 'RS256' };
    const jwk2 = { ...(await exportJWK(key2.publicKey)), kid: 'kid-2', use: 'sig', alg: 'RS256' };

    let fetchCount = 0;
    const fetchMock: FetchFn = () => {
      fetchCount += 1;
      const keys = fetchCount === 1 ? [jwk1] : [jwk1, jwk2];
      return Promise.resolve(
        new Response(JSON.stringify({ keys }), {
          status: 200,
          headers: { 'content-type': 'application/json', 'cache-control': 'public, max-age=3600' },
        }),
      );
    };

    const clock = new FixedClock(NOW_ISO);
    const verifier = createFirebaseJwksTokenVerifier({
      firebaseProjectId: PROJECT_ID,
      clock,
      fetchImpl: fetchMock,
    });

    const token1 = await new SignJWT({ name: '  Jan Kowalski  ' })
      .setProtectedHeader({ alg: 'RS256', kid: 'kid-1' })
      .setIssuer(ISSUER)
      .setAudience(PROJECT_ID)
      .setSubject('firebase-uid-123')
      .setIssuedAt(NOW_SEC - 30)
      .setExpirationTime(NOW_SEC + 3600)
      .sign(key1.privateKey);

    const first = await verifier.verifyIdToken(token1);
    expect(isOk(first) && first.value).toEqual({
      firebaseUid: 'firebase-uid-123',
      displayName: 'Jan Kowalski',
    });

    const second = await verifier.verifyIdToken(token1);
    expect(isOk(second)).toBe(true);
    expect(fetchCount).toBe(1);

    const token2 = await new SignJWT({})
      .setProtectedHeader({ alg: 'RS256', kid: 'kid-2' })
      .setIssuer(ISSUER)
      .setAudience(PROJECT_ID)
      .setSubject('firebase-uid-456')
      .setIssuedAt(NOW_SEC - 10)
      .setExpirationTime(NOW_SEC + 3600)
      .sign(key2.privateKey);

    const rotated = await verifier.verifyIdToken(token2);
    expect(isOk(rotated) && rotated.value).toEqual({ firebaseUid: 'firebase-uid-456' });
    expect(fetchCount).toBe(2);
  });

  it('rejects wrong aud, wrong iss, expired, future iat, missing sub, forged signature, and unconfigured project', async () => {
    const trusted = await generateKeyPair('RS256');
    const attacker = await generateKeyPair('RS256');
    const jwk = { ...(await exportJWK(trusted.publicKey)), kid: 'kid-1', use: 'sig', alg: 'RS256' };
    const fetchMock: FetchFn = () =>
      Promise.resolve(
        new Response(JSON.stringify({ keys: [jwk] }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }),
      );
    const clock = new FixedClock(NOW_ISO);
    const verifier = createFirebaseJwksTokenVerifier({
      firebaseProjectId: PROJECT_ID,
      clock,
      fetchImpl: fetchMock,
    });

    const sign = (
      claims: { iss: string; aud: string; sub?: string; iat: number; exp: number },
      key = trusted.privateKey,
    ) => {
      const builder = new SignJWT({})
        .setProtectedHeader({ alg: 'RS256', kid: 'kid-1' })
        .setIssuer(claims.iss)
        .setAudience(claims.aud)
        .setIssuedAt(claims.iat)
        .setExpirationTime(claims.exp);
      if (claims.sub !== undefined) builder.setSubject(claims.sub);
      return builder.sign(key);
    };

    const invalidTokens = await Promise.all([
      sign({ iss: ISSUER, aud: 'wrong-project', sub: 'u1', iat: NOW_SEC - 10, exp: NOW_SEC + 60 }),
      sign({
        iss: 'https://securetoken.google.com/other',
        aud: PROJECT_ID,
        sub: 'u1',
        iat: NOW_SEC - 10,
        exp: NOW_SEC + 60,
      }),
      sign({ iss: ISSUER, aud: PROJECT_ID, sub: 'u1', iat: NOW_SEC - 120, exp: NOW_SEC - 60 }),
      sign({ iss: ISSUER, aud: PROJECT_ID, sub: 'u1', iat: NOW_SEC + 600, exp: NOW_SEC + 3600 }),
      sign({ iss: ISSUER, aud: PROJECT_ID, iat: NOW_SEC - 10, exp: NOW_SEC + 60 }),
      sign(
        { iss: ISSUER, aud: PROJECT_ID, sub: 'u1', iat: NOW_SEC - 10, exp: NOW_SEC + 60 },
        attacker.privateKey,
      ),
    ]);

    for (const badToken of invalidTokens) {
      const result = await verifier.verifyIdToken(badToken);
      expect(isErr(result) && result.error.code).toBe(IDENTITY_ERROR_CODES.AUTH_TOKEN_INVALID);
    }

    const unconfigured = createFirebaseJwksTokenVerifier({ firebaseProjectId: undefined, clock });
    const failClosed = await unconfigured.verifyIdToken('any.jwt.value');
    expect(isErr(failClosed) && failClosed.error.code).toBe(
      IDENTITY_ERROR_CODES.AUTH_TOKEN_INVALID,
    );
  });
});
