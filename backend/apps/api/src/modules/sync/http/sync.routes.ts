import { OpenAPIHono } from '@hono/zod-openapi';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { createDomainError } from '@stanmieszkania/shared';
import type { Context } from 'hono';
import { respondDomainError } from '../../../http/domain-error-to-http.mapper';
import { COMMON_ERROR_CODES } from '../../../http/http.constants';
import type { AuthenticatedUser, HttpContextVariables } from '../../../http/http-env';
import { createOpenApiDefaultHook } from '../../../http/openapi-default-hook';
import type { ListApartmentChangesFeedUseCase } from '../application/list-apartment-changes-feed.use-case';
import type { ListMyApartmentsSyncUseCase } from '../application/list-my-apartments-sync.use-case';
import type { HydratedSyncChange } from '../domain/sync.entity';
import { getApartmentChangesRoute, getMyApartmentsSyncRoute } from './sync.route-defs';
import type { SyncChangesResponseDto } from './sync.schema';

export interface SyncRouteHandlers {
  readonly listApartmentChanges: ListApartmentChangesFeedUseCase;
  readonly listMyApartmentsSync: ListMyApartmentsSyncUseCase;
}

function toHydratedChangeDto(
  change: HydratedSyncChange,
): SyncChangesResponseDto['changes'][number] {
  if (change.payload === null || change.payload.kind !== 'entry') {
    return {
      ...change,
      payload: change.payload,
    };
  }
  return {
    ...change,
    payload: {
      kind: 'entry',
      entry: {
        ...change.payload.entry,
        markers: [...change.payload.entry.markers],
      },
    },
  };
}

function requireAuthUser(c: Context, user: AuthenticatedUser | undefined, requestId: string) {
  if (user !== undefined) {
    return { ok: true as const, user };
  }
  return {
    ok: false as const,
    response: respondDomainError(
      c,
      createDomainError(
        COMMON_ERROR_CODES.AUTH_TOKEN_MISSING,
        'Authorization bearer token is missing',
      ),
      requestId,
      [HTTP_STATUS.UNAUTHORIZED],
    ),
  };
}

export function createSyncRoutes<E extends { Variables: HttpContextVariables }>(
  resolveHandlers: (c: Context<E>) => SyncRouteHandlers,
) {
  const routes = new OpenAPIHono<E>({
    defaultHook: createOpenApiDefaultHook<E>(),
  });

  routes.openapi(getApartmentChangesRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const query = c.req.valid('query');
    const result = await resolveHandlers(c).listApartmentChanges.execute({
      apartmentId,
      userId: auth.user.id,
      ...(query.after !== undefined ? { after: query.after } : {}),
      ...(query.limit !== undefined ? { limit: query.limit } : {}),
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
      ]);
    }
    return c.json(
      {
        changes: result.value.changes.map(toHydratedChangeDto),
        nextSeq: result.value.nextSeq,
        hasMore: result.value.hasMore,
      },
      HTTP_STATUS.OK,
    );
  });

  routes.openapi(getMyApartmentsSyncRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const result = await resolveHandlers(c).listMyApartmentsSync.execute(auth.user.id);
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), []);
    }
    return c.json({ items: [...result.value] }, HTTP_STATUS.OK);
  });

  return routes;
}
