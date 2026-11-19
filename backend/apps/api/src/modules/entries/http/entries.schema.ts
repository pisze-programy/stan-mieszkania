import { z } from '@hono/zod-openapi';
import { IsoDateTimeSchema, UuidV7Schema } from '@stanmieszkania/http-contracts';
import {
  ENTRY_TEXT_MAX_LENGTH,
  ENTRY_TEXT_MIN_LENGTH,
  MARKER_COORD_MAX,
  MARKER_COORD_MIN,
  MIN_MARKER_NUMBER,
} from '../domain/entries.constants';

export const MediaEntriesPathParamsSchema = z.object({
  apartmentId: UuidV7Schema,
  mediaId: UuidV7Schema,
});

export const EntryPathParamsSchema = z.object({
  apartmentId: UuidV7Schema,
  mediaId: UuidV7Schema,
  entryId: UuidV7Schema,
});

export const DraftMarkerDtoSchema = z
  .object({
    id: UuidV7Schema,
    localNumber: z.number().int().min(MIN_MARKER_NUMBER),
    x: z.number().min(MARKER_COORD_MIN).max(MARKER_COORD_MAX),
    y: z.number().min(MARKER_COORD_MIN).max(MARKER_COORD_MAX),
  })
  .openapi('DraftMarker');

export const CreateEntryRequestSchema = z
  .object({
    text: z.string().trim().min(ENTRY_TEXT_MIN_LENGTH).max(ENTRY_TEXT_MAX_LENGTH),
    createdAt: IsoDateTimeSchema,
    markers: z.array(DraftMarkerDtoSchema).default([]),
  })
  .openapi('CreateEntryRequest');

export const MarkerDtoSchema = z
  .object({
    id: UuidV7Schema,
    entryId: UuidV7Schema,
    mediaId: UuidV7Schema,
    number: z.number().int().min(MIN_MARKER_NUMBER),
    x: z.number().min(MARKER_COORD_MIN).max(MARKER_COORD_MAX),
    y: z.number().min(MARKER_COORD_MIN).max(MARKER_COORD_MAX),
  })
  .openapi('Marker');

export const EntryAuthorDtoSchema = z
  .object({
    userId: UuidV7Schema,
    displayName: z.string(),
    shortTag: z.string(),
    color: z.string(),
    role: z.enum(['owner', 'contributor']),
  })
  .openapi('EntryAuthor');

export const EntryDtoSchema = z
  .object({
    id: UuidV7Schema,
    mediaId: UuidV7Schema,
    authorId: UuidV7Schema,
    author: EntryAuthorDtoSchema,
    text: z.string(),
    markers: z.array(MarkerDtoSchema),
    createdAt: IsoDateTimeSchema,
    serverReceivedAt: IsoDateTimeSchema,
    retractedAt: IsoDateTimeSchema.nullable(),
  })
  .openapi('Entry');

export const EntryListResponseSchema = z
  .object({
    items: z.array(EntryDtoSchema),
  })
  .openapi('EntryListResponse');

export type EntryDto = z.infer<typeof EntryDtoSchema>;
export type CreateEntryRequestDto = z.infer<typeof CreateEntryRequestSchema>;
