import type { ExecutionContext } from '@cloudflare/workers-types';
import { createApp } from './app';
import type { AppBindings } from './composition/hono-variables';

export { ApartmentCoordinator } from './durable-objects/apartment-coordinator.durable-object';
export { UserGuard } from './durable-objects/user-guard.durable-object';

const app = createApp();

export default {
  fetch: (
    request: Request,
    env: AppBindings,
    ctx: ExecutionContext,
  ): Response | Promise<Response> => app.fetch(request, env, ctx),
};
