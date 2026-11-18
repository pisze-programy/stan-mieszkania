import { OpenAPIHono } from '@hono/zod-openapi';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import type { Context } from 'hono';
import { respondDomainError } from '../../../http/domain-error-to-http.mapper';
import type { HttpContextVariables } from '../../../http/http-env';
import { createOpenApiDefaultHook } from '../../../http/openapi-default-hook';
import type { ConfirmMediaUploadUseCase } from '../application/confirm-media-upload.use-case';
import type { GetMediaDownloadUrlUseCase } from '../application/get-media-download-url.use-case';
import type { GetMediaUseCase } from '../application/get-media.use-case';
import type { InitMediaUploadUseCase } from '../application/init-media-upload.use-case';
import type { ListApartmentMediaUseCase } from '../application/list-apartment-media.use-case';
import type { SoftDeleteMediaUseCase } from '../application/soft-delete-media.use-case';
import { requireAuthUser, toMediaDto, toMediaWithAuthorDto } from './media-dto.mapper';
import {
  confirmMediaUploadRoute,
  deleteMediaRoute,
  getMediaDownloadUrlRoute,
  getMediaRoute,
  initMediaUploadRoute,
  listApartmentMediaRoute,
} from './media.route-defs';

export interface MediaRouteHandlers {
  readonly initUpload: InitMediaUploadUseCase;
  readonly confirmUpload: ConfirmMediaUploadUseCase;
  readonly listMedia: ListApartmentMediaUseCase;
  readonly getMedia: GetMediaUseCase;
  readonly getDownloadUrl: GetMediaDownloadUrlUseCase;
  readonly softDelete: SoftDeleteMediaUseCase;
}

export function createMediaRoutes<E extends { Variables: HttpContextVariables }>(
  resolveHandlers: (c: Context<E>) => MediaRouteHandlers,
) {
  const routes = new OpenAPIHono<E>({
    defaultHook: createOpenApiDefaultHook<E>(),
  });

  routes.openapi(initMediaUploadRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;
    const { apartmentId, mediaId } = c.req.valid('param');
    const body = c.req.valid('json');
    const result = await resolveHandlers(c).initUpload.execute({
      apartmentId,
      mediaId,
      userId: auth.user.id,
      kind: body.kind,
      source: body.source,
      sha256: body.sha256,
      capturedAt: body.capturedAt,
      capturedTz: body.capturedTz,
      capturedAtFromImport: body.capturedAtFromImport ?? false,
      width: body.width,
      height: body.height,
      bytes: body.bytes,
      ...(body.lat !== undefined ? { lat: body.lat } : {}),
      ...(body.lng !== undefined ? { lng: body.lng } : {}),
      ...(body.accuracyM !== undefined ? { accuracyM: body.accuracyM } : {}),
      ...(body.locationSource !== undefined ? { locationSource: body.locationSource } : {}),
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.CONFLICT,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
      ]);
    }
    return c.json(
      { media: toMediaDto(result.value.media), upload: result.value.upload },
      HTTP_STATUS.OK,
    );
  });

  routes.openapi(confirmMediaUploadRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;
    const { apartmentId, mediaId } = c.req.valid('param');
    const result = await resolveHandlers(c).confirmUpload.execute({
      apartmentId,
      mediaId,
      userId: auth.user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.CONFLICT,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
      ]);
    }
    return c.json(toMediaDto(result.value), HTTP_STATUS.OK);
  });

  routes.openapi(listApartmentMediaRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;
    const { apartmentId } = c.req.valid('param');
    const query = c.req.valid('query');
    const result = await resolveHandlers(c).listMedia.execute({
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
        items: result.value.items.map(toMediaWithAuthorDto),
        nextCursor: result.value.nextCursor,
        hasMore: result.value.hasMore,
      },
      HTTP_STATUS.OK,
    );
  });

  routes.openapi(getMediaRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;
    const { apartmentId, mediaId } = c.req.valid('param');
    const result = await resolveHandlers(c).getMedia.execute({
      apartmentId,
      mediaId,
      userId: auth.user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
      ]);
    }
    return c.json(toMediaWithAuthorDto(result.value), HTTP_STATUS.OK);
  });

  routes.openapi(getMediaDownloadUrlRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;
    const { apartmentId, mediaId } = c.req.valid('param');
    const result = await resolveHandlers(c).getDownloadUrl.execute({
      apartmentId,
      mediaId,
      userId: auth.user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.CONFLICT,
      ]);
    }
    return c.json(result.value, HTTP_STATUS.OK);
  });

  routes.openapi(deleteMediaRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;
    const { apartmentId, mediaId } = c.req.valid('param');
    const result = await resolveHandlers(c).softDelete.execute({
      apartmentId,
      mediaId,
      userId: auth.user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
      ]);
    }
    return c.json(toMediaDto(result.value), HTTP_STATUS.OK);
  });

  return routes;
}
