import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import {
  HTTP_STATUS,
  PROBLEM_JSON_CONTENT_TYPE,
  ProblemDetailsSchema,
} from '@stanmieszkania/http-contracts';
import { createDomainError } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { mapDomainErrorToHttp } from './domain-error-to-http.mapper';
import { COMMON_ERROR_CODES } from './http.constants';
import { createOpenApiDefaultHook } from './openapi-default-hook';

describe('domain-error-to-http mapper and OpenAPI validation hook', () => {
  it('maps known DomainError codes to expected HTTP status codes and ProblemDetails', () => {
    const cases = [
      [COMMON_ERROR_CODES.VALIDATION_ERROR, HTTP_STATUS.BAD_REQUEST],
      [COMMON_ERROR_CODES.UNAUTHORIZED, HTTP_STATUS.UNAUTHORIZED],
      [COMMON_ERROR_CODES.FORBIDDEN, HTTP_STATUS.FORBIDDEN],
      [COMMON_ERROR_CODES.NOT_FOUND, HTTP_STATUS.NOT_FOUND],
      [COMMON_ERROR_CODES.CONFLICT, HTTP_STATUS.CONFLICT],
      [COMMON_ERROR_CODES.QUOTA_EXCEEDED, HTTP_STATUS.UNPROCESSABLE_ENTITY],
      [COMMON_ERROR_CODES.APP_UPDATE_REQUIRED, HTTP_STATUS.UPGRADE_REQUIRED],
      [COMMON_ERROR_CODES.RATE_LIMITED, HTTP_STATUS.TOO_MANY_REQUESTS],
    ] as const;

    for (const [code, expectedStatus] of cases) {
      const mapped = mapDomainErrorToHttp(
        createDomainError(code, 'Error detail', { field: 'value' }),
        'req-1',
      );
      expect(mapped.status).toBe(expectedStatus);
      expect(ProblemDetailsSchema.parse(mapped.problem)).toMatchObject({
        status: expectedStatus,
        code,
        detail: 'Error detail',
        requestId: 'req-1',
        details: { field: 'value' },
      });
    }
  });

  it('maps unknown error codes to 500 Internal Server Error', () => {
    const mapped = mapDomainErrorToHttp(
      createDomainError('SOMETHING_UNEXPECTED', 'Unexpected'),
      'req-2',
    );

    expect(mapped.status).toBe(HTTP_STATUS.INTERNAL_SERVER_ERROR);
    expect(mapped.problem.code).toBe('SOMETHING_UNEXPECTED');
  });

  it('formats OpenAPI Zod validation failures as 400 application/problem+json', async () => {
    const app = new OpenAPIHono<{ Variables: { requestId: string } }>({
      defaultHook: createOpenApiDefaultHook<{ Variables: { requestId: string } }>(),
    });
    app.use('*', async (c, next) => {
      c.set('requestId', 'req-val-1');
      await next();
    });

    const testRoute = createRoute({
      method: 'post',
      path: '/items',
      request: {
        body: {
          content: {
            'application/json': {
              schema: z.object({ name: z.string().min(3) }),
            },
          },
        },
      },
      responses: {
        [HTTP_STATUS.OK]: {
          description: 'OK',
        },
      },
    });

    app.openapi(testRoute, (c) => c.body(null, HTTP_STATUS.OK));

    const res = await app.request('/items', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'a' }),
    });

    expect(res.status).toBe(HTTP_STATUS.BAD_REQUEST);
    expect(res.headers.get('Content-Type')).toContain(PROBLEM_JSON_CONTENT_TYPE);
    const body = ProblemDetailsSchema.parse(await res.json());
    expect(body.code).toBe(COMMON_ERROR_CODES.VALIDATION_ERROR);
    expect(body.requestId).toBe('req-val-1');
    expect(body.details).toHaveProperty('issues');
  });
});
