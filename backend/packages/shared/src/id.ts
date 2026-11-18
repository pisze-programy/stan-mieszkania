import {
  BYTE_MASK,
  HEX_CHARS_PER_BYTE,
  HEX_RADIX,
  TIMESTAMP_BYTE_DIVISORS,
  UUID_BYTE_LENGTH,
  UUID_GROUP_BYTE_RANGES,
  UUID_REGEX,
  UUID_V7_REGEX,
  UUID_V7_VERSION_MASK,
  UUID_V7_VERSION_NIBBLE,
  UUID_VARIANT_BYTE_INDEX,
  UUID_VARIANT_MASK,
  UUID_VARIANT_NIBBLE,
  UUID_VERSION_BYTE_INDEX,
} from './id.constants';

export interface IdGenerator {
  nextId(): string;
}

function formatUuidBytes(bytes: Uint8Array): string {
  const groups = UUID_GROUP_BYTE_RANGES.map(([start, end]) => {
    let hex = '';
    for (let index = start; index < end; index += 1) {
      const byte = bytes[index] ?? 0;
      hex += byte.toString(HEX_RADIX).padStart(HEX_CHARS_PER_BYTE, '0');
    }
    return hex;
  });
  return groups.join('-');
}

export function generateUuidV7(timestampMs: number = Date.now(), randomBytes?: Uint8Array): string {
  if (!Number.isFinite(timestampMs) || timestampMs < 0) {
    throw new RangeError(
      `UUIDv7 timestampMs must be a non-negative finite number: ${String(timestampMs)}`,
    );
  }

  const bytes = new Uint8Array(UUID_BYTE_LENGTH);
  if (randomBytes !== undefined) {
    if (randomBytes.length !== UUID_BYTE_LENGTH) {
      throw new RangeError(
        `UUIDv7 randomBytes must have length ${String(UUID_BYTE_LENGTH)}, got ${String(randomBytes.length)}`,
      );
    }
    bytes.set(randomBytes);
  } else {
    globalThis.crypto.getRandomValues(bytes);
  }

  const truncatedTs = Math.trunc(timestampMs);
  for (let index = 0; index < TIMESTAMP_BYTE_DIVISORS.length; index += 1) {
    const divisor = TIMESTAMP_BYTE_DIVISORS[index] ?? 1;
    bytes[index] = Math.floor(truncatedTs / divisor) & BYTE_MASK;
  }

  const versionByte = bytes[UUID_VERSION_BYTE_INDEX] ?? 0;
  bytes[UUID_VERSION_BYTE_INDEX] = (versionByte & UUID_V7_VERSION_MASK) | UUID_V7_VERSION_NIBBLE;

  const variantByte = bytes[UUID_VARIANT_BYTE_INDEX] ?? 0;
  bytes[UUID_VARIANT_BYTE_INDEX] = (variantByte & UUID_VARIANT_MASK) | UUID_VARIANT_NIBBLE;

  return formatUuidBytes(bytes);
}

export function isUuid(value: string): boolean {
  return UUID_REGEX.test(value);
}

export function isUuidV7(value: string): boolean {
  return UUID_V7_REGEX.test(value);
}

export class SystemUuidV7Generator implements IdGenerator {
  nextId(): string {
    return generateUuidV7();
  }
}
