import {
  HTTP_STATUS,
  createProblemDetails,
  type ProblemDetails,
} from '@stanmieszkania/http-contracts';
import type { DomainError } from '@stanmieszkania/shared';
import type { Context } from 'hono';
import type { ZodError } from 'zod';
import {
  COMMON_ERROR_CODES,
  ERROR_CODE_HTTP_MAP,
  FALLBACK_HTTP_ERROR,
  type HttpErrorStatusCode,
} from './http.constants';
import { problemDetailsResponse } from './problem-details';

export interface MappedHttpError {
  readonly status: HttpErrorStatusCode;
  readonly problem: ProblemDetails;
}

export function mapDomainErrorToHttp(error: DomainError, requestId: string): MappedHttpError {
  const mapping = ERROR_CODE_HTTP_MAP[error.code] ?? FALLBACK_HTTP_ERROR;
  const problem = createProblemDetails({
    status: mapping.status,
    title: mapping.title,
    detail: error.message,
    code: error.code,
    requestId,
    ...(error.details !== undefined ? { details: error.details } : {}),
  });

  return { status: mapping.status, problem };
}

export function validationErrorResponse(c: Context, error: ZodError, requestId: string): Response {
  const problem = createProblemDetails({
    status: HTTP_STATUS.BAD_REQUEST,
    title: 'Validation Failed',
    detail: 'Request validation failed',
    code: COMMON_ERROR_CODES.VALIDATION_ERROR,
    requestId,
    details: {
      issues: error.issues.map((issue) => ({
        path: issue.path.join('.'),
        message: issue.message,
      })),
    },
  });

  return problemDetailsResponse(c, HTTP_STATUS.BAD_REQUEST, problem);
}

export function notFoundErrorResponse(c: Context, requestId: string): Response {
  const problem = createProblemDetails({
    status: HTTP_STATUS.NOT_FOUND,
    title: 'Route Not Found',
    detail: `Route ${c.req.method} ${c.req.path} was not found`,
    code: COMMON_ERROR_CODES.ROUTE_NOT_FOUND,
    requestId,
  });

  return problemDetailsResponse(c, HTTP_STATUS.NOT_FOUND, problem);
}

export function internalServerErrorResponse(c: Context, requestId: string): Response {
  const problem = createProblemDetails({
    status: HTTP_STATUS.INTERNAL_SERVER_ERROR,
    title: 'Internal Server Error',
    detail: 'An unexpected internal error occurred',
    code: COMMON_ERROR_CODES.INTERNAL_ERROR,
    requestId,
  });

  return problemDetailsResponse(c, HTTP_STATUS.INTERNAL_SERVER_ERROR, problem);
}
