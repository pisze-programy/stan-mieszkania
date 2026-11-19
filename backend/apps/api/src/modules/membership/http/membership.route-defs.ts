import { createRoute } from '@hono/zod-openapi';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { ApartmentDtoSchema, ApartmentIdParamsSchema } from '../../apartments';
import {
  ApartmentMemberListResponseSchema,
  JoinApartmentRequestSchema,
  RevokeMemberParamsSchema,
} from './membership.schema';

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

export const joinApartmentRoute = createRoute({
  operationId: 'joinApartmentByCode',
  method: 'post',
  path: '/apartments/join',
  tags: ['Membership'],
  security: [{ bearerAuth: [] }],
  request: {
    body: {
      required: true,
      content: { 'application/json': { schema: JoinApartmentRequestSchema } },
    },
  },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Joined apartment as contributor (or idempotently replayed active membership)',
      content: { 'application/json': { schema: ApartmentDtoSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: {
      description: 'Revoked contributor cannot re-join until invite code is rotated',
      content: problemJsonContent,
    },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Invite code not found', content: problemJsonContent },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Invalid invite code format',
      content: problemJsonContent,
    },
    [HTTP_STATUS.TOO_MANY_REQUESTS]: {
      description: 'Invite code join rate limit exceeded',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const listApartmentMembersRoute = createRoute({
  operationId: 'listApartmentMembers',
  method: 'get',
  path: '/apartments/{apartmentId}/members',
  tags: ['Membership'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentIdParamsSchema },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Members of the apartment',
      content: { 'application/json': { schema: ApartmentMemberListResponseSchema } },
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const revokeMemberRoute = createRoute({
  operationId: 'revokeApartmentMember',
  method: 'delete',
  path: '/apartments/{apartmentId}/members/{userId}',
  tags: ['Membership'],
  security: [{ bearerAuth: [] }],
  request: { params: RevokeMemberParamsSchema },
  responses: {
    [HTTP_STATUS.NO_CONTENT]: { description: 'Contributor access revoked' },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Owner required', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: {
      description: 'Apartment or active membership not found',
      content: problemJsonContent,
    },
    [HTTP_STATUS.CONFLICT]: {
      description: 'Cannot revoke apartment owner',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});

export const leaveApartmentRoute = createRoute({
  operationId: 'leaveApartment',
  method: 'post',
  path: '/apartments/{apartmentId}/leave',
  tags: ['Membership'],
  security: [{ bearerAuth: [] }],
  request: { params: ApartmentIdParamsSchema },
  responses: {
    [HTTP_STATUS.NO_CONTENT]: {
      description: 'Contributor left apartment (owners use DELETE /apartments/{apartmentId})',
    },
    [HTTP_STATUS.BAD_REQUEST]: { description: 'Validation error', content: problemJsonContent },
    [HTTP_STATUS.FORBIDDEN]: { description: 'Access denied', content: problemJsonContent },
    [HTTP_STATUS.NOT_FOUND]: { description: 'Apartment not found', content: problemJsonContent },
    [HTTP_STATUS.CONFLICT]: {
      description: 'Owner cannot leave directly without transfer/delete',
      content: problemJsonContent,
    },
    ...COMMON_AUTH_AND_SERVER_ERRORS,
  },
});
