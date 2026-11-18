import { z } from '@hono/zod-openapi';
import {
  APPLE_AUTH_CODE_MAX_LENGTH,
  APPLE_AUTH_CODE_MIN_LENGTH,
} from '../domain/account-deletion.constants';

export const DeleteAccountRequestSchema = z
  .object({
    appleAuthorizationCode: z
      .string()
      .trim()
      .min(APPLE_AUTH_CODE_MIN_LENGTH)
      .max(APPLE_AUTH_CODE_MAX_LENGTH)
      .optional()
      .openapi({ example: 'c9b4a3e2f1d0.0.abcde.12345' }),
  })
  .openapi('DeleteAccountRequest');

export type DeleteAccountRequestDto = z.infer<typeof DeleteAccountRequestSchema>;
