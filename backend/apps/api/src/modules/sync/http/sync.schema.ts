import { z } from '@hono/zod-openapi';
import { IsoDateTimeSchema, UuidV7Schema } from '@stanmieszkania/http-contracts';
import { ApartmentDtoSchema, ApartmentRoleSchema } from '../../apartments';
import { MarkerDtoSchema } from '../../entries';
import { MEDIA_KINDS, MEDIA_SOURCES, MEDIA_UPLOAD_STATUSES } from '../../media';
import { SYNC_INITIAL_AFTER_SEQ } from '../domain/sync.constants';

export const SyncActorSummarySchema = z
  .object({
    userId: UuidV7Schema,
    displayName: z.string(),
    shortTag: z.string(),
    color: z.string(),
    role: ApartmentRoleSchema,
  })
  .openapi('SyncActorSummary');

export const SyncMemberSnapshotSchema = SyncActorSummarySchema.extend({
  joinedAt: IsoDateTimeSchema,
  leftAt: IsoDateTimeSchema.nullable(),
}).openapi('SyncMemberSnapshot');

// Decision Q10: SyncMediaSnapshot never includes GPS fields.
export const SyncMediaSnapshotSchema = z
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
    author: SyncActorSummarySchema,
  })
  .openapi('SyncMediaSnapshot');

export const SyncEntrySnapshotSchema = z
  .object({
    id: UuidV7Schema,
    mediaId: UuidV7Schema,
    authorId: UuidV7Schema,
    text: z.string(),
    markers: z.array(MarkerDtoSchema),
    createdAt: IsoDateTimeSchema,
    serverReceivedAt: IsoDateTimeSchema,
    retractedAt: IsoDateTimeSchema.nullable(),
    author: SyncActorSummarySchema,
  })
  .openapi('SyncEntrySnapshot');

export const SyncChangePayloadSchema = z
  .discriminatedUnion('kind', [
    z.object({ kind: z.literal('apartment'), apartment: ApartmentDtoSchema }),
    z.object({ kind: z.literal('member'), member: SyncMemberSnapshotSchema }),
    z.object({ kind: z.literal('media'), media: SyncMediaSnapshotSchema }),
    z.object({ kind: z.literal('entry'), entry: SyncEntrySnapshotSchema }),
  ])
  .openapi('SyncChangePayload');

export const HydratedSyncChangeSchema = z
  .object({
    seq: z.number().int().min(SYNC_INITIAL_AFTER_SEQ),
    apartmentId: UuidV7Schema,
    entityType: z.string(),
    entityId: z.string(),
    op: z.string(),
    createdAt: IsoDateTimeSchema,
    payload: SyncChangePayloadSchema.nullable(),
  })
  .openapi('HydratedSyncChange');

export const SyncChangesResponseSchema = z
  .object({
    changes: z.array(HydratedSyncChangeSchema),
    nextSeq: z.number().int().nullable(),
    hasMore: z.boolean(),
  })
  .openapi('SyncChangesResponse');

export const MyApartmentSyncSummarySchema = z
  .object({
    apartment: ApartmentDtoSchema,
    role: ApartmentRoleSchema,
    headSeq: z.number().int().min(SYNC_INITIAL_AFTER_SEQ),
    confirmedMediaCount: z.number().int().min(SYNC_INITIAL_AFTER_SEQ),
    latestMediaCapturedAt: IsoDateTimeSchema.nullable(),
  })
  .openapi('MyApartmentSyncSummary');

export const MyApartmentsSyncResponseSchema = z
  .object({
    items: z.array(MyApartmentSyncSummarySchema),
  })
  .openapi('MyApartmentsSyncResponse');

export type SyncChangesResponseDto = z.infer<typeof SyncChangesResponseSchema>;
export type MyApartmentsSyncResponseDto = z.infer<typeof MyApartmentsSyncResponseSchema>;
