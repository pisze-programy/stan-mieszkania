import type { D1Database, DurableObjectNamespace, R2Bucket } from '@cloudflare/workers-types';
import { SEMVER_REGEX } from '@stanmieszkania/http-contracts';
import { z } from 'zod';
import {
  DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_SECONDS,
  DEFAULT_AUTH_MODE,
  DEFAULT_CLOUD_MEDIA_QUOTA,
  DEFAULT_INVITE_RATE_LIMIT_MAX_ATTEMPTS,
  DEFAULT_INVITE_RATE_LIMIT_WINDOW_SECONDS,
  DEFAULT_JPEG_MAX_BYTES,
  DEFAULT_JPEG_MAX_DIMENSION_PX,
  DEFAULT_JPEG_QUALITY,
  DEFAULT_MIN_SUPPORTED_APP_VERSION,
  DEFAULT_PRESIGN_GET_TTL_SECONDS,
  DEFAULT_PRESIGN_PUT_TTL_SECONDS,
  DEFAULT_STORAGE_MODE,
  MAX_JPEG_QUALITY,
  MIN_ABANDONED_PENDING_UPLOAD_TTL_SECONDS,
  MIN_CLOUD_MEDIA_QUOTA,
  MIN_INVITE_RATE_LIMIT_MAX_ATTEMPTS,
  MIN_INVITE_RATE_LIMIT_WINDOW_SECONDS,
  MIN_JPEG_MAX_BYTES,
  MIN_JPEG_MAX_DIMENSION_PX,
  MIN_JPEG_QUALITY,
  MIN_PRESIGN_TTL_SECONDS,
} from './config.constants';

export const EnvVarsSchema = z.object({
  CLOUD_MEDIA_QUOTA_PER_APARTMENT: z.coerce
    .number()
    .int()
    .min(MIN_CLOUD_MEDIA_QUOTA)
    .default(DEFAULT_CLOUD_MEDIA_QUOTA),
  PRESIGN_PUT_TTL_SECONDS: z.coerce
    .number()
    .int()
    .min(MIN_PRESIGN_TTL_SECONDS)
    .default(DEFAULT_PRESIGN_PUT_TTL_SECONDS),
  PRESIGN_GET_TTL_SECONDS: z.coerce
    .number()
    .int()
    .min(MIN_PRESIGN_TTL_SECONDS)
    .default(DEFAULT_PRESIGN_GET_TTL_SECONDS),
  ABANDONED_PENDING_UPLOAD_TTL_SECONDS: z.coerce
    .number()
    .int()
    .min(MIN_ABANDONED_PENDING_UPLOAD_TTL_SECONDS)
    .default(DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_SECONDS),
  INVITE_CODE_RATE_LIMIT_MAX_ATTEMPTS: z.coerce
    .number()
    .int()
    .min(MIN_INVITE_RATE_LIMIT_MAX_ATTEMPTS)
    .default(DEFAULT_INVITE_RATE_LIMIT_MAX_ATTEMPTS),
  INVITE_CODE_RATE_LIMIT_WINDOW_SECONDS: z.coerce
    .number()
    .int()
    .min(MIN_INVITE_RATE_LIMIT_WINDOW_SECONDS)
    .default(DEFAULT_INVITE_RATE_LIMIT_WINDOW_SECONDS),
  JPEG_MAX_DIMENSION_PX: z.coerce
    .number()
    .int()
    .min(MIN_JPEG_MAX_DIMENSION_PX)
    .default(DEFAULT_JPEG_MAX_DIMENSION_PX),
  JPEG_QUALITY: z.coerce
    .number()
    .min(MIN_JPEG_QUALITY)
    .max(MAX_JPEG_QUALITY)
    .default(DEFAULT_JPEG_QUALITY),
  JPEG_MAX_BYTES: z.coerce.number().int().min(MIN_JPEG_MAX_BYTES).default(DEFAULT_JPEG_MAX_BYTES),
  MIN_SUPPORTED_APP_VERSION: z
    .string()
    .regex(SEMVER_REGEX, 'Must be a valid semantic version')
    .default(DEFAULT_MIN_SUPPORTED_APP_VERSION),
  AUTH_MODE: z.enum(['local', 'firebase']).default(DEFAULT_AUTH_MODE),
  STORAGE_MODE: z.enum(['local', 'r2']).default(DEFAULT_STORAGE_MODE),
  FIREBASE_PROJECT_ID: z.string().min(1).optional(),
  FIREBASE_CLIENT_EMAIL: z.string().min(1).optional(),
  FIREBASE_PRIVATE_KEY_PEM: z.string().min(1).optional(),
  APPLE_TEAM_ID: z.string().min(1).optional(),
  APPLE_CLIENT_ID: z.string().min(1).optional(),
  APPLE_KEY_ID: z.string().min(1).optional(),
  APPLE_PRIVATE_KEY_PEM: z.string().min(1).optional(),
});

export type RawEnvVars = z.infer<typeof EnvVarsSchema>;

export interface WorkerRuntimeBindings {
  readonly DB: D1Database;
  readonly MEDIA_BUCKET?: R2Bucket;
  readonly USER_GUARD?: DurableObjectNamespace;
  readonly APARTMENT_COORDINATOR?: DurableObjectNamespace;
}
