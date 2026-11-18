export const DISPLAY_NAME_MIN_LENGTH = 1;
export const DISPLAY_NAME_MAX_LENGTH = 80;

export const SHORT_TAG_LENGTH = 4;
export const SHORT_TAG_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

export const DEFAULT_USER_NAME_PREFIX = 'Użytkownik #';
export const DELETED_USER_DISPLAY_NAME = 'Usunięty użytkownik';

export const AUTHOR_COLOR_PALETTE = [
  '#007AFF',
  '#34C759',
  '#FF9500',
  '#AF52DE',
  '#FF2D55',
  '#5856D6',
  '#00C7BE',
  '#FF3B30',
] as const;

export const FNV1A_OFFSET_BASIS = 0x811c9dc5;
export const FNV1A_PRIME = 0x01000193;
export const HASH_MIX_SHIFT = 5;
