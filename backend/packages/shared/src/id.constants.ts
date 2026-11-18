export const UUID_BYTE_LENGTH = 16;
export const MAX_UUID_V7_TIMESTAMP_MS = 0xff_ff_ff_ff_ff_ff;
export const HEX_RADIX = 16;
export const HEX_CHARS_PER_BYTE = 2;

export const BYTE_MASK = 0xff;
export const UUID_V7_VERSION_NIBBLE = 0x70;
export const UUID_V7_VERSION_MASK = 0x0f;
export const UUID_VARIANT_NIBBLE = 0x80;
export const UUID_VARIANT_MASK = 0x3f;

export const UUID_VERSION_BYTE_INDEX = 6;
export const UUID_VARIANT_BYTE_INDEX = 8;

// RFC 9562 Section 5.7: 48-bit big-endian Unix millisecond timestamp byte divisors.
export const TIMESTAMP_BYTE_DIVISORS = [
  0x1_00_00_00_00_00, 0x1_00_00_00_00, 0x1_00_00_00, 0x1_00_00, 0x1_00, 1,
] as const;

export const UUID_GROUP_BYTE_RANGES = [
  [0, 4],
  [4, 6],
  [6, 8],
  [8, 10],
  [10, 16],
] as const;

export const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const UUID_V7_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
