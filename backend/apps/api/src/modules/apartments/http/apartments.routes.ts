import { OpenAPIHono } from '@hono/zod-openapi';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { createDomainError } from '@stanmieszkania/shared';
import type { Context } from 'hono';
import { respondDomainError } from '../../../http/domain-error-to-http.mapper';
import { COMMON_ERROR_CODES } from '../../../http/http.constants';
import type { AuthenticatedUser, HttpContextVariables } from '../../../http/http-env';
import { createOpenApiDefaultHook } from '../../../http/openapi-default-hook';
import type { CreateApartmentUseCase } from '../application/create-apartment.use-case';
import type { DeleteOrLeaveApartmentUseCase } from '../application/delete-or-leave-apartment.use-case';
import type { GetApartmentUseCase } from '../application/get-apartment.use-case';
import type { ListApartmentChangesUseCase } from '../application/list-apartment-changes.use-case';
import type { ListMyApartmentsUseCase } from '../application/list-my-apartments.use-case';
import type { ResetInviteCodeUseCase } from '../application/reset-invite-code.use-case';
import type { UpdateApartmentUseCase } from '../application/update-apartment.use-case';
import { shouldSuggestInviteCodeReset } from '../domain/apartment.entity';
import type { ApartmentListEntry } from '../domain/apartment.repository';
import { APARTMENT_ROLES } from '../domain/apartments.constants';
import {
  deleteApartmentRoute,
  getApartmentRoute,
  listApartmentHistoryRoute,
  listApartmentsRoute,
  patchApartmentRoute,
  putApartmentRoute,
  resetInviteCodeRoute,
} from './apartments.route-defs';
import type { ApartmentDto } from './apartments.schema';

export interface ApartmentRouteHandlers {
  readonly createApartment: CreateApartmentUseCase;
  readonly listMyApartments: ListMyApartmentsUseCase;
  readonly getApartment: GetApartmentUseCase;
  readonly updateApartment: UpdateApartmentUseCase;
  readonly resetInviteCode: ResetInviteCodeUseCase;
  readonly deleteOrLeaveApartment: DeleteOrLeaveApartmentUseCase;
  readonly listApartmentChanges: ListApartmentChangesUseCase;
}

function toApartmentDto(entry: ApartmentListEntry): ApartmentDto {
  const isOwner = entry.role === APARTMENT_ROLES.OWNER;
  return {
    id: entry.apartment.id,
    ownerId: entry.apartment.ownerId,
    name: entry.apartment.name,
    street: entry.apartment.street,
    city: entry.apartment.city,
    role: entry.role,
    // Decision Q4/Q8/Q9: Invite code and reset prompt are exposed to owners only.
    inviteCode: isOwner ? entry.apartment.inviteCode : null,
    shouldSuggestInviteCodeReset: isOwner
      ? shouldSuggestInviteCodeReset(
          entry.apartment.inviteCodeRotatedAt,
          entry.latestContributorJoinedAt,
        )
      : false,
    cloudMediaCount: entry.apartment.cloudMediaCount,
    createdAt: entry.apartment.createdAt,
    updatedAt: entry.apartment.updatedAt,
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

export function createApartmentsRoutes<E extends { Variables: HttpContextVariables }>(
  resolveHandlers: (c: Context<E>) => ApartmentRouteHandlers,
) {
  const routes = new OpenAPIHono<E>({
    defaultHook: createOpenApiDefaultHook<E>(),
  });

  routes.openapi(putApartmentRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const body = c.req.valid('json');
    const result = await resolveHandlers(c).createApartment.execute({
      apartmentId,
      ownerId: auth.user.id,
      name: body.name,
      street: body.street,
      city: body.city,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.CONFLICT,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
      ]);
    }
    return c.json(toApartmentDto(result.value), HTTP_STATUS.OK);
  });

  routes.openapi(listApartmentsRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const result = await resolveHandlers(c).listMyApartments.execute(auth.user.id);
    if (!result.ok) return respondDomainError(c, result.error, c.get('requestId'), []);
    return c.json({ items: result.value.map(toApartmentDto) }, HTTP_STATUS.OK);
  });

  routes.openapi(getApartmentRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const result = await resolveHandlers(c).getApartment.execute({
      apartmentId,
      userId: auth.user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
      ]);
    }
    return c.json(toApartmentDto(result.value), HTTP_STATUS.OK);
  });

  routes.openapi(patchApartmentRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const body = c.req.valid('json');
    const result = await resolveHandlers(c).updateApartment.execute({
      apartmentId,
      userId: auth.user.id,
      ...(body.name !== undefined ? { name: body.name } : {}),
      ...(body.street !== undefined ? { street: body.street } : {}),
      ...(body.city !== undefined ? { city: body.city } : {}),
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
      ]);
    }
    return c.json(toApartmentDto(result.value), HTTP_STATUS.OK);
  });

  routes.openapi(resetInviteCodeRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const result = await resolveHandlers(c).resetInviteCode.execute({
      apartmentId,
      userId: auth.user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.CONFLICT,
      ]);
    }
    return c.json(toApartmentDto(result.value), HTTP_STATUS.OK);
  });

  routes.openapi(deleteApartmentRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const result = await resolveHandlers(c).deleteOrLeaveApartment.execute({
      apartmentId,
      userId: auth.user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
      ]);
    }
    return c.body(null, HTTP_STATUS.NO_CONTENT);
  });

  routes.openapi(listApartmentHistoryRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const result = await resolveHandlers(c).listApartmentChanges.execute({
      apartmentId,
      userId: auth.user.id,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
      ]);
    }
    return c.json({ items: [...result.value] }, HTTP_STATUS.OK);
  });

  return routes;
}
