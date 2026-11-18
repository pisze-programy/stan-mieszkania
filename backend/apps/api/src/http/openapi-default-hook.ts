import type { Hook } from '@hono/zod-openapi';
import { validationErrorResponse } from './domain-error-to-http.mapper';
import { UNKNOWN_REQUEST_ID } from './http.constants';

export function createOpenApiDefaultHook<E extends { Variables: { requestId: string } }>(): Hook<
  unknown,
  E,
  string,
  Response | undefined
> {
  return (result, c) => {
    if (!result.success) {
      const requestIdValue: unknown = c.get('requestId');
      const requestId = typeof requestIdValue === 'string' ? requestIdValue : UNKNOWN_REQUEST_ID;
      return validationErrorResponse(c, result.error, requestId);
    }
    return undefined;
  };
}
