import { err, ok, type Result } from '@stanmieszkania/shared';
import type { InviteCodeRateLimiterPort } from '../domain/invite-rate-limiter.port';
import { inviteCodeRateLimitedError, type MembershipError } from '../domain/membership.errors';

const DEFAULT_RETRY_AFTER_SECONDS = 60;

export interface InMemoryInviteRateLimiterOptions {
  readonly maxAttempts: number;
  readonly retryAfterSeconds?: number;
}

export class InMemoryInviteRateLimiter implements InviteCodeRateLimiterPort {
  private readonly attempts = new Map<string, number>();
  private readonly retryAfterSeconds: number;

  public constructor(private readonly options: InMemoryInviteRateLimiterOptions) {
    this.retryAfterSeconds = options.retryAfterSeconds ?? DEFAULT_RETRY_AFTER_SECONDS;
  }

  public checkAndRecordJoinAttempt(userId: string): Promise<Result<void, MembershipError>> {
    const current = this.attempts.get(userId) ?? 0;
    if (current >= this.options.maxAttempts) {
      return Promise.resolve(err(inviteCodeRateLimitedError(this.retryAfterSeconds)));
    }
    this.attempts.set(userId, current + 1);
    return Promise.resolve(ok(undefined));
  }
}
