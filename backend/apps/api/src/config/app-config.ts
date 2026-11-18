import {
  createDomainError,
  err,
  ok,
  seconds,
  type DomainError,
  type Result,
} from '@stanmieszkania/shared';
import { EnvVarsSchema } from './env.schema';

export type AuthMode = 'local' | 'firebase';
export type StorageMode = 'local' | 'r2';

export interface AppConfig {
  readonly cloudMediaQuotaPerApartment: number;
  readonly presignPutTtlMs: number;
  readonly presignGetTtlMs: number;
  readonly inviteCodeRateLimitMaxAttempts: number;
  readonly inviteCodeRateLimitWindowMs: number;
  readonly jpegMaxDimensionPx: number;
  readonly jpegQuality: number;
  readonly jpegMaxBytes: number;
  readonly minSupportedAppVersion: string;
  readonly authMode: AuthMode;
  readonly storageMode: StorageMode;
  readonly firebaseProjectId?: string;
}

export type AppConfigError = DomainError<'INVALID_APP_CONFIG'>;

export function safeParseAppConfig(rawEnv: unknown): Result<AppConfig, AppConfigError> {
  const parsed = EnvVarsSchema.safeParse(rawEnv ?? {});
  if (!parsed.success) {
    return err(
      createDomainError('INVALID_APP_CONFIG', 'Invalid worker environment configuration', {
        issues: parsed.error.issues.map((issue) => ({
          path: issue.path.join('.'),
          message: issue.message,
        })),
      }),
    );
  }

  const vars = parsed.data;
  const config: AppConfig = {
    cloudMediaQuotaPerApartment: vars.CLOUD_MEDIA_QUOTA_PER_APARTMENT,
    presignPutTtlMs: seconds(vars.PRESIGN_PUT_TTL_SECONDS),
    presignGetTtlMs: seconds(vars.PRESIGN_GET_TTL_SECONDS),
    inviteCodeRateLimitMaxAttempts: vars.INVITE_CODE_RATE_LIMIT_MAX_ATTEMPTS,
    inviteCodeRateLimitWindowMs: seconds(vars.INVITE_CODE_RATE_LIMIT_WINDOW_SECONDS),
    jpegMaxDimensionPx: vars.JPEG_MAX_DIMENSION_PX,
    jpegQuality: vars.JPEG_QUALITY,
    jpegMaxBytes: vars.JPEG_MAX_BYTES,
    minSupportedAppVersion: vars.MIN_SUPPORTED_APP_VERSION,
    authMode: vars.AUTH_MODE,
    storageMode: vars.STORAGE_MODE,
    ...(vars.FIREBASE_PROJECT_ID !== undefined
      ? { firebaseProjectId: vars.FIREBASE_PROJECT_ID }
      : {}),
  };

  return ok(config);
}

export function parseAppConfig(rawEnv: unknown): AppConfig {
  const result = safeParseAppConfig(rawEnv);
  if (!result.ok) {
    throw new Error(`${result.error.code}: ${result.error.message}`);
  }
  return result.value;
}
