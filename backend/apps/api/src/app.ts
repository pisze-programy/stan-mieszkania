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
import { requestIdMiddleware } from './http/middleware/request-id.middleware';
import { createOpenApiDefaultHook } from './http/openapi-default-hook';
import { createAppConfigRoutes } from './modules/app-config';

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
      appConfig,
      requestId,
      ...(options.overrides !== undefined ? { overrides: options.overrides } : {}),
    });
    c.set('appConfig', appConfig);
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

  return app;
}
