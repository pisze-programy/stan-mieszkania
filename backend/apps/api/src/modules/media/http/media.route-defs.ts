import { createRoute } from '@hono/zod-openapi';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { ApartmentIdParamsSchema } from '../../apartments';
import {
  ApartmentMediaParamsSchema,
  InitMediaUploadRequestSchema,
  InitMediaUploadResponseSchema,
  MediaDtoSchema,
  MediaTimelineQuerySchema,
  MediaTimelineResponseSchema,
  MediaWithAuthorDtoSchema,
  PresignedUrlDtoSchema,
} from './media.schema';

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

export const initMediaUploadRoute = createRoute({
  method: 'post',
  path: '/apartments/{apartmentId}/media/{mediaId}/init',
  tags: ['Media'],
  security: [{ bearerAuth: [] }],
  request: {
    params: ApartmentMediaParamsSchema,
    body: {
      required: true,
      content: { 'application/json': { schema: InitMediaUploadRequestSchema } },
    },
  },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Pending media slot reserved and upload URL issued',
      content: { 'application/json': { schema: InitMediaUploadResponseSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    [HTTP_STATUS.CONFLICT]: {
      description: 'Media ID conflict or deleted',
      content: problemJsonContent,
    },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Quota exceeded, video disabled, or invalid metadata',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const confirmMediaUploadRoute = createRoute({
  method: 'post',
  path: '/apartments/{apartmentId}/media/{mediaId}/confirm',
  tags: ['Media'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentMediaParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Uploaded media checksum verified and confirmed',
      content: { 'application/json': { schema: MediaDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: {
      description: 'Access or author required',
      content: problemJsonContent,
    },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Media not found', content: problemJsonContent },
    [HTTP_STATUS.CONFLICT]: {
      description: 'Object not uploaded or already deleted',
      content: problemJsonContent,
    },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Uploaded SHA-256 or byte size mismatch',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const listApartmentMediaRoute = createRoute({
  method: 'get',
  path: '/apartments/{apartmentId}/media',
  tags: ['Media'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentIdParamsSchema, query: MediaTimelineQuerySchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Cursor-paginated media timeline for apartment',
      content: { 'application/json': { schema: MediaTimelineResponseSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Invalid pagination cursor',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const getMediaRoute = createRoute({
  method: 'get',
  path: '/apartments/{apartmentId}/media/{mediaId}',
  tags: ['Media'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentMediaParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Media details with author summary',
      content: { 'application/json': { schema: MediaWithAuthorDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Media not found', content: problemJsonContent },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const getMediaDownloadUrlRoute = createRoute({
  method: 'get',
  path: '/apartments/{apartmentId}/media/{mediaId}/download-url',
  tags: ['Media'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentMediaParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Short-lived signed download URL',
      content: { 'application/json': { schema: PresignedUrlDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Media not found', content: problemJsonContent },
    [HTTP_STATUS.CONFLICT]: {
      description: 'Media pending upload or soft-deleted',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const deleteMediaRoute = createRoute({
  method: 'delete',
  path: '/apartments/{apartmentId}/media/{mediaId}',
  tags: ['Media'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentMediaParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Soft-deleted media tombstone',
      content: { 'application/json': { schema: MediaDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Author required', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Media not found', content: problemJsonContent },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});
