import { err, ok } from '@stanmieszkania/shared';
import { authTokenInvalidError } from '../domain/identity.errors';
import type { TokenVerifierPort, VerifiedIdentityClaims } from '../domain/token-verifier.port';

const LOCAL_DEV_TOKEN_PREFIX = 'dev:';

function parseLocalDevClaims(idToken: string): VerifiedIdentityClaims | null {
  if (!idToken.startsWith(LOCAL_DEV_TOKEN_PREFIX)) {
    return null;
  }

  const remainder = idToken.slice(LOCAL_DEV_TOKEN_PREFIX.length);
  if (remainder.length === 0) {
    return null;
  }

  const colonIndex = remainder.indexOf(':');
  if (colonIndex === -1) {
    const firebaseUid = remainder.trim();
    return firebaseUid.length > 0 ? { firebaseUid } : null;
  }

  const firebaseUid = remainder.slice(0, colonIndex).trim();
  const encodedName = remainder.slice(colonIndex + 1);
  if (firebaseUid.length === 0) {
    return null;
  }

  try {
    const displayName = decodeURIComponent(encodedName).trim();
    if (displayName.length === 0) {
      return { firebaseUid };
    }
    return { firebaseUid, displayName };
  } catch {
    return null;
  }
}

export function createLocalDevTokenVerifier(): TokenVerifierPort {
  return {
    verifyIdToken: (idToken) => {
      const claims = parseLocalDevClaims(idToken);
      if (claims === null) {
        return Promise.resolve(err(authTokenInvalidError('Invalid local development token')));
      }
      return Promise.resolve(ok(claims));
    },
  };
}

export function createFailClosedTokenVerifier(): TokenVerifierPort {
  return {
    verifyIdToken: () =>
      Promise.resolve(
        err(authTokenInvalidError('Firebase ID token verifier is not configured yet')),
      ),
  };
}
