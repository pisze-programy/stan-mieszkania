export const MEDIA_KINDS = ['photo', 'video'] as const;
export const MEDIA_SOURCES = ['camera', 'import'] as const;
export const MEDIA_UPLOAD_STATUSES = ['pending', 'uploaded'] as const;
export const LOCATION_SOURCES = ['device', 'exif'] as const;

export const SHA256_HEX_LENGTH = 64;
export const SHA256_HEX_REGEX = /^[0-9a-f]{64}$/;

export const MIN_LATITUDE = -90;
export const MAX_LATITUDE = 90;
export const MIN_LONGITUDE = -180;
export const MAX_LONGITUDE = 180;

export const MIN_POSITIVE_DIMENSION_PX = 1;
export const MIN_POSITIVE_BYTES = 1;
export const MIN_EXCLUSIVE_ACCURACY_METERS = 0;

export const MEDIA_R2_KEY_EXTENSION = '.jpg';
export const MEDIA_CHANGE_LOG_ENTITY_TYPE = 'media';
export const MEDIA_CHANGE_LOG_OPS = {
  CREATED: 'created',
  UPLOADED: 'uploaded',
  DELETED: 'deleted',
} as const;
