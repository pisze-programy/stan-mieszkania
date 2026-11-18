import { OpenAPIHono, createRoute } from '@hono/zod-openapi';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import type { Context } from 'hono';
import { respondDomainError } from '../../../http/domain-error-to-http.mapper';
import type { AuthenticatedUser, HttpContextVariables } from '../../../http/http-env';
import { createOpenApiDefaultHook } from '../../../http/openapi-default-hook';
import { authTokenMissingError } from '../../identity';
import type { DeleteMyAccountUseCase } from '../application/delete-my-account.use-case';
import { DeleteAccountRequestSchema } from './account-deletion.schema';

const problemJsonContent = {
  'application/problem+json': {
    schema: ProblemDetailsSchema,
  },
} as const;

export const deleteMeRoute = createRoute({
  method: 'delete',
  path: '/me',
  tags: ['AccountDeletion'],
  security: [{ bearerAuth: [] }],
  request: {
    body: {
      required: false,
      content: {
        'application/json': {
          schema: DeleteAccountRequestSchema,
        },
      },
    },
  },
  responses: {
    [HTTP_STATUS.NO_CONTENT]: {
      description: 'Account deleted, private data purged, and shared contributions anonymized',
    },
    [HTTP_STATUS.BAD_REQUEST]: {
      description: 'Invalid request payload',
      content: problemJsonContent,
    },
    [HTTP_STATUS.UNAUTHORIZED]: {
      description: 'Missing or invalid bearer token',
      content: problemJsonContent,
    },
    [HTTP_STATUS.FORBIDDEN]: {
      description: 'Account has already been deleted',
      content: problemJsonContent,
    },
    [HTTP_STATUS.UNPROCESSABLE_ENTITY]: {
      description: 'Invalid Apple authorization code',
      content: problemJsonContent,
    },
    [HTTP_STATUS.BAD_GATEWAY]: {
      description: 'External auth cleanup failed',
      content: problemJsonContent,
    },
    [HTTP_STATUS.INTERNAL_SERVER_ERROR]: {
      description: 'Unexpected internal error',
      content: problemJsonContent,
    },
  },
});

export function createAccountDeletionRoutes<E extends { Variables: HttpContextVariables }>(
  resolveDeleteMyAccount: (c: Context<E>) => DeleteMyAccountUseCase,
) {
  const routes = new OpenAPIHono<E>({
    defaultHook: createOpenApiDefaultHook<E>(),
  });

  routes.openapi(deleteMeRoute, async (c) => {
    const user: AuthenticatedUser | undefined = c.get('authenticatedUser');
    if (user === undefined) {
      return respondDomainError(c, authTokenMissingError(), c.get('requestId'), [
        HTTP_STATUS.UNAUTHORIZED,
      ]);
    }

    const rawBody: unknown = c.req.valid('json');
    const parsedBody =
      rawBody !== undefined ? DeleteAccountRequestSchema.safeParse(rawBody) : undefined;
    const appleAuthorizationCode =
      parsedBody !== undefined && parsedBody.success
        ? parsedBody.data.appleAuthorizationCode
        : undefined;
    const useCase = resolveDeleteMyAccount(c);
    const result = await useCase.execute({
      userId: user.id,
      firebaseUid: user.firebaseUid,
      ...(appleAuthorizationCode !== undefined ? { appleAuthorizationCode } : {}),
    });

    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
        HTTP_STATUS.BAD_GATEWAY,
      ]);
    }

    return c.body(null, HTTP_STATUS.NO_CONTENT);
  });

  return routes;
}
