import type { DomainError, Result } from '@stanmieszkania/shared';

export interface AppleTokenRevokerPort {
  revokeAuthorizationCode(authorizationCode: string): Promise<Result<void, DomainError>>;
}

export interface IdentityProviderDeleterPort {
  deleteProviderUser(firebaseUid: string): Promise<Result<void, DomainError>>;
}

export interface MediaCleanupPort {
  deletePrivateMediaObjects(
    userId: string,
    r2Keys: readonly string[],
  ): Promise<Result<void, DomainError>>;
}
