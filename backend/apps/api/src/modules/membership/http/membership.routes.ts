import { OpenAPIHono } from '@hono/zod-openapi';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { createDomainError } from '@stanmieszkania/shared';
import type { Context } from 'hono';
import { respondDomainError } from '../../../http/domain-error-to-http.mapper';
import { COMMON_ERROR_CODES } from '../../../http/http.constants';
import type { AuthenticatedUser, HttpContextVariables } from '../../../http/http-env';
import { createOpenApiDefaultHook } from '../../../http/openapi-default-hook';
import { shouldSuggestInviteCodeReset, type ApartmentDto } from '../../apartments';
import type { JoinApartmentByCodeUseCase } from '../application/join-apartment-by-code.use-case';
import type { LeaveApartmentUseCase } from '../application/leave-apartment.use-case';
import type { ListApartmentMembersUseCase } from '../application/list-apartment-members.use-case';
import type { RevokeMemberAccessUseCase } from '../application/revoke-member-access.use-case';
import { MEMBERSHIP_ROLES } from '../domain/membership.constants';
import type { JoinApartmentSummary } from '../domain/membership.repository';
import {
  joinApartmentRoute,
  leaveApartmentRoute,
  listApartmentMembersRoute,
  revokeMemberRoute,
} from './membership.route-defs';

export interface MembershipRouteHandlers {
  readonly joinApartment: JoinApartmentByCodeUseCase;
  readonly listMembers: ListApartmentMembersUseCase;
  readonly revokeMember: RevokeMemberAccessUseCase;
  readonly leaveApartment: LeaveApartmentUseCase;
}

function toJoinedApartmentDto(summary: JoinApartmentSummary): ApartmentDto {
  const isOwner = summary.role === MEMBERSHIP_ROLES.OWNER;
  return {
    id: summary.apartment.id,
    ownerId: summary.apartment.ownerId,
    name: summary.apartment.name,
    street: summary.apartment.street,
    city: summary.apartment.city,
    role: summary.role,
    inviteCode: isOwner ? summary.apartment.inviteCode : null,
    shouldSuggestInviteCodeReset: isOwner
      ? shouldSuggestInviteCodeReset(
          summary.apartment.inviteCodeRotatedAt,
          summary.latestContributorJoinedAt,
        )
      : false,
    cloudMediaCount: summary.apartment.cloudMediaCount,
    createdAt: summary.apartment.createdAt,
    updatedAt: summary.apartment.updatedAt,
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

export function createMembershipRoutes<E extends { Variables: HttpContextVariables }>(
  resolveHandlers: (c: Context<E>) => MembershipRouteHandlers,
) {
  const routes = new OpenAPIHono<E>({
    defaultHook: createOpenApiDefaultHook<E>(),
  });

  routes.openapi(joinApartmentRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const body = c.req.valid('json');
    const result = await resolveHandlers(c).joinApartment.execute({
      userId: auth.user.id,
      inviteCode: body.inviteCode,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.UNPROCESSABLE_ENTITY,
        HTTP_STATUS.TOO_MANY_REQUESTS,
      ]);
    }
    return c.json(toJoinedApartmentDto(result.value), HTTP_STATUS.OK);
  });

  routes.openapi(listApartmentMembersRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const result = await resolveHandlers(c).listMembers.execute({
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

  routes.openapi(revokeMemberRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId, userId } = c.req.valid('param');
    const result = await resolveHandlers(c).revokeMember.execute({
      apartmentId,
      actorUserId: auth.user.id,
      targetUserId: userId,
    });
    if (!result.ok) {
      return respondDomainError(c, result.error, c.get('requestId'), [
        HTTP_STATUS.FORBIDDEN,
        HTTP_STATUS.NOT_FOUND,
        HTTP_STATUS.CONFLICT,
      ]);
    }
    return c.body(null, HTTP_STATUS.NO_CONTENT);
  });

  routes.openapi(leaveApartmentRoute, async (c) => {
    const auth = requireAuthUser(c, c.get('authenticatedUser'), c.get('requestId'));
    if (!auth.ok) return auth.response;

    const { apartmentId } = c.req.valid('param');
    const result = await resolveHandlers(c).leaveApartment.execute({
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
    return c.body(null, HTTP_STATUS.NO_CONTENT);
  });

  return routes;
}
