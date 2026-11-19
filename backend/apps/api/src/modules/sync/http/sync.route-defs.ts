import { createRoute } from '@hono/zod-openapi';
import {
  CursorQuerySchema,
  HTTP_STATUS,
  ProblemDetailsSchema,
} from '@stanmieszkania/http-contracts';
import { ApartmentIdParamsSchema } from '../../apartments';
import { MyApartmentsSyncResponseSchema, SyncChangesResponseSchema } from './sync.schema';

const problemJsonContent = {
  'application/problem+json': { schema: ProblemDetailsSchema },
} as const;

const COMMON_AUTH_AND_SERVER_ERRORS = {
  [HTTP_STATUS.UNAUTHORIZED]: { description: 'Unauthorized', content: problemJsonContent },
  [HTTP_STATUS.INTERNAL_SERVER_ERROR]: {
    description: 'Unexpected internal error',
    content: problemJsonContent,
  },
} as const;

export const getApartmentChangesRoute = createRoute({
  method: 'get',
  path: '/apartments/{apartmentId}/changes',
  tags: ['Sync'],
  security: [{ bearerAuth: [] }],
  request: {
    params: ApartmentIdParamsSchema,
    query: CursorQuerySchema,
  },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Cursor-paginated hydrated change_log feed for an apartment',
      content: { 'application/json': { schema: SyncChangesResponseSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Invalid sync query parameters',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const getMyApartmentsSyncRoute = createRoute({
  method: 'get',
  path: '/me/apartments',
  tags: ['Sync'],
  security: [{ bearerAuth: [] }],
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Active apartments with head change_log sequence and media counters',
      content: { 'application/json': { schema: MyApartmentsSyncResponseSchema } },
    },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Account deleted', content: problemJsonContent },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});
