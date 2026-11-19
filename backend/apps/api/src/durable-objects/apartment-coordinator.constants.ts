export const COORDINATOR_STATE_STORAGE_KEY = 'apartment_coordinator_state';

export const APARTMENT_COORDINATOR_ORIGIN = 'https://apartment-coordinator.internal';

export const APARTMENT_COORDINATOR_PATHS = {
  LOCK_ACQUIRE: '/lock/acquire',
  LOCK_RELEASE: '/lock/release',
  SCHEDULE_ORPHAN_PURGE: '/schedule/orphan-purge',
  SCHEDULE_PENDING_CLEANUP: '/schedule/pending-cleanup',
  RUN_ALARM: '/alarm/run',
} as const;

export const APARTMENT_COORDINATOR_HTTP_STATUS = {
  OK: 200,
  BAD_REQUEST: 400,
  NOT_FOUND: 404,
} as const;

export const DEFAULT_LEASE_TTL_MS = 30_000;
export const MIN_LEASE_WAIT_MS = 1;
export const DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS = 86_400_000;
export const ORPHAN_PURGE_RETRY_DELAY_MS = 60_000;
export const MEDIA_ABANDONED_CLEANED_OP = 'abandoned_cleaned';
export const MEDIA_PENDING_OP = 'pending';
export const MEDIA_ENTITY_TYPE = 'media';
export const UPLOAD_STATUS_PENDING = 'pending';
export const ABANDONED_CLEANUP_DELETE_MEDIA_INDEX = 4;
