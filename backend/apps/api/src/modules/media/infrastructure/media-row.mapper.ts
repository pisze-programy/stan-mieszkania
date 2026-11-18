import { err, ok, type Result } from '@stanmieszkania/shared';
import type { Media, MediaLocation, MediaUploadStatus } from '../domain/media.entity';
import { mediaValidationFailedError, type MediaError } from '../domain/media.errors';
import type { MediaWithAuthor } from '../domain/media.repository';
import type { MediaDbUploadStatus, MediaRow } from './media.table';

const CURSOR_SEPARATOR = '|';
const CURSOR_PARTS_COUNT = 2;
const IMPORT_FLAG_TRUE = 1;
const IMPORT_FLAG_FALSE = 0;

export type MediaWithAuthorRow = MediaRow & {
  readonly author_display_name: string;
  readonly author_short_tag: string;
  readonly author_color: string;
  readonly author_role: 'owner' | 'contributor' | null;
};

export interface DecodedMediaCursor {
  readonly capturedAt: string;
  readonly id: string;
}

export function mapDbUploadStatusToDomain(status: MediaDbUploadStatus): MediaUploadStatus {
  return status === 'confirmed' ? 'uploaded' : 'pending';
}

export function mapDomainUploadStatusToDb(status: MediaUploadStatus): MediaDbUploadStatus {
  return status === 'uploaded' ? 'confirmed' : 'pending';
}

function mapLocationFromRow(row: MediaRow): MediaLocation | null {
  if (row.lat === null || row.lng === null) {
    return null;
  }
  return {
    lat: row.lat,
    lng: row.lng,
    accuracyM: row.accuracy_m,
    locationSource: row.location_source,
  };
}

export function mapMediaRowToEntity(row: MediaRow): Media {
  return {
    id: row.id,
    apartmentId: row.apartment_id,
    authorId: row.author_id,
    kind: row.kind,
    source: row.source,
    uploadStatus: mapDbUploadStatusToDomain(row.upload_status),
    sha256: row.sha256,
    capturedAt: row.captured_at,
    capturedTz: row.captured_tz,
    capturedAtFromImport: row.captured_at_from_import === IMPORT_FLAG_TRUE,
    serverReceivedAt: row.server_received_at,
    location: mapLocationFromRow(row),
    width: row.width,
    height: row.height,
    bytes: row.bytes,
    r2Key: row.r2_key,
    deletedAt: row.deleted_at,
    deletedBy: row.deleted_by,
  };
}

export function mapMediaEntityToRow(media: Media): MediaRow {
  return {
    id: media.id,
    apartment_id: media.apartmentId,
    author_id: media.authorId,
    kind: media.kind,
    source: media.source,
    upload_status: mapDomainUploadStatusToDb(media.uploadStatus),
    sha256: media.sha256,
    captured_at: media.capturedAt,
    captured_tz: media.capturedTz,
    captured_at_from_import: media.capturedAtFromImport ? IMPORT_FLAG_TRUE : IMPORT_FLAG_FALSE,
    server_received_at: media.serverReceivedAt,
    lat: media.location?.lat ?? null,
    lng: media.location?.lng ?? null,
    accuracy_m: media.location?.accuracyM ?? null,
    location_source: media.location?.locationSource ?? null,
    width: media.width,
    height: media.height,
    bytes: media.bytes,
    r2_key: media.r2Key,
    deleted_at: media.deletedAt,
    deleted_by: media.deletedBy,
  };
}

export function mapMediaWithAuthorRow(row: MediaWithAuthorRow): MediaWithAuthor {
  return {
    media: mapMediaRowToEntity(row),
    author: {
      userId: row.author_id,
      displayName: row.author_display_name,
      shortTag: row.author_short_tag,
      color: row.author_color,
      role: row.author_role ?? 'contributor',
    },
  };
}

export function encodeMediaCursor(media: Pick<Media, 'capturedAt' | 'id'>): string {
  return `${media.capturedAt}${CURSOR_SEPARATOR}${media.id}`;
}

export function decodeMediaCursor(raw: string): Result<DecodedMediaCursor, MediaError> {
  const parts = raw.split(CURSOR_SEPARATOR);
  const capturedAt = parts[0] ?? '';
  const id = parts[1] ?? '';
  if (parts.length !== CURSOR_PARTS_COUNT || capturedAt.length === 0 || id.length === 0) {
    return err(mediaValidationFailedError('Invalid media pagination cursor'));
  }
  return ok({ capturedAt, id });
}
