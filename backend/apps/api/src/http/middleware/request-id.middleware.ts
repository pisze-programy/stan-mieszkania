import { HEADER_NAMES } from '@stanmieszkania/http-contracts';
import { SystemUuidV7Generator, type IdGenerator } from '@stanmieszkania/shared';
import { createMiddleware } from 'hono/factory';
import { MAX_REQUEST_ID_HEADER_LENGTH } from '../http.constants';
import type { HttpContextVariables } from '../http-env';

export function requestIdMiddleware(idGenerator: IdGenerator = new SystemUuidV7Generator()) {
  return createMiddleware<{ Variables: Pick<HttpContextVariables, 'requestId'> }>(
    async (c, next) => {
      const incoming = c.req.header(HEADER_NAMES.REQUEST_ID)?.trim();
      const requestId =
        incoming !== undefined &&
        incoming.length > 0 &&
        incoming.length <= MAX_REQUEST_ID_HEADER_LENGTH
          ? incoming
          : idGenerator.nextId();

      c.set('requestId', requestId);
      c.header(HEADER_NAMES.REQUEST_ID, requestId);
      await next();
    },
  );
}
