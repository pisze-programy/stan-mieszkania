export const APARTMENT_NAME_MIN_LENGTH = 1;
export const APARTMENT_NAME_MAX_LENGTH = 100;

export const APARTMENT_STREET_MIN_LENGTH = 1;
export const APARTMENT_STREET_MAX_LENGTH = 120;

export const APARTMENT_CITY_MIN_LENGTH = 1;
export const APARTMENT_CITY_MAX_LENGTH = 80;

export const INVITE_CODE_RAW_LENGTH = 8;
export const INVITE_CODE_GROUP_LENGTH = 4;
export const INVITE_CODE_SEPARATOR = '-';
// Decision Q9/S6.2: Excludes ambiguous 0/O/1/I characters for reliable SMS/verbal sharing.
export const INVITE_CODE_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
export const MAX_INVITE_CODE_GENERATION_ATTEMPTS = 5;

// Decision Q5: Private retention window before purging orphaned apartments with shared history.
export const ORPHAN_APARTMENT_RETENTION_DAYS = 30;
export const INITIAL_CLOUD_MEDIA_COUNT = 0;

export const APARTMENT_ROLES = {
  OWNER: 'owner',
  CONTRIBUTOR: 'contributor',
} as const;

export const APARTMENT_CHANGE_FIELDS = {
  NAME: 'name',
  STREET: 'street',
  CITY: 'city',
} as const;

export const CHANGE_LOG_ENTITY_TYPES = {
  APARTMENT: 'apartment',
} as const;

export const CHANGE_LOG_OPS = {
  CREATED: 'created',
  UPDATED: 'updated',
  INVITE_CODE_ROTATED: 'invite_code_rotated',
  OWNERSHIP_TRANSFERRED: 'ownership_transferred',
} as const;
