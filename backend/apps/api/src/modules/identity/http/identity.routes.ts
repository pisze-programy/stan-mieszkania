import { OpenAPIHono, createRoute } from '@hono/zod-openapi';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import type { Context } from 'hono';
import { respondDomainError } from '../../../http/domain-error-to-http.mapper';
import type { AuthenticatedUser, HttpContextVariables } from '../../../http/http-env';
import { createOpenApiDefaultHook } from '../../../http/openapi-default-hook';
import type { UpdateDisplayNameUseCase } from '../application/update-display-name.use-case';
import { authTokenMissingError } from '../domain/identity.errors';
import {
  UpdateProfileRequestSchema,
  UserProfileSchema,
  type UserProfileDto,
} from './identity.schema';

export const getMeRoute = createRoute({
  method: 'get',
  path: '/me',
  tags: ['Identity'],
  security: [{ bearerAuth: [] }],
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Authenticated user profile',
      content: {
        'application/json': {
          schema: UserProfileSchema,
        },
      },
    },
    [HTTP_STATUS.UNAUTHORIZED]: {
      description: 'Missing or invalid bearer token',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
    [HTTP_STATUS.FORBIDDEN]: {
      description: 'Account has been deleted',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
    [HTTP_STATUS.INTERNAL_SERVER_ERROR]: {
      description: 'Unexpected internal error',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
  },
});

export const patchMeRoute = createRoute({
  method: 'patch',
  path: '/me',
  tags: ['Identity'],
  security: [{ bearerAuth: [] }],
  request: {
    body: {
      required: true,
      content: {
        'application/json': {
          schema: UpdateProfileRequestSchema,
        },
      },
    },
  },
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Updated user profile',
      content: {
        'application/json': {
          schema: UserProfileSchema,
        },
      },
    },
    [HTTP_STATUS.BAD_REQUEST]: {
      description: 'Invalid request payload',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
    [HTTP_STATUS.UNAUTHORIZED]: {
      description: 'Missing or invalid bearer token',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
    [HTTP_STATUS.FORBIDDEN]: {
      description: 'Account has been deleted',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
    [HTTP_STATUS.NOT_FOUND]: {
      description: 'User not found',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Invalid display name',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
    [HTTP_STATUS.INTERNAL_SERVER_ERROR]: {
      description: 'Unexpected internal error',
      content: {
        'application/problem+json': {
          schema: ProblemDetailsSchema,
        },
      },
    },
  },
});

function toUserProfileDto(user: AuthenticatedUser): UserProfileDto {
  return {
    id: user.id,
    displayName: user.displayName,
    shortTag: user.shortTag,
    color: user.color,
    createdAt: user.createdAt,
  };
}

export function createIdentityRoutes<E extends { Variables: HttpContextVariables }>(
  resolveUpdateDisplayName: (c: Context<E>) => UpdateDisplayNameUseCase,
) {
  const routes = new OpenAPIHono<E>({
    defaultHook: createOpenApiDefaultHook<E>(),
  });

  routes.openapi(getMeRoute, (c) => {
    const user: AuthenticatedUser | undefined = c.get('authenticatedUser');
    if (user === undefined) {
      return respondDomainError(c, authTokenMissingError(), c.get('requestId'), [
        HTTP_STATUS.UNAUTHORIZED,
        HTTP_STATUS.FORBIDDEN,
      ]);
    }
    return c.json(toUserProfileDto(user), HTTP_STATUS.OK);
  });

  routes.openapi(patchMeRoute, async (c) => {
    const user: AuthenticatedUser | undefined = c.get('authenticatedUser');
    if (user === undefined) {
      return respondDomainError(c, authTokenMissingError(), c.get('requestId'), [
        HTTP_STATUS.UNAUTHORIZED,
      ]);
    }

    const body = c.req.valid('json');
    const useCase = resolveUpdateDisplayName(c);
    const updated = await useCase.execute({
      userId: user.id,
      displayName: body.displayName,
    });

    if (!updated.ok) {
      return respondDomainError(c, updated.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
      ]);
    }

    return c.json(toUserProfileDto(updated.value), HTTP_STATUS.OK);
  });

  return routes;
}
