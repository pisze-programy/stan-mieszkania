import type { Result } from '@stanmieszkania/shared';
import type { IdentityError } from './identity.errors';

export interface VerifiedIdentityClaims {
  readonly firebaseUid: string;
  readonly displayName?: string;
}

export interface TokenVerifierPort {
  verifyIdToken(idToken: string): Promise<Result<VerifiedIdentityClaims, IdentityError>>;
}
