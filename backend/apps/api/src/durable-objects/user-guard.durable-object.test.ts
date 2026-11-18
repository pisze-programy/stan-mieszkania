import { describe, expect, it } from 'vitest';
import {
  CLEANUP_RETRY_BASE_DELAY_MS,
  JOIN_ATTEMPTS_STORAGE_KEY,
  PENDING_CLEANUP_STORAGE_KEY,
  USER_GUARD_HTTP_STATUS,
  USER_GUARD_ORIGIN,
  USER_GUARD_PATHS,
} from './user-guard.constants';
import { UserGuard } from './user-guard.durable-object';
import type {
  PendingAccountCleanupState,
  UserGuardR2BucketLike,
  UserGuardStorageLike,
} from './user-guard.types';

class InMemoryUserGuardStorage implements UserGuardStorageLike {
  readonly data = new Map<string, unknown>();
  readonly alarms: number[] = [];

  get<T = unknown>(key: string): Promise<T | undefined> {
    // reason: Generic test storage mirrors DurableObjectStorage.get<T> lookup semantics.
    return Promise.resolve(this.data.get(key) as T | undefined);
  }

  put(key: string, value: unknown): Promise<void> {
    this.data.set(key, value);
    return Promise.resolve();
  }

  delete(key: string): Promise<boolean> {
    return Promise.resolve(this.data.delete(key));
  }

  setAlarm(scheduledTime: number | Date): Promise<void> {
    const timeMs = scheduledTime instanceof Date ? scheduledTime.getTime() : scheduledTime;
    this.alarms.push(timeMs);
    return Promise.resolve();
  }
}

describe('UserGuard Durable Object', () => {
  it('enforces sliding-window join rate limit and recovers after window expiry', async () => {
    const storage = new InMemoryUserGuardStorage();
    const guard = new UserGuard({ storage }, {});
    const windowMs = 60_000;
    const baseMs = 1_000_000;

    expect(
      await guard.checkAndRecordJoinAttempt({ maxAttempts: 2, windowMs, nowMs: baseMs }),
    ).toEqual({ allowed: true });
    expect(
      await guard.checkAndRecordJoinAttempt({ maxAttempts: 2, windowMs, nowMs: baseMs + 10_000 }),
    ).toEqual({ allowed: true });

    const blocked = await guard.checkAndRecordJoinAttempt({
      maxAttempts: 2,
      windowMs,
      nowMs: baseMs + 15_500,
    });
    expect(blocked).toEqual({ allowed: false, retryAfterSeconds: 45 });

    const recovered = await guard.checkAndRecordJoinAttempt({
      maxAttempts: 2,
      windowMs,
      nowMs: baseMs + windowMs,
    });
    expect(recovered).toEqual({ allowed: true });
    expect(await storage.get<number[]>(JOIN_ATTEMPTS_STORAGE_KEY)).toEqual([
      baseMs + 10_000,
      baseMs + windowMs,
    ]);
  });

  it('persists pending R2 cleanup keys, retries failures with backoff alarm, and clears on success', async () => {
    const storage = new InMemoryUserGuardStorage();
    const deletedKeys: string[] = [];
    let failSecondKey = true;

    const bucket: UserGuardR2BucketLike = {
      delete: (keys) => {
        const list = Array.isArray(keys) ? keys : [keys];
        for (const key of list) {
          if (key === 'apt/k2.jpg' && failSecondKey) {
            return Promise.reject(new Error('R2 temporary outage'));
          }
          deletedKeys.push(key);
        }
        return Promise.resolve();
      },
    };

    const guard = new UserGuard({ storage }, { MEDIA_BUCKET: bucket });
    const startMs = 2_000_000;

    await guard.enqueueCleanup({
      r2Keys: ['apt/k1.jpg', 'apt/k2.jpg', 'apt/k1.jpg'],
      nowMs: startMs,
    });
    expect(storage.alarms).toEqual([startMs]);

    const firstRun = await guard.runCleanup(startMs);
    expect(firstRun).toEqual({ deletedCount: 1, remainingCount: 1 });
    expect(deletedKeys).toEqual(['apt/k1.jpg']);
    expect(await storage.get<PendingAccountCleanupState>(PENDING_CLEANUP_STORAGE_KEY)).toEqual({
      r2Keys: ['apt/k2.jpg'],
      attempts: 1,
    });
    expect(storage.alarms).toEqual([startMs, startMs + CLEANUP_RETRY_BASE_DELAY_MS]);

    failSecondKey = false;
    await guard.alarm();
    expect(deletedKeys).toEqual(['apt/k1.jpg', 'apt/k2.jpg']);
    expect(await storage.get(PENDING_CLEANUP_STORAGE_KEY)).toBeUndefined();
  });

  it('handles HTTP RPC endpoints and rejects invalid requests', async () => {
    const storage = new InMemoryUserGuardStorage();
    const guard = new UserGuard({ storage }, {});

    const rateRes = await guard.fetch(
      new Request(`${USER_GUARD_ORIGIN}${USER_GUARD_PATHS.RATE_LIMIT_JOIN}`, {
        method: 'POST',
        body: JSON.stringify({ maxAttempts: 1, windowMs: 10_000, nowMs: 5_000 }),
      }),
    );
    expect(rateRes.status).toBe(USER_GUARD_HTTP_STATUS.OK);
    expect(await rateRes.json()).toEqual({ allowed: true });

    const badJsonRes = await guard.fetch(
      new Request(`${USER_GUARD_ORIGIN}${USER_GUARD_PATHS.RATE_LIMIT_JOIN}`, {
        method: 'POST',
        body: 'not-json',
      }),
    );
    expect(badJsonRes.status).toBe(USER_GUARD_HTTP_STATUS.BAD_REQUEST);

    const notFoundRes = await guard.fetch(
      new Request(`${USER_GUARD_ORIGIN}/unknown`, { method: 'POST', body: '{}' }),
    );
    expect(notFoundRes.status).toBe(USER_GUARD_HTTP_STATUS.NOT_FOUND);
  });
});
