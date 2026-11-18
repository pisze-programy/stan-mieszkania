import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { INVITE_CODE_ALPHABET } from './apartments.constants';
import { APARTMENT_ERROR_CODES } from './apartments.errors';
import { generateInviteCode, normalizeInviteCode } from './invite-code.value-object';

describe('InviteCode value object', () => {
  it('generates canonical XXXX-XXXX code from unambiguous alphabet', () => {
    const code = generateInviteCode();
    expect(code).toMatch(/^[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}$/);

    const deterministic = generateInviteCode(new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7]));
    expect(deterministic).toBe('2345-6789');
    expect(() => generateInviteCode(new Uint8Array(7))).toThrow(RangeError);
  });

  it('normalizes lowercase, spaces, and missing hyphens into canonical XXXX-XXXX', () => {
    const normalized = normalizeInviteCode(' k7qm 4xpb ');
    expect(isOk(normalized)).toBe(true);
    if (isOk(normalized)) {
      expect(normalized.value).toBe('K7QM-4XPB');
    }

    const noHyphen = normalizeInviteCode('k7qm4xpb');
    expect(noHyphen).toEqual({ ok: true, value: 'K7QM-4XPB' });
  });

  it('rejects wrong lengths and ambiguous characters (0, O, 1, I)', () => {
    for (const invalid of [
      'SHORT',
      'TOO-LONG-CODE',
      'K7QM-4XP0',
      'K7QM-4XPO',
      'K7QM-4XP1',
      'K7QM-4XPI',
    ]) {
      const result = normalizeInviteCode(invalid);
      expect(isErr(result)).toBe(true);
      if (isErr(result)) {
        expect(result.error.code).toBe(APARTMENT_ERROR_CODES.INVITE_CODE_INVALID);
      }
    }

    for (const forbidden of ['0', 'O', '1', 'I']) {
      expect(INVITE_CODE_ALPHABET.includes(forbidden)).toBe(false);
    }
  });
});
