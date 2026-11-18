import type { DurableObjectId } from '@cloudflare/workers-types';

export interface UserGuardStorageLike {
  get<T = unknown>(key: string): Promise<T | undefined>;
  put(key: string, value: unknown): Promise<void>;
  delete(key: string): Promise<boolean>;
  setAlarm(scheduledTime: number | Date): Promise<void>;
}

export interface UserGuardStateLike {
  readonly storage: UserGuardStorageLike;
}

export interface UserGuardR2BucketLike {
  delete(keys: string | string[]): Promise<void>;
}

export interface UserGuardEnv {
  readonly MEDIA_BUCKET?: UserGuardR2BucketLike;
}

export interface UserGuardResponseLike {
  readonly ok: boolean;
  readonly status: number;
  json(): Promise<unknown>;
}

export interface UserGuardStubLike {
  fetch(
    input: string,
    init?: {
      readonly method?: string;
      readonly headers?: Record<string, string>;
      readonly body?: string;
    },
  ): Promise<UserGuardResponseLike>;
}

export interface UserGuardNamespaceLike {
  idFromName(name: string): DurableObjectId;
  get(id: DurableObjectId): UserGuardStubLike;
}

export interface JoinRateLimitCheckInput {
  readonly maxAttempts: number;
  readonly windowMs: number;
  readonly nowMs?: number;
}

export type JoinRateLimitDecision =
  { readonly allowed: true } | { readonly allowed: false; readonly retryAfterSeconds: number };

export interface EnqueueCleanupInput {
  readonly r2Keys: readonly string[];
  readonly nowMs?: number;
}

export interface PendingAccountCleanupState {
  readonly r2Keys: readonly string[];
  readonly attempts: number;
}

export interface CleanupRunResult {
  readonly deletedCount: number;
  readonly remainingCount: number;
}
