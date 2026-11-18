import { isErr, isOk } from '@stanmieszkania/shared';
import { SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import {
  applyApartmentMetadataUpdate,
  createApartment,
  rotateInviteCode,
  shouldSuggestInviteCodeReset,
} from './apartment.entity';
import { APARTMENT_NAME_MAX_LENGTH } from './apartments.constants';
import { APARTMENT_ERROR_CODES } from './apartments.errors';

describe('Apartment and ApartmentChange domain entities', () => {
  it('creates an apartment with trimmed fields and initial defaults', () => {
    const result = createApartment({
      id: 'apt-1',
      ownerId: 'usr-1',
      name: '  Mokotów Kawalerka  ',
      street: '  Puławska 12/4  ',
      city: '  Warszawa  ',
      inviteCode: 'K7QM-4XPB',
      createdAt: '2026-11-18T12:00:00.000Z',
    });

    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value).toEqual({
        id: 'apt-1',
        ownerId: 'usr-1',
        name: 'Mokotów Kawalerka',
        street: 'Puławska 12/4',
        city: 'Warszawa',
        inviteCode: 'K7QM-4XPB',
        inviteCodeRotatedAt: null,
        cloudMediaCount: 0,
        orphanDeleteAfter: null,
        createdAt: '2026-11-18T12:00:00.000Z',
        updatedAt: '2026-11-18T12:00:00.000Z',
        deletedAt: null,
      });
    }
  });

  it('rejects empty or oversized metadata fields', () => {
    const emptyName = createApartment({
      id: 'apt-1',
      ownerId: 'usr-1',
      name: '   ',
      street: 'Puławska 12',
      city: 'Warszawa',
      inviteCode: 'K7QM-4XPB',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    expect(isErr(emptyName)).toBe(true);
    if (isErr(emptyName)) {
      expect(emptyName.error.code).toBe(APARTMENT_ERROR_CODES.APARTMENT_VALIDATION_FAILED);
    }

    const oversizedName = createApartment({
      id: 'apt-1',
      ownerId: 'usr-1',
      name: 'x'.repeat(APARTMENT_NAME_MAX_LENGTH + 1),
      street: 'Puławska 12',
      city: 'Warszawa',
      inviteCode: 'K7QM-4XPB',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    expect(isErr(oversizedName)).toBe(true);
  });

  it('computes field-level change records on update and skips unchanged updates', () => {
    const created = createApartment({
      id: 'apt-1',
      ownerId: 'usr-1',
      name: 'Stara Nazwa',
      street: 'Puławska 12',
      city: 'Warszawa',
      inviteCode: 'K7QM-4XPB',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    expect(isOk(created)).toBe(true);
    if (!isOk(created)) return;

    const ids = new SequentialUuidV7Generator();
    const noOp = applyApartmentMetadataUpdate({
      apartment: created.value,
      authorId: 'usr-1',
      name: '  Stara Nazwa ',
      updatedAt: '2026-11-18T12:05:00.000Z',
      idGenerator: ids,
    });
    expect(isOk(noOp)).toBe(true);
    if (isOk(noOp)) {
      expect(noOp.value.changes).toHaveLength(0);
      expect(noOp.value.apartment.updatedAt).toBe('2026-11-18T12:00:00.000Z');
    }

    const updated = applyApartmentMetadataUpdate({
      apartment: created.value,
      authorId: 'usr-1',
      name: 'Nowa Nazwa',
      city: 'Kraków',
      updatedAt: '2026-11-18T12:10:00.000Z',
      idGenerator: ids,
    });
    expect(isOk(updated)).toBe(true);
    if (isOk(updated)) {
      expect(updated.value.apartment.name).toBe('Nowa Nazwa');
      expect(updated.value.apartment.street).toBe('Puławska 12');
      expect(updated.value.apartment.city).toBe('Kraków');
      expect(updated.value.changes).toHaveLength(2);
      expect(updated.value.changes[0]).toMatchObject({
        field: 'name',
        oldValue: 'Stara Nazwa',
        newValue: 'Nowa Nazwa',
      });
      expect(updated.value.changes[1]).toMatchObject({
        field: 'city',
        oldValue: 'Warszawa',
        newValue: 'Kraków',
      });
    }
  });

  it('rotates invite code and computes invite code reset suggestion', () => {
    const created = createApartment({
      id: 'apt-1',
      ownerId: 'usr-1',
      name: 'Mieszkanie',
      street: 'Puławska 12',
      city: 'Warszawa',
      inviteCode: 'K7QM-4XPB',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    expect(isOk(created)).toBe(true);
    if (!isOk(created)) return;

    expect(shouldSuggestInviteCodeReset(null, null)).toBe(false);
    expect(shouldSuggestInviteCodeReset(null, '2026-11-18T12:30:00.000Z')).toBe(true);

    const rotated = rotateInviteCode(created.value, 'ABCD-2345', '2026-11-18T13:00:00.000Z');
    expect(rotated.inviteCode).toBe('ABCD-2345');
    expect(rotated.inviteCodeRotatedAt).toBe('2026-11-18T13:00:00.000Z');

    expect(
      shouldSuggestInviteCodeReset(rotated.inviteCodeRotatedAt, '2026-11-18T12:30:00.000Z'),
    ).toBe(false);
    expect(
      shouldSuggestInviteCodeReset(rotated.inviteCodeRotatedAt, '2026-11-18T14:00:00.000Z'),
    ).toBe(true);
  });
});
