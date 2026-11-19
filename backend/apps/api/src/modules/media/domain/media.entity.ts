import { err, ok, type Result } from '@stanmieszkania/shared';
import {
  validateMediaLocation,
  type LocationSource,
  type MediaLocation,
} from './media-location.value-object';
import {
  MEDIA_R2_KEY_EXTENSION,
  MIN_POSITIVE_BYTES,
  MIN_POSITIVE_DIMENSION_PX,
  type MEDIA_KINDS,
  type MEDIA_SOURCES,
  type MEDIA_UPLOAD_STATUSES,
} from './media.constants';
import {
  mediaAlreadyDeletedError,
  mediaAuthorRequiredError,
  mediaHashMismatchError,
  mediaObjectNotUploadedError,
  mediaValidationFailedError,
  videoDisabledInMvpError,
  type MediaError,
} from './media.errors';
import { normalizeSha256Hash } from './sha256-hash.value-object';

export type MediaKind = (typeof MEDIA_KINDS)[number];
export type MediaSource = (typeof MEDIA_SOURCES)[number];
export type MediaUploadStatus = (typeof MEDIA_UPLOAD_STATUSES)[number];
export type { LocationSource, MediaLocation };

export interface Media {
  readonly id: string;
  readonly apartmentId: string;
  readonly authorId: string;
  readonly kind: MediaKind;
  readonly source: MediaSource;
  readonly uploadStatus: MediaUploadStatus;
  readonly sha256: string;
  readonly capturedAt: string;
  readonly capturedTz: string;
  readonly capturedAtFromImport: boolean;
  readonly serverReceivedAt: string | null;
  readonly location: MediaLocation | null;
  readonly width: number;
  readonly height: number;
  readonly bytes: number;
  readonly r2Key: string;
  readonly deletedAt: string | null;
  readonly deletedBy: string | null;
}

export interface CreatePendingMediaInput {
  readonly id: string;
  readonly apartmentId: string;
  readonly authorId: string;
  readonly kind: MediaKind;
  readonly source: MediaSource;
  readonly sha256: string;
  readonly capturedAt: string;
  readonly capturedTz: string;
  readonly capturedAtFromImport: boolean;
  readonly location: MediaLocation | null;
  readonly width: number;
  readonly height: number;
  readonly bytes: number;
  readonly maxBytes: number;
}

export interface ConfirmMediaUploadedInput {
  readonly uploadedSha256: string;
  readonly uploadedBytes: number;
  readonly serverReceivedAt: string;
}

export interface SoftDeleteMediaInput {
  readonly actorUserId: string;
  readonly nowIso: string;
}

export function buildMediaR2Key(apartmentId: string, mediaId: string): string {
  return `apartments/${apartmentId}/media/${mediaId}${MEDIA_R2_KEY_EXTENSION}`;
}

export function createPendingMedia(input: CreatePendingMediaInput): Result<Media, MediaError> {
  if (input.kind === 'video') {
    return err(videoDisabledInMvpError());
  }
  const sha = normalizeSha256Hash(input.sha256);
  if (!sha.ok) {
    return sha;
  }
  const capturedTz = input.capturedTz.trim();
  if (capturedTz.length === 0 || input.capturedAt.trim().length === 0) {
    return err(mediaValidationFailedError('capturedAt and capturedTz must not be empty'));
  }
  if (
    !Number.isInteger(input.width) ||
    input.width < MIN_POSITIVE_DIMENSION_PX ||
    !Number.isInteger(input.height) ||
    input.height < MIN_POSITIVE_DIMENSION_PX
  ) {
    return err(mediaValidationFailedError('width and height must be positive integers'));
  }
  if (!Number.isInteger(input.bytes) || input.bytes < MIN_POSITIVE_BYTES) {
    return err(mediaValidationFailedError('bytes must be a positive integer'));
  }
  if (input.bytes > input.maxBytes) {
    return err(
      mediaValidationFailedError('Media byte size exceeds configured maximum', {
        bytes: input.bytes,
        maxBytes: input.maxBytes,
      }),
    );
  }
  let validatedLocation: MediaLocation | null = null;
  if (input.location !== null) {
    const loc = validateMediaLocation(input.location);
    if (!loc.ok) {
      return loc;
    }
    validatedLocation = loc.value;
  }

  return ok({
    id: input.id,
    apartmentId: input.apartmentId,
    authorId: input.authorId,
    kind: input.kind,
    source: input.source,
    uploadStatus: 'pending',
    sha256: sha.value,
    capturedAt: input.capturedAt,
    capturedTz,
    capturedAtFromImport: input.capturedAtFromImport,
    serverReceivedAt: null,
    location: validatedLocation,
    width: input.width,
    height: input.height,
    bytes: input.bytes,
    r2Key: buildMediaR2Key(input.apartmentId, input.id),
    deletedAt: null,
    deletedBy: null,
  });
}

export function confirmMediaUploaded(
  media: Media,
  input: ConfirmMediaUploadedInput,
): Result<Media, MediaError> {
  if (media.deletedAt !== null) {
    return err(mediaAlreadyDeletedError(media.id));
  }
  const uploadedSha = normalizeSha256Hash(input.uploadedSha256);
  if (!uploadedSha.ok) {
    return uploadedSha;
  }
  if (uploadedSha.value !== media.sha256 || input.uploadedBytes !== media.bytes) {
    return err(mediaHashMismatchError(media.id));
  }
  if (media.uploadStatus === 'uploaded') {
    return ok(media);
  }
  return ok({
    ...media,
    uploadStatus: 'uploaded',
    serverReceivedAt: input.serverReceivedAt,
  });
}

export function softDeleteMedia(
  media: Media,
  input: SoftDeleteMediaInput,
): Result<Media, MediaError> {
  if (media.authorId !== input.actorUserId) {
    return err(mediaAuthorRequiredError(media.id));
  }
  if (media.deletedAt !== null) {
    return ok(media);
  }
  if (media.uploadStatus !== 'uploaded') {
    return err(mediaObjectNotUploadedError(media.id));
  }
  return ok({
    ...media,
    deletedAt: input.nowIso,
    deletedBy: input.actorUserId,
  });
}

export function isMediaVerified(media: Pick<Media, 'uploadStatus' | 'serverReceivedAt'>): boolean {
  return media.uploadStatus === 'uploaded' && media.serverReceivedAt !== null;
}
