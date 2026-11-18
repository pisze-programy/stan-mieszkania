import { z } from '@hono/zod-openapi';
import type { ErrorDetails } from '@stanmieszkania/shared';
import {
  MAX_HTTP_ERROR_STATUS,
  MIN_HTTP_ERROR_STATUS,
  PROBLEM_BASE_TYPE_URI,
  type HttpStatusCode,
} from './http-contracts.constants';

export const ProblemDetailsSchema = z
  .object({
    type: z.string().min(1),
    title: z.string().min(1),
    status: z.number().int().min(MIN_HTTP_ERROR_STATUS).max(MAX_HTTP_ERROR_STATUS),
    detail: z.string().min(1),
    code: z.string().min(1),
    requestId: z.string().min(1),
    details: z.record(z.string(), z.unknown()).optional(),
  })
  .openapi('ProblemDetails');

export type ProblemDetails = z.infer<typeof ProblemDetailsSchema>;

export interface CreateProblemDetailsInput {
  readonly status: HttpStatusCode;
  readonly title: string;
  readonly detail: string;
  readonly code: string;
  readonly requestId: string;
  readonly type?: string;
  readonly details?: ErrorDetails;
}

export function createProblemDetails(input: CreateProblemDetailsInput): ProblemDetails {
  const type = input.type ?? `${PROBLEM_BASE_TYPE_URI}${input.code.toLowerCase()}`;
  const base: ProblemDetails = {
    type,
    title: input.title,
    status: input.status,
    detail: input.detail,
    code: input.code,
    requestId: input.requestId,
  };

  if (input.details === undefined) {
    return base;
  }

  return {
    ...base,
    details: { ...input.details },
  };
}
