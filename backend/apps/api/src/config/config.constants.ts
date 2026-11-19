import { hours, minutes, toSeconds } from '@stanmieszkania/shared';

export const DEFAULT_CLOUD_MEDIA_QUOTA = 250;
export const MIN_CLOUD_MEDIA_QUOTA = 1;

export const DEFAULT_PRESIGN_PUT_TTL_SECONDS = toSeconds(minutes(15));
export const DEFAULT_PRESIGN_GET_TTL_SECONDS = toSeconds(hours(1));
export const MIN_PRESIGN_TTL_SECONDS = 60;
export const DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_SECONDS = toSeconds(hours(24));
export const MIN_ABANDONED_PENDING_UPLOAD_TTL_SECONDS = 60;

export const DEFAULT_INVITE_RATE_LIMIT_MAX_ATTEMPTS = 5;
export const MIN_INVITE_RATE_LIMIT_MAX_ATTEMPTS = 1;
export const DEFAULT_INVITE_RATE_LIMIT_WINDOW_SECONDS = toSeconds(minutes(15));
export const MIN_INVITE_RATE_LIMIT_WINDOW_SECONDS = 60;

export const DEFAULT_JPEG_MAX_DIMENSION_PX = 3000;
export const MIN_JPEG_MAX_DIMENSION_PX = 320;
export const DEFAULT_JPEG_QUALITY = 0.8;
export const MIN_JPEG_QUALITY = 0.1;
export const MAX_JPEG_QUALITY = 1.0;
export const DEFAULT_JPEG_MAX_BYTES = 3_145_728;
export const MIN_JPEG_MAX_BYTES = 102_400;

export const DEFAULT_MIN_SUPPORTED_APP_VERSION = '1.0.0';
export const DEFAULT_AUTH_MODE = 'local';
export const DEFAULT_STORAGE_MODE = 'local';
