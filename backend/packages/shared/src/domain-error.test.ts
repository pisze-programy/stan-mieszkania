import { describe, expect, it } from 'vitest';
import { createDomainError } from './domain-error';

describe('createDomainError', () => {
  it('omits details property when details are not provided', () => {
    const error = createDomainError('QUOTA_EXCEEDED', 'Cloud media quota reached');

    expect(error).toEqual({
      code: 'QUOTA_EXCEEDED',
      message: 'Cloud media quota reached',
    });
    expect('details' in error).toBe(false);
  });

  it('includes details when provided', () => {
    const error = createDomainError('QUOTA_EXCEEDED', 'Cloud media quota reached', {
      limit: 250,
      current: 250,
    });

    expect(error).toEqual({
      code: 'QUOTA_EXCEEDED',
      message: 'Cloud media quota reached',
      details: { limit: 250, current: 250 },
    });
  });
});
