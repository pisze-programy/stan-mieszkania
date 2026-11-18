import { generateUuidV7 } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { HEADER_NAMES } from './http-contracts.constants';
import {
  AppVersionHeaderSchema,
  CursorQuerySchema,
  CursorSeqSchema,
  IsoDateTimeSchema,
  UuidV7Schema,
} from './primitives.schema';

describe('HTTP primitive Zod schemas', () => {
  it('validates UUIDv7 and rejects UUIDv4 or malformed IDs', () => {
    expect(UuidV7Schema.safeParse(generateUuidV7()).success).toBe(true);
    expect(UuidV7Schema.safeParse('550e8400-e29b-41d4-a716-446655440000').success).toBe(false);
    expect(UuidV7Schema.safeParse('not-a-uuid').success).toBe(false);
  });

  it('validates ISO-8601 date-time strings with timezone offset or Z', () => {
    expect(IsoDateTimeSchema.safeParse('2026-11-18T12:00:00.000Z').success).toBe(true);
    expect(IsoDateTimeSchema.safeParse('2026-11-18T12:00:00+01:00').success).toBe(true);
    expect(IsoDateTimeSchema.safeParse('2026-11-18').success).toBe(false);
    expect(IsoDateTimeSchema.safeParse('2026-11-18T12:00:00').success).toBe(false);
  });

  it('validates CursorSeq and coerces CursorQuery parameters', () => {
    expect(CursorSeqSchema.parse(0)).toBe(0);
    expect(CursorSeqSchema.safeParse(-1).success).toBe(false);

    expect(CursorQuerySchema.parse({ after: '15', limit: '50' })).toEqual({
      after: 15,
      limit: 50,
    });
    expect(CursorQuerySchema.parse({})).toEqual({});
    expect(CursorQuerySchema.safeParse({ limit: '0' }).success).toBe(false);
    expect(CursorQuerySchema.safeParse({ limit: '201' }).success).toBe(false);
  });

  it('validates AppVersionHeader semver format', () => {
    expect(AppVersionHeaderSchema.safeParse({ [HEADER_NAMES.APP_VERSION]: '1.2.3' }).success).toBe(
      true,
    );
    expect(
      AppVersionHeaderSchema.safeParse({ [HEADER_NAMES.APP_VERSION]: '1.2.3-beta.1' }).success,
    ).toBe(true);
    expect(AppVersionHeaderSchema.safeParse({ [HEADER_NAMES.APP_VERSION]: 'v1.2' }).success).toBe(
      false,
    );
  });
});
