import { DEFAULT_PAGE_SIZE } from '@stanmieszkania/shared';

export const SYNC_DEFAULT_PAGE_SIZE = DEFAULT_PAGE_SIZE;
export const SYNC_INITIAL_AFTER_SEQ = 0;

export const SYNC_ENTITY_TYPES = {
  APARTMENT: 'apartment',
  MEMBERSHIP: 'membership',
  MEDIA: 'media',
  ENTRY: 'entry',
} as const;

export const SYNC_ROLES = {
  OWNER: 'owner',
  CONTRIBUTOR: 'contributor',
} as const;
