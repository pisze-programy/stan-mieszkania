import { createDomainError, type DomainError, type ErrorDetails } from '@stanmieszkania/shared';

export const MEDIA_ERROR_CODES = {
  QUOTA_EXCEEDED: 'QUOTA_EXCEEDED',
  VIDEO_DISABLED_IN_MVP: 'VIDEO_DISABLED_IN_MVP',
  MEDIA_NOT_FOUND: 'MEDIA_NOT_FOUND',
  MEDIA_ACCESS_DENIED: 'MEDIA_ACCESS_DENIED',
  MEDIA_AUTHOR_REQUIRED: 'MEDIA_AUTHOR_REQUIRED',
  MEDIA_INVALID_SHA256: 'MEDIA_INVALID_SHA256',
  MEDIA_HASH_MISMATCH: 'MEDIA_HASH_MISMATCH',
  MEDIA_OBJECT_NOT_UPLOADED: 'MEDIA_OBJECT_NOT_UPLOADED',
  MEDIA_ALREADY_DELETED: 'MEDIA_ALREADY_DELETED',
  MEDIA_CONFLICT: 'MEDIA_CONFLICT',
  MEDIA_VALIDATION_FAILED: 'MEDIA_VALIDATION_FAILED',
} as const;

export type MediaErrorCode = (typeof MEDIA_ERROR_CODES)[keyof typeof MEDIA_ERROR_CODES];
export type MediaError = DomainError<MediaErrorCode>;

export function quotaExceededError(cloudMediaCount: number, quota: number): MediaError {
  return createDomainError(
    MEDIA_ERROR_CODES.QUOTA_EXCEEDED,
    'Apartment cloud media quota has been reached',
    { cloudMediaCount, quota },
  );
}

export function videoDisabledInMvpError(): MediaError {
  return createDomainError(
    MEDIA_ERROR_CODES.VIDEO_DISABLED_IN_MVP,
    'Video upload is disabled in MVP; only photos are supported',
  );
}

export function mediaNotFoundError(mediaId: string): MediaError {
  return createDomainError(MEDIA_ERROR_CODES.MEDIA_NOT_FOUND, 'Media item was not found', {
    mediaId,
  });
}

export function mediaAccessDeniedError(apartmentId: string): MediaError {
  return createDomainError(
    MEDIA_ERROR_CODES.MEDIA_ACCESS_DENIED,
    'User does not have access to media in this apartment',
    { apartmentId },
  );
}

export function mediaAuthorRequiredError(mediaId: string): MediaError {
  return createDomainError(
    MEDIA_ERROR_CODES.MEDIA_AUTHOR_REQUIRED,
    'Only the media author can delete this media item',
    { mediaId },
  );
}

export function mediaInvalidSha256Error(message: string): MediaError {
  return createDomainError(MEDIA_ERROR_CODES.MEDIA_INVALID_SHA256, message);
}

export function mediaHashMismatchError(mediaId: string): MediaError {
  return createDomainError(
    MEDIA_ERROR_CODES.MEDIA_HASH_MISMATCH,
    'Uploaded object checksum or size does not match registered media',
    { mediaId },
  );
}

export function mediaObjectNotUploadedError(mediaId: string): MediaError {
  return createDomainError(
    MEDIA_ERROR_CODES.MEDIA_OBJECT_NOT_UPLOADED,
    'Media object has not been uploaded to object storage yet',
    { mediaId },
  );
}

export function mediaAlreadyDeletedError(mediaId: string): MediaError {
  return createDomainError(
    MEDIA_ERROR_CODES.MEDIA_ALREADY_DELETED,
    'Media item has already been deleted',
    { mediaId },
  );
}

export function mediaConflictError(message: string, details?: ErrorDetails): MediaError {
  return createDomainError(MEDIA_ERROR_CODES.MEDIA_CONFLICT, message, details);
}

export function mediaValidationFailedError(message: string, details?: ErrorDetails): MediaError {
  return createDomainError(MEDIA_ERROR_CODES.MEDIA_VALIDATION_FAILED, message, details);
}
