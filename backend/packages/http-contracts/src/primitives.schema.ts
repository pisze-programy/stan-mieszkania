import { z } from '@hono/zod-openapi';
import {
  APP_VERSION_MAX_LENGTH,
  APP_VERSION_MIN_LENGTH,
  HEADER_NAMES,
  MAX_PAGE_LIMIT,
  MIN_CURSOR_SEQ,
  MIN_PAGE_LIMIT,
  SEMVER_REGEX,
  UUID_V7_SCHEMA_REGEX,
} from './http-contracts.constants';

export const UuidV7Schema = z
  .string()
  .regex(UUID_V7_SCHEMA_REGEX, 'Must be a valid UUIDv7')
  .openapi('UuidV7', { example: '01933e2a-7b40-7000-8000-000000000001' });

export const IsoDateTimeSchema = z.iso
  .datetime({ offset: true })
  .openapi('IsoDateTime', { example: '2026-11-18T12:00:00.000Z' });

export const CursorSeqSchema = z
  .number()
  .int()
  .min(MIN_CURSOR_SEQ)
  .openapi('CursorSeq', { example: 42 });

export const CursorQuerySchema = z
  .object({
    after: z.coerce.number().int().min(MIN_CURSOR_SEQ).optional(),
    limit: z.coerce.number().int().min(MIN_PAGE_LIMIT).max(MAX_PAGE_LIMIT).optional(),
  })
  .openapi('CursorQuery');

export const AppVersionHeaderSchema = z
  .object({
    [HEADER_NAMES.APP_VERSION]: z
      .string()
      .min(APP_VERSION_MIN_LENGTH)
      .max(APP_VERSION_MAX_LENGTH)
      .regex(SEMVER_REGEX, 'Must be a valid semantic version'),
  })
  .openapi('AppVersionHeader');

export type UuidV7 = z.infer<typeof UuidV7Schema>;
export type IsoDateTime = z.infer<typeof IsoDateTimeSchema>;
export type CursorSeq = z.infer<typeof CursorSeqSchema>;
export type CursorQuery = z.infer<typeof CursorQuerySchema>;
export type AppVersionHeader = z.infer<typeof AppVersionHeaderSchema>;
