import {
  CLEANUP_BACKOFF_BASE,
  CLEANUP_MAX_ATTEMPTS,
  CLEANUP_MAX_RETRY_DELAY_MS,
  CLEANUP_RETRY_BASE_DELAY_MS,
  JOIN_ATTEMPTS_STORAGE_KEY,
  MIN_RETRY_AFTER_SECONDS,
  PENDING_CLEANUP_STORAGE_KEY,
  USER_GUARD_HTTP_STATUS,
  USER_GUARD_MS_PER_SECOND,
  USER_GUARD_PATHS,
} from './user-guard.constants';
import type {
  CleanupRunResult,
  EnqueueCleanupInput,
  JoinRateLimitCheckInput,
  JoinRateLimitDecision,
  PendingAccountCleanupState,
  UserGuardEnv,
  UserGuardStateLike,
} from './user-guard.types';

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function parseRateLimitInput(body: unknown): JoinRateLimitCheckInput | null {
  if (!isRecord(body)) {
    return null;
  }
  const { maxAttempts, windowMs, nowMs } = body;
  if (
    typeof maxAttempts !== 'number' ||
    !Number.isInteger(maxAttempts) ||
    maxAttempts < 1 ||
    typeof windowMs !== 'number' ||
    !Number.isFinite(windowMs) ||
    windowMs < 1 ||
    (nowMs !== undefined && (typeof nowMs !== 'number' || !Number.isFinite(nowMs)))
  ) {
    return null;
  }
  return nowMs === undefined ? { maxAttempts, windowMs } : { maxAttempts, windowMs, nowMs };
}

function parseEnqueueCleanupInput(body: unknown): EnqueueCleanupInput | null {
  if (!isRecord(body) || !Array.isArray(body['r2Keys'])) {
    return null;
  }
  const keys: string[] = [];
  for (const item of body['r2Keys']) {
    if (typeof item !== 'string' || item.length === 0) {
      return null;
    }
    keys.push(item);
  }
  const nowMs = body['nowMs'];
  if (nowMs !== undefined && (typeof nowMs !== 'number' || !Number.isFinite(nowMs))) {
    return null;
  }
  return nowMs === undefined ? { r2Keys: keys } : { r2Keys: keys, nowMs };
}

function jsonResponse(payload: unknown, status: number = USER_GUARD_HTTP_STATUS.OK): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

// Architecture A17: Per-user Durable Object enforces invite join rate limits and durable cleanup alarms.
export class UserGuard {
  private readonly ctx: UserGuardStateLike;
  private readonly env: UserGuardEnv;

  constructor(ctx: UserGuardStateLike, env: UserGuardEnv) {
    this.ctx = ctx;
    this.env = env;
  }

  async checkAndRecordJoinAttempt(input: JoinRateLimitCheckInput): Promise<JoinRateLimitDecision> {
    const nowMs = input.nowMs ?? Date.now();
    const stored = (await this.ctx.storage.get<readonly number[]>(JOIN_ATTEMPTS_STORAGE_KEY)) ?? [];
    const active = stored
      .filter((timestamp) => nowMs - timestamp < input.windowMs)
      .sort((left, right) => left - right);

    if (active.length >= input.maxAttempts) {
      if (active.length !== stored.length) {
        await this.ctx.storage.put(JOIN_ATTEMPTS_STORAGE_KEY, active);
      }
      const oldest = active[0] ?? nowMs;
      const remainingMs = Math.max(1, input.windowMs - (nowMs - oldest));
      const retryAfterSeconds = Math.max(
        MIN_RETRY_AFTER_SECONDS,
        Math.ceil(remainingMs / USER_GUARD_MS_PER_SECOND),
      );
      return { allowed: false, retryAfterSeconds };
    }

    await this.ctx.storage.put(JOIN_ATTEMPTS_STORAGE_KEY, [...active, nowMs]);
    return { allowed: true };
  }

  async enqueueCleanup(input: EnqueueCleanupInput): Promise<void> {
    const nowMs = input.nowMs ?? Date.now();
    const existing = await this.ctx.storage.get<PendingAccountCleanupState>(
      PENDING_CLEANUP_STORAGE_KEY,
    );
    const mergedKeys = [...new Set([...(existing?.r2Keys ?? []), ...input.r2Keys])];
    if (mergedKeys.length === 0) {
      return;
    }

    await this.ctx.storage.put(PENDING_CLEANUP_STORAGE_KEY, {
      r2Keys: mergedKeys,
      attempts: existing?.attempts ?? 0,
    });
    await this.ctx.storage.setAlarm(nowMs);
  }

  async runCleanup(nowMs: number = Date.now()): Promise<CleanupRunResult> {
    const pending = await this.ctx.storage.get<PendingAccountCleanupState>(
      PENDING_CLEANUP_STORAGE_KEY,
    );
    if (pending === undefined || pending.r2Keys.length === 0) {
      await this.ctx.storage.delete(PENDING_CLEANUP_STORAGE_KEY);
      return { deletedCount: 0, remainingCount: 0 };
    }

    const failedKeys: string[] = [];
    let deletedCount = 0;

    for (const key of pending.r2Keys) {
      try {
        await this.env.MEDIA_BUCKET?.delete(key);
        deletedCount += 1;
      } catch {
        failedKeys.push(key);
      }
    }

    if (failedKeys.length === 0) {
      await this.ctx.storage.delete(PENDING_CLEANUP_STORAGE_KEY);
      return { deletedCount, remainingCount: 0 };
    }

    const nextAttempts = pending.attempts + 1;
    await this.ctx.storage.put(PENDING_CLEANUP_STORAGE_KEY, {
      r2Keys: failedKeys,
      attempts: nextAttempts,
    });
    if (nextAttempts < CLEANUP_MAX_ATTEMPTS) {
      const backoffMs = Math.min(
        CLEANUP_MAX_RETRY_DELAY_MS,
        CLEANUP_RETRY_BASE_DELAY_MS * CLEANUP_BACKOFF_BASE ** (nextAttempts - 1),
      );
      await this.ctx.storage.setAlarm(nowMs + backoffMs);
    }

    return { deletedCount, remainingCount: failedKeys.length };
  }

  async alarm(): Promise<void> {
    await this.runCleanup(Date.now());
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Not found' }, USER_GUARD_HTTP_STATUS.NOT_FOUND);
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonResponse({ error: 'Invalid JSON' }, USER_GUARD_HTTP_STATUS.BAD_REQUEST);
    }

    if (url.pathname === USER_GUARD_PATHS.RATE_LIMIT_JOIN) {
      const parsed = parseRateLimitInput(body);
      if (parsed === null) {
        return jsonResponse({ error: 'Invalid payload' }, USER_GUARD_HTTP_STATUS.BAD_REQUEST);
      }
      return jsonResponse(await this.checkAndRecordJoinAttempt(parsed));
    }

    if (url.pathname === USER_GUARD_PATHS.ENQUEUE_CLEANUP) {
      const parsed = parseEnqueueCleanupInput(body);
      if (parsed === null) {
        return jsonResponse({ error: 'Invalid payload' }, USER_GUARD_HTTP_STATUS.BAD_REQUEST);
      }
      await this.enqueueCleanup(parsed);
      return jsonResponse({ queued: parsed.r2Keys.length });
    }

    if (url.pathname === USER_GUARD_PATHS.RUN_CLEANUP) {
      const nowMs = isRecord(body) && typeof body['nowMs'] === 'number' ? body['nowMs'] : undefined;
      return jsonResponse(await this.runCleanup(nowMs));
    }

    return jsonResponse({ error: 'Not found' }, USER_GUARD_HTTP_STATUS.NOT_FOUND);
  }
}
