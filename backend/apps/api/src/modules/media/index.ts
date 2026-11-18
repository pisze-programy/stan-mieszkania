export {
  LOCATION_SOURCES,
  MAX_LATITUDE,
  MAX_LONGITUDE,
  MEDIA_CHANGE_LOG_ENTITY_TYPE,
  MEDIA_CHANGE_LOG_OPS,
  MEDIA_CONTENT_TYPE_JPEG,
  MEDIA_KINDS,
  MEDIA_R2_KEY_EXTENSION,
  MEDIA_SOURCES,
  MEDIA_TIMEZONE_MAX_LENGTH,
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
  ApartmentMediaAccess,
  ConfirmMediaUploadedParams,
  MediaAuthorSummary,
  MediaListQuery,
  MediaRepository,
  MediaWithAuthor,
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
export {
  createConfirmMediaUploadUseCase,
  type ConfirmMediaUploadCommand,
  type ConfirmMediaUploadDeps,
  type ConfirmMediaUploadUseCase,
} from './application/confirm-media-upload.use-case';
export {
  createGetMediaDownloadUrlUseCase,
  type GetMediaDownloadUrlDeps,
  type GetMediaDownloadUrlQuery,
  type GetMediaDownloadUrlUseCase,
} from './application/get-media-download-url.use-case';
export {
  createGetMediaUseCase,
  type GetMediaDeps,
  type GetMediaQuery,
  type GetMediaUseCase,
} from './application/get-media.use-case';
export {
  createInitMediaUploadUseCase,
  type InitMediaUploadCommand,
  type InitMediaUploadDeps,
  type InitMediaUploadResult,
  type InitMediaUploadUseCase,
} from './application/init-media-upload.use-case';
export {
  createListApartmentMediaUseCase,
  type ListApartmentMediaDeps,
  type ListApartmentMediaQuery,
  type ListApartmentMediaUseCase,
} from './application/list-apartment-media.use-case';
export {
  createSoftDeleteMediaUseCase,
  type SoftDeleteMediaCommand,
  type SoftDeleteMediaDeps,
  type SoftDeleteMediaUseCase,
} from './application/soft-delete-media.use-case';
export { MEDIA_TABLE, mediaRowSchema, type MediaRow } from './infrastructure/media.table';
export { createD1MediaRepository } from './infrastructure/d1-media.repository';
export {
  LOCAL_STORAGE_ROUTE_PATH,
  createFailClosedObjectStorage,
  createLocalR2ObjectStorage,
  verifyLocalStorageSignature,
  type LocalR2BucketLike,
  type LocalR2ObjectStorageDeps,
} from './infrastructure/local-r2-object-storage';
export {
  ApartmentMediaParamsSchema,
  InitMediaUploadRequestSchema,
  InitMediaUploadResponseSchema,
  MediaAuthorSummarySchema,
  MediaDtoSchema,
  MediaTimelineQuerySchema,
  MediaTimelineResponseSchema,
  MediaWithAuthorDtoSchema,
  PresignedUrlDtoSchema,
  type InitMediaUploadResponseDto,
  type MediaDto,
  type MediaTimelineResponseDto,
  type MediaWithAuthorDto,
  type PresignedUrlDto,
} from './http/media.schema';
export {
  confirmMediaUploadRoute,
  deleteMediaRoute,
  getMediaDownloadUrlRoute,
  getMediaRoute,
  initMediaUploadRoute,
  listApartmentMediaRoute,
} from './http/media.route-defs';
export { createMediaRoutes, type MediaRouteHandlers } from './http/media.routes';
export {
  createLocalStorageRoutes,
  type LocalStorageBucketPort,
  type LocalStorageHandlers,
} from './http/local-storage.routes';
export { InMemoryMediaRepository, InMemoryObjectStorage } from './testing/in-memory-media.doubles';
