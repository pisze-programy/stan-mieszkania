import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { IDENTITY_ERROR_CODES } from '../domain/identity.errors';
import {
  createFailClosedTokenVerifier,
  createLocalDevTokenVerifier,
} from './local-dev-token-verifier';

describe('localDevTokenVerifier', () => {
  it('parses dev:<uid> and dev:<uid>:<encodedDisplayName>', async () => {
    const verifier = createLocalDevTokenVerifier();

    const anon = await verifier.verifyIdToken('dev:user-123');
    expect(isOk(anon)).toBe(true);
    if (isOk(anon)) {
      expect(anon.value).toEqual({ firebaseUid: 'user-123' });
    }

    const named = await verifier.verifyIdToken('dev:user-456:Jan%20Nowak%20%231');
    expect(isOk(named)).toBe(true);
    if (isOk(named)) {
      expect(named.value).toEqual({ firebaseUid: 'user-456', displayName: 'Jan Nowak #1' });
    }
  });

  it('rejects malformed tokens and fail-closed firebase placeholder rejects all tokens', async () => {
    const localVerifier = createLocalDevTokenVerifier();
    for (const badToken of ['', 'bearer-xyz', 'dev:', 'dev::name', 'dev:uid:%E0%A4%A']) {
      const result = await localVerifier.verifyIdToken(badToken);
      expect(isErr(result)).toBe(true);
      if (isErr(result)) {
        expect(result.error.code).toBe(IDENTITY_ERROR_CODES.AUTH_TOKEN_INVALID);
      }
    }

    const failClosed = createFailClosedTokenVerifier();
    const denied = await failClosed.verifyIdToken('dev:user-123');
    expect(isErr(denied)).toBe(true);
    if (isErr(denied)) {
      expect(denied.error.code).toBe(IDENTITY_ERROR_CODES.AUTH_TOKEN_INVALID);
    }
  });
});
