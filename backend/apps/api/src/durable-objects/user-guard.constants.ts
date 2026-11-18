export const JOIN_ATTEMPTS_STORAGE_KEY = 'invite_join_attempts';
export const PENDING_CLEANUP_STORAGE_KEY = 'pending_account_cleanup';

export const USER_GUARD_ORIGIN = 'https://user-guard.internal';

export const USER_GUARD_PATHS = {
  RATE_LIMIT_JOIN: '/rate-limit/join',
  ENQUEUE_CLEANUP: '/cleanup/enqueue',
  RUN_CLEANUP: '/cleanup/run',
} as const;

export const USER_GUARD_HTTP_STATUS = {
  OK: 200,
  BAD_REQUEST: 400,
  NOT_FOUND: 404,
} as const;

export const USER_GUARD_MS_PER_SECOND = 1_000;
export const MIN_RETRY_AFTER_SECONDS = 1;
export const CLEANUP_RETRY_BASE_DELAY_MS = 10_000;
export const CLEANUP_MAX_RETRY_DELAY_MS = 300_000;
export const CLEANUP_MAX_ATTEMPTS = 10;
export const CLEANUP_BACKOFF_BASE = 2;
