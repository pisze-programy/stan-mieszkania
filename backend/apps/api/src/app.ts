import { OpenAPIHono } from '@hono/zod-openapi';
import { createJsonLogger, type Logger } from '@stanmieszkania/shared';
import type { AppHonoEnv } from './composition/hono-variables';
import {
  createRequestContainer,
  type RequestContainerOverrides,
} from './composition/request-container';
import { parseAppConfig } from './config/app-config';
import {
  internalServerErrorResponse,
  notFoundErrorResponse,
} from './http/domain-error-to-http.mapper';
import { UNKNOWN_REQUEST_ID } from './http/http.constants';
import { appVersionMiddleware } from './http/middleware/app-version.middleware';
import { firebaseAuthMiddleware } from './http/middleware/firebase-auth.middleware';
import { requestIdMiddleware } from './http/middleware/request-id.middleware';
import { createOpenApiDefaultHook } from './http/openapi-default-hook';
import { createAccountDeletionRoutes } from './modules/account-deletion';
import { createAppConfigRoutes } from './modules/app-config';
import { createApartmentsRoutes } from './modules/apartments';
import { createIdentityRoutes } from './modules/identity';
import { createLocalStorageRoutes, createMediaRoutes } from './modules/media';
import { createMembershipRoutes } from './modules/membership';

export interface CreateAppOptions {
  readonly overrides?: RequestContainerOverrides;
}

function isLoggerLike(value: unknown): value is Pick<Logger, 'error'> {
  return (
    value !== null &&
    typeof value === 'object' &&
    'error' in value &&
    typeof value.error === 'function'
  );
}

function resolveErrorLogger(
  containerValue: unknown,
  requestId: string,
  overrides?: RequestContainerOverrides,
): Pick<Logger, 'error'> {
  if (
    containerValue !== null &&
    typeof containerValue === 'object' &&
    'logger' in containerValue &&
    isLoggerLike(containerValue.logger)
  ) {
    return containerValue.logger;
  }
  if (overrides?.logger !== undefined) {
    return overrides.logger.child({ requestId });
  }
  return createJsonLogger({
    baseContext: { requestId },
    ...(overrides?.clock !== undefined ? { clock: overrides.clock } : {}),
  });
}

export function createApp(options: CreateAppOptions = {}): OpenAPIHono<AppHonoEnv> {
  const app = new OpenAPIHono<AppHonoEnv>({
    defaultHook: createOpenApiDefaultHook<AppHonoEnv>(),
  });

  app.use('*', requestIdMiddleware(options.overrides?.idGenerator));

  app.use('*', async (c, next) => {
    const appConfig = parseAppConfig(c.env);
    const requestId = c.get('requestId');
    const container = createRequestContainer({
      db: c.env.DB,
      ...(c.env.MEDIA_BUCKET !== undefined ? { mediaBucket: c.env.MEDIA_BUCKET } : {}),
      ...(c.env.USER_GUARD !== undefined ? { userGuard: c.env.USER_GUARD } : {}),
      appConfig,
      requestId,
      ...(options.overrides !== undefined ? { overrides: options.overrides } : {}),
    });
    c.set('appConfig', appConfig);
    c.set('logger', container.logger);
    c.set('authenticateToken', (idToken) => container.authenticateUser.execute(idToken));
    c.set('container', container);
    await next();
  });

  app.use('*', appVersionMiddleware());

  app.notFound((c) => {
    const requestIdValue: unknown = c.get('requestId');
    const requestId = typeof requestIdValue === 'string' ? requestIdValue : UNKNOWN_REQUEST_ID;
    return notFoundErrorResponse(c, requestId);
  });

  app.onError((error, c) => {
    const requestIdValue: unknown = c.get('requestId');
    const requestId = typeof requestIdValue === 'string' ? requestIdValue : UNKNOWN_REQUEST_ID;
    const logger = resolveErrorLogger(c.get('container'), requestId, options.overrides);

    logger.error('Unhandled request error', {
      errorName: error.name,
      errorMessage: error.message,
    });

    return internalServerErrorResponse(c, requestId);
  });

  app.route('/v1', createAppConfigRoutes());

  const requireAuth = firebaseAuthMiddleware();
  app.use('/v1/me', requireAuth);
  app.use('/v1/me/*', requireAuth);
  app.use('/v1/apartments', requireAuth);
  app.use('/v1/apartments/*', requireAuth);
  app.route(
    '/v1',
    createIdentityRoutes<AppHonoEnv>((c) => c.get('container').updateDisplayName),
  );
  app.route(
    '/v1',
    createAccountDeletionRoutes<AppHonoEnv>((c) => c.get('container').deleteMyAccount),
  );
  app.route(
    '/v1',
    createLocalStorageRoutes<AppHonoEnv>((c) => c.get('container').localStorage),
  );
  app.route(
    '/v1',
    createMediaRoutes<AppHonoEnv>((c) => c.get('container').media),
  );
  app.route(
    '/v1',
    createMembershipRoutes<AppHonoEnv>((c) => c.get('container').membership),
  );
  app.route(
    '/v1',
    createApartmentsRoutes<AppHonoEnv>((c) => c.get('container').apartments),
  );

  return app;
}
