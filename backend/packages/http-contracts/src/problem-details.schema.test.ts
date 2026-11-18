import { describe, expect, it } from 'vitest';
import { HTTP_STATUS, PROBLEM_BASE_TYPE_URI } from './http-contracts.constants';
import { ProblemDetailsSchema, createProblemDetails } from './problem-details.schema';

describe('ProblemDetailsSchema', () => {
  it('constructs RFC 9457 payload and omits details when undefined', () => {
    const problem = createProblemDetails({
      status: HTTP_STATUS.UNPROCESSABLE_ENTITY,
      title: 'Quota exceeded',
      detail: 'Apartment cloud media limit of 250 reached',
      code: 'QUOTA_EXCEEDED',
      requestId: 'req-123',
    });

    expect(ProblemDetailsSchema.parse(problem)).toEqual({
      type: `${PROBLEM_BASE_TYPE_URI}quota_exceeded`,
      title: 'Quota exceeded',
      status: 422,
      detail: 'Apartment cloud media limit of 250 reached',
      code: 'QUOTA_EXCEEDED',
      requestId: 'req-123',
    });
    expect('details' in problem).toBe(false);
  });

  it('preserves explicit type and structured details when provided', () => {
    const problem = createProblemDetails({
      type: 'https://stanmieszkania.pl/problems/custom',
      status: HTTP_STATUS.BAD_REQUEST,
      title: 'Validation failed',
      detail: 'Invalid field',
      code: 'VALIDATION_ERROR',
      requestId: 'req-456',
      details: { field: 'name' },
    });

    expect(ProblemDetailsSchema.parse(problem)).toEqual({
      type: 'https://stanmieszkania.pl/problems/custom',
      title: 'Validation failed',
      status: 400,
      detail: 'Invalid field',
      code: 'VALIDATION_ERROR',
      requestId: 'req-456',
      details: { field: 'name' },
    });
  });

  it('rejects non-error HTTP status codes', () => {
    const result = ProblemDetailsSchema.safeParse({
      type: 'https://stanmieszkania.pl/problems/ok',
      title: 'OK',
      status: 200,
      detail: 'Not an error',
      code: 'OK',
      requestId: 'req-789',
    });

    expect(result.success).toBe(false);
  });
});
