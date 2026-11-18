import {
  HEADER_NAMES,
  HTTP_STATUS,
  PROBLEM_JSON_CONTENT_TYPE,
  ProblemDetailsSchema,
} from '@stanmieszkania/http-contracts';
import { isUuidV7 } from '@stanmieszkania/shared';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { createApp } from './app';
import { PublicAppConfigSchema } from './modules/app-config';

describe('API app, middlewares, and /v1/config', () => {
  it('generates X-Request-Id when missing and echoes incoming X-Request-Id', async () => {
    const idGenerator = new SequentialUuidV7Generator();
    const app = createApp({ overrides: { idGenerator } });

    const resGenerated = await app.request('/v1/config', {}, {});
    expect(resGenerated.status).toBe(HTTP_STATUS.OK);
    const generatedId = resGenerated.headers.get(HEADER_NAMES.REQUEST_ID);
    expect(generatedId).not.toBeNull();
    if (generatedId !== null) {
      expect(isUuidV7(generatedId)).toBe(true);
    }

    const resEcho = await app.request(
      '/v1/config',
      { headers: { [HEADER_NAMES.REQUEST_ID]: 'client-trace-42' } },
      {},
    );
    expect(resEcho.status).toBe(HTTP_STATUS.OK);
    expect(resEcho.headers.get(HEADER_NAMES.REQUEST_ID)).toBe('client-trace-42');
  });

  it('returns public config from GET /v1/config even when client version is below minimum', async () => {
    const app = createApp();
    const res = await app.request(
      '/v1/config',
      { headers: { [HEADER_NAMES.APP_VERSION]: '0.9.0' } },
      { MIN_SUPPORTED_APP_VERSION: '1.0.0', CLOUD_MEDIA_QUOTA_PER_APARTMENT: '300' },
    );

    expect(res.status).toBe(HTTP_STATUS.OK);
    const body = PublicAppConfigSchema.parse(await res.json());
    expect(body).toEqual({
      minSupportedAppVersion: '1.0.0',
      cloudMediaQuotaPerApartment: 300,
      jpegCompression: {
        maxDimensionPx: 3000,
        quality: 0.8,
        maxBytes: 3_145_728,
      },
    });
  });

  it('enforces X-App-Version format and minimum version on non-config routes', async () => {
    const app = createApp();

    const invalidRes = await app.request(
      '/v1/unknown',
      { headers: { [HEADER_NAMES.APP_VERSION]: 'bad-ver', [HEADER_NAMES.REQUEST_ID]: 'req-bad' } },
      {},
    );
    expect(invalidRes.status).toBe(HTTP_STATUS.BAD_REQUEST);
    expect(invalidRes.headers.get('Content-Type')).toContain(PROBLEM_JSON_CONTENT_TYPE);
    expect(ProblemDetailsSchema.parse(await invalidRes.json())).toMatchObject({
      code: 'VALIDATION_ERROR',
      requestId: 'req-bad',
    });

    const outdatedRes = await app.request(
      '/v1/unknown',
      { headers: { [HEADER_NAMES.APP_VERSION]: '0.9.9', [HEADER_NAMES.REQUEST_ID]: 'req-old' } },
      { MIN_SUPPORTED_APP_VERSION: '1.0.0' },
    );
    expect(outdatedRes.status).toBe(HTTP_STATUS.UPGRADE_REQUIRED);
    expect(ProblemDetailsSchema.parse(await outdatedRes.json())).toMatchObject({
      code: 'APP_UPDATE_REQUIRED',
      requestId: 'req-old',
    });
  });

  it('returns 404 ROUTE_NOT_FOUND problem+json for unknown routes', async () => {
    const app = createApp();
    const res = await app.request(
      '/v1/does-not-exist',
      { headers: { [HEADER_NAMES.APP_VERSION]: '1.0.0', [HEADER_NAMES.REQUEST_ID]: 'req-404' } },
      {},
    );

    expect(res.status).toBe(HTTP_STATUS.NOT_FOUND);
    expect(res.headers.get('Content-Type')).toContain(PROBLEM_JSON_CONTENT_TYPE);
    expect(ProblemDetailsSchema.parse(await res.json())).toMatchObject({
      status: 404,
      code: 'ROUTE_NOT_FOUND',
      requestId: 'req-404',
    });
  });

  it('returns 500 INTERNAL_ERROR problem+json without leaking error details on uncaught errors', async () => {
    const logger = new RecordingLogger();
    const clock = new FixedClock();
    const app = createApp({ overrides: { logger, clock } });

    const res = await app.request(
      '/v1/config',
      { headers: { [HEADER_NAMES.REQUEST_ID]: 'req-500' } },
      { CLOUD_MEDIA_QUOTA_PER_APARTMENT: '0' },
    );

    expect(res.status).toBe(HTTP_STATUS.INTERNAL_SERVER_ERROR);
    expect(res.headers.get('Content-Type')).toContain(PROBLEM_JSON_CONTENT_TYPE);
    const problem = ProblemDetailsSchema.parse(await res.json());
    expect(problem).toMatchObject({
      status: 500,
      code: 'INTERNAL_ERROR',
      detail: 'An unexpected internal error occurred',
      requestId: 'req-500',
    });
    expect(JSON.stringify(problem)).not.toContain('INVALID_APP_CONFIG');
  });
});
