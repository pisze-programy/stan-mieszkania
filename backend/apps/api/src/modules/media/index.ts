export {
  LOCATION_SOURCES,
  MAX_LATITUDE,
  MAX_LONGITUDE,
  MEDIA_CHANGE_LOG_ENTITY_TYPE,
  MEDIA_CHANGE_LOG_OPS,
  MEDIA_KINDS,
  MEDIA_R2_KEY_EXTENSION,
  MEDIA_SOURCES,
  MEDIA_UPLOAD_STATUSES,
  MIN_EXCLUSIVE_ACCURACY_METERS,
  MIN_LATITUDE,
  MIN_LONGITUDE,
  MIN_POSITIVE_BYTES,
  MIN_POSITIVE_DIMENSION_PX,
  SHA256_HEX_LENGTH,
  SHA256_HEX_REGEX,
} from './domain/media.constants';
export {
  MEDIA_ERROR_CODES,
  mediaAccessDeniedError,
  mediaAlreadyDeletedError,
  mediaAuthorRequiredError,
  mediaConflictError,
  mediaHashMismatchError,
  mediaInvalidSha256Error,
  mediaNotFoundError,
  mediaObjectNotUploadedError,
  mediaValidationFailedError,
  quotaExceededError,
  videoDisabledInMvpError,
  type MediaError,
  type MediaErrorCode,
} from './domain/media.errors';
export { normalizeSha256Hash } from './domain/sha256-hash.value-object';
export { validateMediaLocation } from './domain/media-location.value-object';
export { canReserveCloudMediaSlot } from './domain/media-quota.policy';
export {
  buildMediaR2Key,
  confirmMediaUploaded,
  createPendingMedia,
  isMediaVerified,
  softDeleteMedia,
  type ConfirmMediaUploadedInput,
  type CreatePendingMediaInput,
  type LocationSource,
  type Media,
  type MediaKind,
  type MediaLocation,
  type MediaSource,
  type MediaUploadStatus,
  type SoftDeleteMediaInput,
} from './domain/media.entity';
export type {
  ConfirmMediaUploadedParams,
  MediaRepository,
  ReservePendingMediaParams,
  SoftDeleteMediaParams,
} from './domain/media.repository';
export type {
  CreatePresignedGetUrlParams,
  CreatePresignedPutUrlParams,
  ObjectStoragePort,
  PresignedUrl,
  UploadedObjectMetadata,
} from './domain/object-storage.port';
