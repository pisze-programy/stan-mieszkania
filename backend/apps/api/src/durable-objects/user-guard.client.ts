import { err, ok, type Clock } from '@stanmieszkania/shared';
import { z } from 'zod';
import { accountDeletionFailedError, type MediaCleanupPort } from '../modules/account-deletion';
import { inviteCodeRateLimitedError, type InviteCodeRateLimiterPort } from '../modules/membership';
import { USER_GUARD_ORIGIN, USER_GUARD_PATHS } from './user-guard.constants';
import type { UserGuardNamespaceLike } from './user-guard.types';

const JoinRateLimitDecisionSchema = z.discriminatedUnion('allowed', [
  z.object({ allowed: z.literal(true) }),
  z.object({ allowed: z.literal(false), retryAfterSeconds: z.number().int().min(1) }),
]);

export interface UserGuardRateLimiterOptions {
  readonly namespace: UserGuardNamespaceLike;
  readonly maxAttempts: number;
  readonly windowMs: number;
  readonly clock: Clock;
}

export interface UserGuardMediaCleanupOptions {
  readonly namespace: UserGuardNamespaceLike;
  readonly clock: Clock;
}

function getUserGuardStub(namespace: UserGuardNamespaceLike, userId: string) {
  return namespace.get(namespace.idFromName(userId));
}

export function createUserGuardInviteRateLimiter(
  options: UserGuardRateLimiterOptions,
): InviteCodeRateLimiterPort {
  return {
    checkAndRecordJoinAttempt: async (userId) => {
      const stub = getUserGuardStub(options.namespace, userId);
      const response = await stub.fetch(`${USER_GUARD_ORIGIN}${USER_GUARD_PATHS.RATE_LIMIT_JOIN}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          maxAttempts: options.maxAttempts,
          windowMs: options.windowMs,
          nowMs: options.clock.nowMs(),
        }),
      });

      if (!response.ok) {
        throw new Error(`UserGuard rate-limit RPC failed with status ${String(response.status)}`);
      }

      const parsed = JoinRateLimitDecisionSchema.parse(await response.json());
      if (!parsed.allowed) {
        return err(inviteCodeRateLimitedError(parsed.retryAfterSeconds));
      }

      return ok();
    },
  };
}

export function createUserGuardMediaCleanup(
  options: UserGuardMediaCleanupOptions,
): MediaCleanupPort {
  return {
    deletePrivateMediaObjects: async (userId, r2Keys) => {
      if (r2Keys.length === 0) {
        return ok();
      }
      try {
        const stub = getUserGuardStub(options.namespace, userId);
        const nowMs = options.clock.nowMs();

        const enqueueResponse = await stub.fetch(
          `${USER_GUARD_ORIGIN}${USER_GUARD_PATHS.ENQUEUE_CLEANUP}`,
          {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ r2Keys, nowMs }),
          },
        );
        if (!enqueueResponse.ok) {
          return err(
            accountDeletionFailedError(
              `UserGuard cleanup enqueue failed with status ${String(enqueueResponse.status)}`,
            ),
          );
        }

        // Liveness invariant: keys are durably queued with a DO alarm; ignore transient immediate-run errors.
        try {
          await stub.fetch(`${USER_GUARD_ORIGIN}${USER_GUARD_PATHS.RUN_CLEANUP}`, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ nowMs }),
          });
        } catch {
          return ok();
        }

        return ok();
      } catch (cause: unknown) {
        const message = cause instanceof Error ? cause.message : 'Unknown UserGuard error';
        return err(accountDeletionFailedError(`Private media cleanup failed: ${message}`));
      }
    },
  };
}
