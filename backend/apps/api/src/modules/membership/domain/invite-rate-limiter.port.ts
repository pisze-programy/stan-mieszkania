import type { Result } from '@stanmieszkania/shared';
import type { MembershipError } from './membership.errors';

export interface InviteCodeRateLimiterPort {
  checkAndRecordJoinAttempt(userId: string): Promise<Result<void, MembershipError>>;
}
