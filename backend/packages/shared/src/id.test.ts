import { describe, expect, it } from 'vitest';
import { SystemUuidV7Generator, generateUuidV7, isUuid, isUuidV7 } from './id';

describe('UUIDv7', () => {
  it('encodes exact 48-bit big-endian timestamp, version 7, and RFC 9562 variant bits', () => {
    const timestampMs = 0x017f_22e2_79b0;
    const randomBytes = new Uint8Array(16).fill(0xff);

    const uuid = generateUuidV7(timestampMs, randomBytes);

    expect(uuid).toBe('017f22e2-79b0-7fff-bfff-ffffffffffff');
    expect(isUuidV7(uuid)).toBe(true);
    expect(isUuid(uuid)).toBe(true);
  });

  it('sets variant to 0b10xxxxxx even when random byte starts with 0x00', () => {
    const zeroBytes = new Uint8Array(16).fill(0x00);
    const uuid = generateUuidV7(1_700_000_000_000, zeroBytes);

    const segments = uuid.split('-');
    expect(segments[2]?.[0]).toBe('7');
    expect(segments[3]?.[0]).toBe('8');
    expect(isUuidV7(uuid)).toBe(true);
  });

  it('preserves lexicographic ordering across increasing timestamps', () => {
    const fixedRandom = new Uint8Array(16).fill(0xab);
    const earlier = generateUuidV7(1_700_000_000_000, fixedRandom);
    const later = generateUuidV7(1_700_000_000_001, fixedRandom);
    const muchLater = generateUuidV7(1_800_000_000_000, fixedRandom);

    expect(earlier < later).toBe(true);
    expect(later < muchLater).toBe(true);
  });

  it('generates valid unique UUIDv7 values via SystemUuidV7Generator', () => {
    const generator = new SystemUuidV7Generator();
    const first = generator.nextId();
    const second = generator.nextId();

    expect(isUuidV7(first)).toBe(true);
    expect(isUuidV7(second)).toBe(true);
    expect(first).not.toBe(second);
  });

  it('rejects invalid timestamp or randomBytes length', () => {
    expect(() => generateUuidV7(-1)).toThrow(RangeError);
    expect(() => generateUuidV7(Number.NaN)).toThrow(RangeError);
    expect(() => generateUuidV7(1000, new Uint8Array(8))).toThrow(RangeError);
  });

  it('distinguishes UUIDv7 from UUIDv4 and malformed strings', () => {
    const uuidV4 = '550e8400-e29b-41d4-a716-446655440000';
    const wrongVariant = '017f22e2-79b0-7fff-0fff-ffffffffffff';

    expect(isUuid(uuidV4)).toBe(true);
    expect(isUuidV7(uuidV4)).toBe(false);
    expect(isUuidV7(wrongVariant)).toBe(false);
    expect(isUuid('not-a-uuid')).toBe(false);
  });
});
