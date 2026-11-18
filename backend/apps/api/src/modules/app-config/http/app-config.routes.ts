import { OpenAPIHono, createRoute } from '@hono/zod-openapi';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import type { HttpContextVariables } from '../../../http/http-env';
import { createOpenApiDefaultHook } from '../../../http/openapi-default-hook';
import { createGetPublicAppConfigUseCase } from '../application/get-public-app-config.use-case';
import { PublicAppConfigSchema } from './app-config.schema';

export const getAppConfigRoute = createRoute({
  method: 'get',
  path: '/config',
  tags: ['Config'],
  responses: {
    [HTTP_STATUS.OK]: {
      description: 'Public client configuration',
      content: {
        'application/json': {
          schema: PublicAppConfigSchema,
        },
      },
    },
  },
});

export function createAppConfigRoutes() {
  const routes = new OpenAPIHono<{ Variables: HttpContextVariables }>({
    defaultHook: createOpenApiDefaultHook<{ Variables: HttpContextVariables }>(),
  });

  routes.openapi(getAppConfigRoute, (c) => {
    const useCase = createGetPublicAppConfigUseCase(c.get('appConfig'));
    return c.json(useCase.execute(), HTTP_STATUS.OK);
  });

  return routes;
}
