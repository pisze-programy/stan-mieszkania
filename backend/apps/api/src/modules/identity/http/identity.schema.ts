import { z } from '@hono/zod-openapi';
import { IsoDateTimeSchema, UuidV7Schema } from '@stanmieszkania/http-contracts';
import {
  DISPLAY_NAME_MAX_LENGTH,
  DISPLAY_NAME_MIN_LENGTH,
  HEX_COLOR_REGEX,
  SHORT_TAG_LENGTH,
} from '../domain/identity.constants';

export const UserProfileSchema = z
  .object({
    id: UuidV7Schema,
    displayName: z.string().min(DISPLAY_NAME_MIN_LENGTH).max(DISPLAY_NAME_MAX_LENGTH),
    shortTag: z.string().length(SHORT_TAG_LENGTH),
    color: z.string().regex(HEX_COLOR_REGEX),
    createdAt: IsoDateTimeSchema,
  })
  .openapi('UserProfile');

export const UpdateProfileRequestSchema = z
  .object({
    displayName: z.string().min(DISPLAY_NAME_MIN_LENGTH).max(DISPLAY_NAME_MAX_LENGTH),
  })
  .openapi('UpdateProfileRequest');

export type UserProfileDto = z.infer<typeof UserProfileSchema>;
export type UpdateProfileRequestDto = z.infer<typeof UpdateProfileRequestSchema>;
