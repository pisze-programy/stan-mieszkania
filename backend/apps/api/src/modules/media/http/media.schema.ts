import { z } from '@hono/zod-openapi';
import {
  IsoDateTimeSchema,
  MAX_PAGE_LIMIT,
  MIN_PAGE_LIMIT,
  UuidV7Schema,
} from '@stanmieszkania/http-contracts';
import { ApartmentRoleSchema } from '../../apartments';
import {
  LOCATION_SOURCES,
  MEDIA_KINDS,
  MEDIA_SOURCES,
  MEDIA_TIMEZONE_MAX_LENGTH,
  MEDIA_UPLOAD_STATUSES,
  MIN_POSITIVE_BYTES,
  MIN_POSITIVE_DIMENSION_PX,
} from '../domain/media.constants';

const MIN_SHA256_INPUT_LENGTH = 1;
const MIN_TZ_INPUT_LENGTH = 1;
const MIN_CURSOR_LENGTH = 1;

export const ApartmentMediaParamsSchema = z
  .object({
    apartmentId: UuidV7Schema,
    mediaId: UuidV7Schema,
  })
  .openapi('ApartmentMediaParams');

export const InitMediaUploadRequestSchema = z
  .object({
    kind: z.enum(MEDIA_KINDS),
    source: z.enum(MEDIA_SOURCES),
    sha256: z.string().min(MIN_SHA256_INPUT_LENGTH),
    capturedAt: IsoDateTimeSchema,
    capturedTz: z.string().min(MIN_TZ_INPUT_LENGTH).max(MEDIA_TIMEZONE_MAX_LENGTH),
    capturedAtFromImport: z.boolean().optional(),
    width: z.number().int().min(MIN_POSITIVE_DIMENSION_PX),
    height: z.number().int().min(MIN_POSITIVE_DIMENSION_PX),
    bytes: z.number().int().min(MIN_POSITIVE_BYTES),
    lat: z.number().optional(),
    lng: z.number().optional(),
    accuracyM: z.number().optional(),
    locationSource: z.enum(LOCATION_SOURCES).optional(),
  })
  .openapi('InitMediaUploadRequest');

export const MediaAuthorSummarySchema = z
  .object({
    userId: UuidV7Schema,
    displayName: z.string(),
    shortTag: z.string(),
    color: z.string(),
    role: ApartmentRoleSchema,
  })
  .openapi('MediaAuthorSummary');

// Decision Q10: GPS fields are intentionally omitted from all client-facing Media DTOs.
export const MediaDtoSchema = z
  .object({
    id: UuidV7Schema,
    apartmentId: UuidV7Schema,
    authorId: UuidV7Schema,
    kind: z.enum(MEDIA_KINDS),
    source: z.enum(MEDIA_SOURCES),
    uploadStatus: z.enum(MEDIA_UPLOAD_STATUSES),
    sha256: z.string(),
    capturedAt: IsoDateTimeSchema,
    capturedTz: z.string(),
    capturedAtFromImport: z.boolean(),
    serverReceivedAt: IsoDateTimeSchema.nullable(),
    width: z.number().int(),
    height: z.number().int(),
    bytes: z.number().int(),
    deletedAt: IsoDateTimeSchema.nullable(),
    deletedBy: UuidV7Schema.nullable(),
  })
  .openapi('Media');

export const MediaWithAuthorDtoSchema = MediaDtoSchema.extend({
  author: MediaAuthorSummarySchema,
}).openapi('MediaWithAuthor');

export const PresignedUrlDtoSchema = z
  .object({
    url: z.string(),
    expiresAt: IsoDateTimeSchema,
  })
  .openapi('PresignedUrl');

export const InitMediaUploadResponseSchema = z
  .object({
    media: MediaDtoSchema,
    upload: PresignedUrlDtoSchema.nullable().openapi({}),
  })
  .openapi('InitMediaUploadResponse');

export const MediaTimelineQuerySchema = z
  .object({
    after: z.string().min(MIN_CURSOR_LENGTH).optional(),
    limit: z.coerce.number().int().min(MIN_PAGE_LIMIT).max(MAX_PAGE_LIMIT).optional(),
  })
  .openapi('MediaTimelineQuery');

export const MediaTimelineResponseSchema = z
  .object({
    items: z.array(MediaWithAuthorDtoSchema),
    nextCursor: z.string().nullable(),
    hasMore: z.boolean(),
  })
  .openapi('MediaTimelineResponse');

export type MediaDto = z.infer<typeof MediaDtoSchema>;
export type MediaWithAuthorDto = z.infer<typeof MediaWithAuthorDtoSchema>;
export type InitMediaUploadResponseDto = z.infer<typeof InitMediaUploadResponseSchema>;
export type MediaTimelineResponseDto = z.infer<typeof MediaTimelineResponseSchema>;
export type PresignedUrlDto = z.infer<typeof PresignedUrlDtoSchema>;
