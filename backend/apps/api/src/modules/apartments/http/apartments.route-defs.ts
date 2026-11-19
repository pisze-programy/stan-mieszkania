import { createRoute } from '@hono/zod-openapi';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import {
  ApartmentDtoSchema,
  ApartmentHistoryResponseSchema,
  ApartmentIdParamsSchema,
  ApartmentListResponseSchema,
  UpdateApartmentRequestSchema,
  UpsertApartmentRequestSchema,
} from './apartments.schema';

const problemJsonContent = {
  'application/problem+json': {
    schema: ProblemDetailsSchema,
  },
} as const;

const COMMON_AUTH_AND_SERVER_ERRORS = {
  [HTTP_STATUS.UNAUTHORIZED]: { description: 'Unauthorized', content: problemJsonContent },
  [HTTP_STATUS.INTERNAL_SERVER_ERROR]: {
    description: 'Unexpected internal error',
    content: problemJsonContent,
  },
} as const;

export const putApartmentRoute = createRoute({
  operationId: 'putApartment',
  method: 'put',
  path: '/apartments/{apartmentId}',
  tags: ['Apartments'],
  security: [{ bearerAuth: [] }],
  request: {
    params: ApartmentIdParamsSchema,
    body: {
      required: true,
      content: { 'application/json': { schema: UpsertApartmentRequestSchema } },
    },
  },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Created or idempotently replayed apartment',
      content: { 'application/json': { schema: ApartmentDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.CONFLICT]: { description: 'Invite code collision', content: problemJsonContent },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Invalid apartment fields',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const listApartmentsRoute = createRoute({
  operationId: 'listApartments',
  method: 'get',
  path: '/apartments',
  tags: ['Apartments'],
  security: [{ bearerAuth: [] }],
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Active apartments for current user',
      content: { 'application/json': { schema: ApartmentListResponseSchema } },
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const getApartmentRoute = createRoute({
  operationId: 'getApartment',
  method: 'get',
  path: '/apartments/{apartmentId}',
  tags: ['Apartments'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentIdParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Apartment details',
      content: { 'application/json': { schema: ApartmentDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const patchApartmentRoute = createRoute({
  operationId: 'updateApartment',
  method: 'patch',
  path: '/apartments/{apartmentId}',
  tags: ['Apartments'],
  security: [{ bearerAuth: [] }],
  request: {
    params: ApartmentIdParamsSchema,
    body: {
      required: true,
      content: { 'application/json': { schema: UpdateApartmentRequestSchema } },
    },
  },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Updated apartment details',
      content: { 'application/json': { schema: ApartmentDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Owner required', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Invalid apartment fields',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const resetInviteCodeRoute = createRoute({
  operationId: 'resetApartmentInviteCode',
  method: 'post',
  path: '/apartments/{apartmentId}/invite-code/reset',
  tags: ['Apartments'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentIdParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Apartment with regenerated invite code',
      content: { 'application/json': { schema: ApartmentDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Owner required', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    [HTTP_STATUS.CONFLICT]: { description: 'Invite code collision', content: problemJsonContent },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const deleteApartmentRoute = createRoute({
  operationId: 'deleteOrLeaveApartment',
  method: 'delete',
  path: '/apartments/{apartmentId}',
  tags: ['Apartments'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentIdParamsSchema },
  responses: {
    [HTTP_STATUS.NO_CONTENT]: { description: 'Apartment left, transferred, or deleted' },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const listApartmentHistoryRoute = createRoute({
  operationId: 'listApartmentHistory',
  method: 'get',
  path: '/apartments/{apartmentId}/history',
  tags: ['Apartments'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentIdParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Apartment metadata change history',
      content: { 'application/json': { schema: ApartmentHistoryResponseSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});
