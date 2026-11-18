import { hours, minutes } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { parseAppConfig, safeParseAppConfig } from './app-config';

describe('parseAppConfig', () => {
  it('parses defaults when optional env vars are omitted', () => {
    const config = parseAppConfig({});

    expect(config).toEqual({
      cloudMediaQuotaPerApartment: 250,
      presignPutTtlMs: minutes(15),
      presignGetTtlMs: hours(1),
      inviteCodeRateLimitMaxAttempts: 5,
      inviteCodeRateLimitWindowMs: minutes(15),
      jpegMaxDimensionPx: 3000,
      jpegQuality: 0.8,
      jpegMaxBytes: 3_145_728,
      minSupportedAppVersion: '1.0.0',
      authMode: 'local',
      storageMode: 'local',
    });
    expect('firebaseProjectId' in config).toBe(false);
  });

  it('coerces string Wrangler vars into typed AppConfig fields', () => {
    const config = parseAppConfig({
      CLOUD_MEDIA_QUOTA_PER_APARTMENT: '500',
      PRESIGN_PUT_TTL_SECONDS: '300',
      PRESIGN_GET_TTL_SECONDS: '1800',
      INVITE_CODE_RATE_LIMIT_MAX_ATTEMPTS: '10',
      INVITE_CODE_RATE_LIMIT_WINDOW_SECONDS: '600',
      JPEG_MAX_DIMENSION_PX: '2048',
      JPEG_QUALITY: '0.75',
      JPEG_MAX_BYTES: '2097152',
      MIN_SUPPORTED_APP_VERSION: '1.2.0',
      AUTH_MODE: 'firebase',
      STORAGE_MODE: 'r2',
      FIREBASE_PROJECT_ID: 'stanmieszkania-prod',
    });

    expect(config).toEqual({
      cloudMediaQuotaPerApartment: 500,
      presignPutTtlMs: 300_000,
      presignGetTtlMs: 1_800_000,
      inviteCodeRateLimitMaxAttempts: 10,
      inviteCodeRateLimitWindowMs: 600_000,
      jpegMaxDimensionPx: 2048,
      jpegQuality: 0.75,
      jpegMaxBytes: 2_097_152,
      minSupportedAppVersion: '1.2.0',
      authMode: 'firebase',
      storageMode: 'r2',
      firebaseProjectId: 'stanmieszkania-prod',
    });
  });

  it('returns INVALID_APP_CONFIG error for invalid values and throws in parseAppConfig', () => {
    const invalid = {
      CLOUD_MEDIA_QUOTA_PER_APARTMENT: '0',
      MIN_SUPPORTED_APP_VERSION: 'invalid',
    };

    const result = safeParseAppConfig(invalid);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('INVALID_APP_CONFIG');
    }

    expect(() => parseAppConfig(invalid)).toThrow(/INVALID_APP_CONFIG/);
  });
});
