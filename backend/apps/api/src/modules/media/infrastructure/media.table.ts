import { defineTable, type TableRow } from '@stanmieszkania/d1';
import { z } from 'zod';
import { LOCATION_SOURCES, MEDIA_KINDS, MEDIA_SOURCES } from '../domain/media.constants';

export const MEDIA_DB_UPLOAD_STATUSES = ['pending', 'confirmed'] as const;

export const mediaRowSchema = z.object({
  id: z.string(),
  apartment_id: z.string(),
  author_id: z.string(),
  kind: z.enum(MEDIA_KINDS),
  source: z.enum(MEDIA_SOURCES),
  upload_status: z.enum(MEDIA_DB_UPLOAD_STATUSES),
  sha256: z.string(),
  captured_at: z.string(),
  captured_tz: z.string(),
  captured_at_from_import: z.number().int(),
  server_received_at: z.string().nullable(),
  lat: z.number().nullable(),
  lng: z.number().nullable(),
  accuracy_m: z.number().nullable(),
  location_source: z.enum(LOCATION_SOURCES).nullable(),
  width: z.number().int(),
  height: z.number().int(),
  bytes: z.number().int(),
  r2_key: z.string(),
  deleted_at: z.string().nullable(),
  deleted_by: z.string().nullable(),
});

export const MEDIA_TABLE = defineTable({
  name: 'media',
  columns: {
    id: 'id',
    apartmentId: 'apartment_id',
    authorId: 'author_id',
    kind: 'kind',
    source: 'source',
    uploadStatus: 'upload_status',
    sha256: 'sha256',
    capturedAt: 'captured_at',
    capturedTz: 'captured_tz',
    capturedAtFromImport: 'captured_at_from_import',
    serverReceivedAt: 'server_received_at',
    lat: 'lat',
    lng: 'lng',
    accuracyM: 'accuracy_m',
    locationSource: 'location_source',
    width: 'width',
    height: 'height',
    bytes: 'bytes',
    r2Key: 'r2_key',
    deletedAt: 'deleted_at',
    deletedBy: 'deleted_by',
  },
  rowSchema: mediaRowSchema,
});

export type MediaRow = TableRow<typeof MEDIA_TABLE>;
export type MediaDbUploadStatus = (typeof MEDIA_DB_UPLOAD_STATUSES)[number];
