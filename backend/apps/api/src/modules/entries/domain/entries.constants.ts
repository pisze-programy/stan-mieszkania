export const ENTRY_TEXT_MIN_LENGTH = 1;
export const ENTRY_TEXT_MAX_LENGTH = 4000;

export const MARKER_COORD_MIN = 0;
export const MARKER_COORD_MAX = 1;
export const MIN_MARKER_NUMBER = 1;

export const DECIMAL_RADIX = 10;
export const REDACTED_ENTRY_TEXT = '';
export const MARKER_TOKEN_REGEX = /\[(\d+)\]/g;

export const ENTRY_CHANGE_LOG_ENTITY_TYPE = 'entry';
export const MARKER_CHANGE_LOG_ENTITY_TYPE = 'marker';
export const ENTRY_CHANGE_LOG_OPS = {
  CREATED: 'created',
  RETRACTED: 'retracted',
} as const;
