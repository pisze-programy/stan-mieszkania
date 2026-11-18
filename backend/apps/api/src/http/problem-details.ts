import {
  PROBLEM_JSON_CONTENT_TYPE,
  createProblemDetails,
  type ProblemDetails,
} from '@stanmieszkania/http-contracts';
import type { Context } from 'hono';
import type { HttpErrorStatusCode } from './http.constants';

export function problemDetailsResponse<TStatus extends HttpErrorStatusCode>(
  c: Context,
  status: TStatus,
  problem: ProblemDetails,
) {
  return c.json(problem, status, {
    'Content-Type': PROBLEM_JSON_CONTENT_TYPE,
  });
}

export { createProblemDetails, type ProblemDetails };
