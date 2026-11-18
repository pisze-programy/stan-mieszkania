import {
  PROBLEM_JSON_CONTENT_TYPE,
  createProblemDetails,
  type ProblemDetails,
} from '@stanmieszkania/http-contracts';
import type { Context } from 'hono';
import type { HttpErrorStatusCode } from './http.constants';

export function problemDetailsResponse(
  c: Context,
  status: HttpErrorStatusCode,
  problem: ProblemDetails,
): Response {
  return c.body(JSON.stringify(problem), status, {
    'Content-Type': PROBLEM_JSON_CONTENT_TYPE,
  });
}

export { createProblemDetails, type ProblemDetails };
