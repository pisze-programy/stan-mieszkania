import { z } from '@hono/zod-openapi';
import { IsoDateTimeSchema, UuidV7Schema } from '@stanmieszkania/http-contracts';
import { ApartmentRoleSchema } from '../../apartments';
import {
  JOIN_REQUEST_INVITE_CODE_MAX_LENGTH,
  JOIN_REQUEST_INVITE_CODE_MIN_LENGTH,
} from '../domain/membership.constants';

export const JoinApartmentRequestSchema = z
  .object({
    inviteCode: z
      .string()
      .min(JOIN_REQUEST_INVITE_CODE_MIN_LENGTH)
      .max(JOIN_REQUEST_INVITE_CODE_MAX_LENGTH),
  })
  .openapi('JoinApartmentRequest');

export const RevokeMemberParamsSchema = z
  .object({
    apartmentId: UuidV7Schema,
    userId: UuidV7Schema,
  })
  .openapi('RevokeMemberParams');

export const ApartmentMemberDtoSchema = z
  .object({
    userId: UuidV7Schema,
    displayName: z.string(),
    shortTag: z.string(),
    color: z.string(),
    role: ApartmentRoleSchema,
    joinedAt: IsoDateTimeSchema,
    leftAt: IsoDateTimeSchema.nullable(),
  })
  .openapi('ApartmentMember');

export const ApartmentMemberListResponseSchema = z
  .object({
    items: z.array(ApartmentMemberDtoSchema),
  })
  .openapi('ApartmentMemberListResponse');

export type ApartmentMemberDto = z.infer<typeof ApartmentMemberDtoSchema>;
