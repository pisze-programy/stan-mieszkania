import { ok } from '@stanmieszkania/shared';
import type { InviteCodeRateLimiterPort } from '../domain/invite-rate-limiter.port';

export function createAllowAllInviteRateLimiter(): InviteCodeRateLimiterPort {
  return {
    checkAndRecordJoinAttempt: () => Promise.resolve(ok(undefined)),
  };
}
