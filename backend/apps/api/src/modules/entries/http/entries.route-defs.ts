import { createRoute } from '@hono/zod-openapi';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import {
  CreateEntryRequestSchema,
  EntryDtoSchema,
  EntryListResponseSchema,
  EntryPathParamsSchema,
  MediaEntriesPathParamsSchema,
} from './entries.schema';

const problemJsonContent = {
  'application/problem+json': {
    schema: ProblemDetailsSchema,
  },
} as const;

const COMMON_ERRORS = {
  [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
  [HTTP_STATUS.UNAUTHORIZED]: { description: 'Unauthorized', content: problemJsonContent },
  [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
  [HTTP_STATUS.NOT_FOUND]: { description: 'Not found', content: problemJsonContent },
  [HTTP_STATUS.INTERNAL_SERVER_ERROR]: {
    description: 'Unexpected internal error',
    content: problemJsonContent,
  },
} as const;

export const putEntryRoute = createRoute({
  method: 'put',
  path: '/apartments/{apartmentId}/media/{mediaId}/entries/{entryId}',
  tags: ['Entries'],
  security: [{ bearerAuth: [] }],
  request: {
    params: EntryPathParamsSchema,
    body: {
      required: true,
      content: { 'application/json': { schema: CreateEntryRequestSchema } },
    },
  },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Created or idempotently replayed verified entry with server marker numbers',
      content: { 'application/json': { schema: EntryDtoSchema } },
    },
    [HTTP_STATUS.CONFLICT]: {
      description: 'Entry conflict or target media not ready',
      content: problemJsonContent,
    },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Invalid entry or marker data',
      content: problemJsonContent,
    },
    ...COMMON_ERRORS,
  },
});

export const listEntriesRoute = createRoute({
  method: 'get',
  path: '/apartments/{apartmentId}/media/{mediaId}/entries',
  tags: ['Entries'],
  security: [{ bearerAuth: [] }],
  request: { params: MediaEntriesPathParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Ordered timeline entries for a media item',
      content: { 'application/json': { schema: EntryListResponseSchema } },
    },
    ...COMMON_ERRORS,
  },
});

export const deleteEntryRoute = createRoute({
  method: 'delete',
  path: '/apartments/{apartmentId}/media/{mediaId}/entries/{entryId}',
  tags: ['Entries'],
  security: [{ bearerAuth: [] }],
  request: { params: EntryPathParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Retracted entry tombstone with redacted text and empty markers',
      content: { 'application/json': { schema: EntryDtoSchema } },
    },
    ...COMMON_ERRORS,
  },
});
