import { err, ok } from '@stanmieszkania/shared';
import {
  accountDeletionFailedError,
  externalAuthCleanupFailedError,
} from '../domain/account-deletion.errors';
import type {
  AppleTokenRevokerPort,
  IdentityProviderDeleterPort,
  MediaCleanupPort,
} from '../domain/external-auth-cleanup.port';

export interface R2ObjectDeleterLike {
  delete(keys: string | string[]): Promise<void>;
}

export function createLocalAppleTokenRevoker(): AppleTokenRevokerPort {
  return {
    revokeAuthorizationCode: () => Promise.resolve(ok()),
  };
}

export function createFailClosedAppleTokenRevoker(): AppleTokenRevokerPort {
  return {
    revokeAuthorizationCode: () =>
      Promise.resolve(
        err(
          externalAuthCleanupFailedError(
            'Live Apple token revocation adapter is not configured in this build',
          ),
        ),
      ),
  };
}

export function createLocalIdentityProviderDeleter(): IdentityProviderDeleterPort {
  return {
    deleteProviderUser: () => Promise.resolve(ok()),
  };
}

export function createFailClosedIdentityProviderDeleter(): IdentityProviderDeleterPort {
  return {
    deleteProviderUser: () =>
      Promise.resolve(
        err(
          externalAuthCleanupFailedError(
            'Live Firebase Admin user deletion adapter is not configured in this build',
          ),
        ),
      ),
  };
}

export function createDirectR2MediaCleanup(bucket?: R2ObjectDeleterLike): MediaCleanupPort {
  return {
    deletePrivateMediaObjects: async (_userId, r2Keys) => {
      if (bucket === undefined || r2Keys.length === 0) {
        return ok();
      }
      try {
        for (const key of r2Keys) {
          await bucket.delete(key);
        }
        return ok();
      } catch (cause: unknown) {
        const message = cause instanceof Error ? cause.message : 'Unknown R2 delete error';
        return err(accountDeletionFailedError(`Private media cleanup failed: ${message}`));
      }
    },
  };
}
