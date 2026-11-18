import { createDomainError } from '@stanmieszkania/shared';
import { createMiddleware } from 'hono/factory';
import { mapDomainErrorToHttp } from '../domain-error-to-http.mapper';
import {
  AUTHORIZATION_HEADER_NAME,
  BEARER_AUTH_PREFIX,
  COMMON_ERROR_CODES,
} from '../http.constants';
import type { AuthenticateTokenFn, HttpContextVariables } from '../http-env';
import { problemDetailsResponse } from '../problem-details';

function extractBearerToken(authorizationHeader: string | undefined): string | null {
  if (authorizationHeader === undefined) {
    return null;
  }

  const trimmed = authorizationHeader.trim();
  if (!trimmed.toLowerCase().startsWith(BEARER_AUTH_PREFIX.toLowerCase())) {
    return null;
  }

  const token = trimmed.slice(BEARER_AUTH_PREFIX.length).trim();
  return token.length > 0 ? token : null;
}

export function firebaseAuthMiddleware(explicitAuthenticate?: AuthenticateTokenFn) {
  return createMiddleware<{ Variables: HttpContextVariables }>(async (c, next) => {
    const token = extractBearerToken(c.req.header(AUTHORIZATION_HEADER_NAME));
    if (token === null) {
      const mapped = mapDomainErrorToHttp(
        createDomainError(
          COMMON_ERROR_CODES.AUTH_TOKEN_MISSING,
          'Authorization bearer token is missing',
        ),
        c.get('requestId'),
      );
      return problemDetailsResponse(c, mapped.status, mapped.problem);
    }

    const authenticate = explicitAuthenticate ?? c.get('authenticateToken');
    if (authenticate === undefined) {
      throw new Error('Authentication handler is not registered in request context');
    }

    const authenticated = await authenticate(token);
    if (!authenticated.ok) {
      const mapped = mapDomainErrorToHttp(authenticated.error, c.get('requestId'));
      return problemDetailsResponse(c, mapped.status, mapped.problem);
    }

    c.set('authenticatedUser', authenticated.value);
    c.set('logger', c.get('logger').child({ userId: authenticated.value.id }));
    await next();
    return;
  });
}
