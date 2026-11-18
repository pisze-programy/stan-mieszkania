import { z } from '@hono/zod-openapi';
import { IsoDateTimeSchema, UuidV7Schema } from '@stanmieszkania/http-contracts';
import {
  APARTMENT_CHANGE_FIELDS,
  APARTMENT_CITY_MAX_LENGTH,
  APARTMENT_CITY_MIN_LENGTH,
  APARTMENT_NAME_MAX_LENGTH,
  APARTMENT_NAME_MIN_LENGTH,
  APARTMENT_ROLES,
  APARTMENT_STREET_MAX_LENGTH,
  APARTMENT_STREET_MIN_LENGTH,
  INITIAL_CLOUD_MEDIA_COUNT,
} from '../domain/apartments.constants';

export const ApartmentRoleSchema = z
  .enum([APARTMENT_ROLES.OWNER, APARTMENT_ROLES.CONTRIBUTOR])
  .openapi('ApartmentRole');

export const ApartmentIdParamsSchema = z
  .object({
    apartmentId: UuidV7Schema,
  })
  .openapi('ApartmentIdParams');

export const UpsertApartmentRequestSchema = z
  .object({
    name: z.string().min(APARTMENT_NAME_MIN_LENGTH).max(APARTMENT_NAME_MAX_LENGTH),
    street: z.string().min(APARTMENT_STREET_MIN_LENGTH).max(APARTMENT_STREET_MAX_LENGTH),
    city: z.string().min(APARTMENT_CITY_MIN_LENGTH).max(APARTMENT_CITY_MAX_LENGTH),
  })
  .openapi('UpsertApartmentRequest');

export const UpdateApartmentRequestSchema = z
  .object({
    name: z.string().min(APARTMENT_NAME_MIN_LENGTH).max(APARTMENT_NAME_MAX_LENGTH).optional(),
    street: z.string().min(APARTMENT_STREET_MIN_LENGTH).max(APARTMENT_STREET_MAX_LENGTH).optional(),
    city: z.string().min(APARTMENT_CITY_MIN_LENGTH).max(APARTMENT_CITY_MAX_LENGTH).optional(),
  })
  .openapi('UpdateApartmentRequest');

export const ApartmentDtoSchema = z
  .object({
    id: UuidV7Schema,
    ownerId: UuidV7Schema,
    name: z.string().min(APARTMENT_NAME_MIN_LENGTH).max(APARTMENT_NAME_MAX_LENGTH),
    street: z.string().min(APARTMENT_STREET_MIN_LENGTH).max(APARTMENT_STREET_MAX_LENGTH),
    city: z.string().min(APARTMENT_CITY_MIN_LENGTH).max(APARTMENT_CITY_MAX_LENGTH),
    role: ApartmentRoleSchema,
    inviteCode: z.string().nullable(),
    shouldSuggestInviteCodeReset: z.boolean(),
    cloudMediaCount: z.number().int().min(INITIAL_CLOUD_MEDIA_COUNT),
    createdAt: IsoDateTimeSchema,
    updatedAt: IsoDateTimeSchema,
  })
  .openapi('Apartment');

export const ApartmentListResponseSchema = z
  .object({
    items: z.array(ApartmentDtoSchema),
  })
  .openapi('ApartmentListResponse');

export const ApartmentChangeFieldSchema = z
  .enum([
    APARTMENT_CHANGE_FIELDS.NAME,
    APARTMENT_CHANGE_FIELDS.STREET,
    APARTMENT_CHANGE_FIELDS.CITY,
  ])
  .openapi('ApartmentChangeField');

export const ApartmentChangeDtoSchema = z
  .object({
    id: UuidV7Schema,
    apartmentId: UuidV7Schema,
    authorId: UuidV7Schema,
    field: ApartmentChangeFieldSchema,
    oldValue: z.string(),
    newValue: z.string(),
    createdAt: IsoDateTimeSchema,
  })
  .openapi('ApartmentChange');

export const ApartmentHistoryResponseSchema = z
  .object({
    items: z.array(ApartmentChangeDtoSchema),
  })
  .openapi('ApartmentHistoryResponse');

export type ApartmentDto = z.infer<typeof ApartmentDtoSchema>;
export type ApartmentChangeDto = z.infer<typeof ApartmentChangeDtoSchema>;
