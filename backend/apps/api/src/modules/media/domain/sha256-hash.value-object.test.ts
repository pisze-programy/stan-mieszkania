import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { MEDIA_ERROR_CODES } from './media.errors';
import { normalizeSha256Hash } from './sha256-hash.value-object';

describe('sha256-hash.value-object', () => {
  it('normalizes uppercase and surrounding whitespace into lowercase 64-char hex', () => {
    const raw = `  ${'ABCDEF0123456789'.repeat(4)}  `;
    const result = normalizeSha256Hash(raw);
    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value).toBe('abcdef0123456789'.repeat(4));
    }
  });

  it('rejects wrong length and non-hex strings with MEDIA_INVALID_SHA256', () => {
    const tooShort = normalizeSha256Hash('abcd');
    expect(isErr(tooShort) && tooShort.error.code).toBe(MEDIA_ERROR_CODES.MEDIA_INVALID_SHA256);

    const nonHex = normalizeSha256Hash('z'.repeat(64));
    expect(isErr(nonHex) && nonHex.error.code).toBe(MEDIA_ERROR_CODES.MEDIA_INVALID_SHA256);
  });
});
