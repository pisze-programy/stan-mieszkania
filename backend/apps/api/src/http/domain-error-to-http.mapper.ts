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

function createInternalProblemDetails(
  status: HttpErrorStatusCode,
  title: string,
  requestId: string,
): ProblemDetails {
  return createProblemDetails({
    status,
    title,
    detail: 'An unexpected internal error occurred',
    code: COMMON_ERROR_CODES.INTERNAL_ERROR,
    requestId,
  });
}

export function mapDomainErrorToHttp(error: DomainError, requestId: string): MappedHttpError {
  const mapping = ERROR_CODE_HTTP_MAP[error.code];

  // Never expose unmapped or 5xx internal error messages, codes, or details (e.g. SQL/Zod internals).
  if (mapping === undefined || mapping.status >= HTTP_STATUS.INTERNAL_SERVER_ERROR) {
    const status = mapping?.status ?? FALLBACK_HTTP_ERROR.status;
    const title = mapping?.title ?? FALLBACK_HTTP_ERROR.title;
    return {
      status,
      problem: createInternalProblemDetails(status, title, requestId),
    };
  }

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

export function validationErrorResponse(c: Context, error: ZodError, requestId: string) {
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

export function notFoundErrorResponse(c: Context, requestId: string) {
  const problem = createProblemDetails({
    status: HTTP_STATUS.NOT_FOUND,
    title: 'Route Not Found',
    detail: `Route ${c.req.method} ${c.req.path} was not found`,
    code: COMMON_ERROR_CODES.ROUTE_NOT_FOUND,
    requestId,
  });

  return problemDetailsResponse(c, HTTP_STATUS.NOT_FOUND, problem);
}

export function internalServerErrorResponse(c: Context, requestId: string) {
  const problem = createInternalProblemDetails(
    HTTP_STATUS.INTERNAL_SERVER_ERROR,
    FALLBACK_HTTP_ERROR.title,
    requestId,
  );

  return problemDetailsResponse(c, HTTP_STATUS.INTERNAL_SERVER_ERROR, problem);
}

export function respondDomainError<const TAllowed extends readonly HttpErrorStatusCode[]>(
  c: Context,
  error: DomainError,
  requestId: string,
  allowedStatuses: TAllowed,
) {
  const mapped = mapDomainErrorToHttp(error, requestId);
  const matchedStatus = allowedStatuses.find(
    (status): status is TAllowed[number] => status === mapped.status,
  );

  if (matchedStatus !== undefined) {
    return problemDetailsResponse(c, matchedStatus, mapped.problem);
  }

  return internalServerErrorResponse(c, requestId);
}
