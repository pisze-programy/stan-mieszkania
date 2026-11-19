import { OpenAPIHono } from '@hono/zod-openapi';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import type { Context } from 'hono';
import { respondDomainError } from '../../../http/domain-error-to-http.mapper';
import type { AuthenticatedUser, HttpContextVariables } from '../../../http/http-env';
import { createOpenApiDefaultHook } from '../../../http/openapi-default-hook';
import { authTokenMissingError } from '../../identity';
import type { CreateEntryUseCase } from '../application/create-entry.use-case';
import type { ListMediaEntriesUseCase } from '../application/list-media-entries.use-case';
import type { RetractEntryUseCase } from '../application/retract-entry.use-case';
import type { EntryWithAuthor } from '../domain/entry.repository';
import { deleteEntryRoute, listEntriesRoute, putEntryRoute } from './entries.route-defs';
import type { EntryDto } from './entries.schema';

export interface EntriesRouteHandlers {
  readonly createEntry: CreateEntryUseCase;
  readonly listEntries: ListMediaEntriesUseCase;
  readonly retractEntry: RetractEntryUseCase;
}

function toEntryDto(item: EntryWithAuthor): EntryDto {
  return {
    id: item.entry.id,
    mediaId: item.entry.mediaId,
    authorId: item.entry.authorId,
    author: {
      userId: item.author.userId,
      displayName: item.author.displayName,
      shortTag: item.author.shortTag,
      color: item.author.color,
      role: item.author.role,
    },
    text: item.entry.text,
    markers: item.entry.markers.map((marker) => ({
      id: marker.id,
      entryId: marker.entryId,
      mediaId: marker.mediaId,
      number: marker.number,
      x: marker.x,
      y: marker.y,
    })),
    createdAt: item.entry.createdAt,
    serverReceivedAt: item.entry.serverReceivedAt,
    retractedAt: item.entry.retractedAt,
  };
}

export function createEntriesRoutes<E extends { Variables: HttpContextVariables }>(
  resolveHandlers: (c: Context<E>) => EntriesRouteHandlers,
) {
  const routes = new OpenAPIHono<E>({
    defaultHook: createOpenApiDefaultHook<E>(),
  });

  routes.openapi(putEntryRoute, async (c) => {
    const user: AuthenticatedUser | undefined = c.get('authenticatedUser');
    if (user === undefined) {
      return respondDomainError(c, authTokenMissingError(), c.get('requestId'), [
        HTTP_STATUS.UNAUTHORIZED,
      ]);
    }
    const { apartmentId, mediaId, entryId } = c.req.valid('param');
    const body = c.req.valid('json');
    const result = await resolveHandlers(c).createEntry.execute({
      apartmentId,
      mediaId,
      entryId,
      actorUserId: user.id,
      text: body.text,
      draftMarkers: body.markers,
      createdAt: body.createdAt,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.CONFLICT,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
      ]);
    }
    return c.json(toEntryDto(result.value), HTTP_STATUS.OK);
  });

  routes.openapi(listEntriesRoute, async (c) => {
    const user: AuthenticatedUser | undefined = c.get('authenticatedUser');
    if (user === undefined) {
      return respondDomainError(c, authTokenMissingError(), c.get('requestId'), [
        HTTP_STATUS.UNAUTHORIZED,
      ]);
    }
    const { apartmentId, mediaId } = c.req.valid('param');
    const result = await resolveHandlers(c).listEntries.execute({
      apartmentId,
      mediaId,
      actorUserId: user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
      ]);
    }
    return c.json({ items: result.value.map(toEntryDto) }, HTTP_STATUS.OK);
  });

  routes.openapi(deleteEntryRoute, async (c) => {
    const user: AuthenticatedUser | undefined = c.get('authenticatedUser');
    if (user === undefined) {
      return respondDomainError(c, authTokenMissingError(), c.get('requestId'), [
        HTTP_STATUS.UNAUTHORIZED,
      ]);
    }
    const { apartmentId, mediaId, entryId } = c.req.valid('param');
    const result = await resolveHandlers(c).retractEntry.execute({
      apartmentId,
      mediaId,
      entryId,
      actorUserId: user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
      ]);
    }
    return c.json(toEntryDto(result.value), HTTP_STATUS.OK);
  });

  return routes;
}
