import { createDomainError, err, isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { RecordingMediaCleanup } from '../../account-deletion';
import { APARTMENT_ERROR_CODES } from '../domain/apartments.errors';
import { InMemoryApartmentRepository } from '../testing/in-memory-apartment.repository';
import { createCreateApartmentUseCase } from './create-apartment.use-case';
import { createDeleteOrLeaveApartmentUseCase } from './delete-or-leave-apartment.use-case';
import { createListApartmentChangesUseCase } from './list-apartment-changes.use-case';
import { createResetInviteCodeUseCase } from './reset-invite-code.use-case';
import { createUpdateApartmentUseCase } from './update-apartment.use-case';

describe('Apartments application use cases', () => {
  it('creates apartment idempotently, retries invite code collisions, and blocks foreign reuse of apartmentId', async () => {
    const repo = new InMemoryApartmentRepository();
    const clock = new FixedClock();
    let seq = 0;
    const codes = ['AAAA-2222', 'AAAA-2222', 'BBBB-3333'];
    const createUseCase = createCreateApartmentUseCase({
      apartmentRepository: repo,
      clock,
      generateCode: () => codes[seq++] ?? 'CCCC-4444',
    });

    const first = await createUseCase.execute({
      apartmentId: 'apt-1',
      ownerId: 'usr-1',
      name: 'Kawalerka',
      street: 'Puławska 1',
      city: 'Warszawa',
    });
    expect(isOk(first)).toBe(true);
    if (isOk(first)) {
      expect(first.value.apartment.inviteCode).toBe('AAAA-2222');
    }

    const replay = await createUseCase.execute({
      apartmentId: 'apt-1',
      ownerId: 'usr-1',
      name: 'Different Name Ignored On Replay',
      street: 'Other',
      city: 'Other',
    });
    expect(isOk(replay)).toBe(true);
    if (isOk(first) && isOk(replay)) {
      expect(replay.value.apartment).toEqual(first.value.apartment);
    }

    const foreignReplay = await createUseCase.execute({
      apartmentId: 'apt-1',
      ownerId: 'usr-2',
      name: 'Hijack',
      street: 'S',
      city: 'C',
    });
    expect(isErr(foreignReplay)).toBe(true);
    if (isErr(foreignReplay)) {
      expect(foreignReplay.error.code).toBe(APARTMENT_ERROR_CODES.APARTMENT_ACCESS_DENIED);
    }

    const second = await createUseCase.execute({
      apartmentId: 'apt-2',
      ownerId: 'usr-2',
      name: 'Mieszkanie 2',
      street: 'Marszałkowska 10',
      city: 'Warszawa',
    });
    expect(isOk(second)).toBe(true);
    if (isOk(second)) {
      expect(second.value.apartment.inviteCode).toBe('BBBB-3333');
    }

    const failingRepo = new InMemoryApartmentRepository();
    failingRepo.createWithOwnerMembership = () =>
      Promise.resolve(err(createDomainError('DB_EXECUTION_FAILED', 'Simulated FK failure')));
    const failingCreate = createCreateApartmentUseCase({
      apartmentRepository: failingRepo,
      clock,
      generateCode: () => 'DDDD-5555',
    });
    const propagated = await failingCreate.execute({
      apartmentId: 'apt-3',
      ownerId: 'missing-user',
      name: 'Broken',
      street: 'S',
      city: 'C',
    });
    expect(isErr(propagated) && propagated.error.code).toBe('DB_EXECUTION_FAILED');
  });

  it('enforces owner-only update & reset, records change history, and handles owner transfer / contributor leave / solo delete', async () => {
    const repo = new InMemoryApartmentRepository();
    const clock = new FixedClock();
    const ids = new SequentialUuidV7Generator();

    const createUseCase = createCreateApartmentUseCase({
      apartmentRepository: repo,
      clock,
      generateCode: () => 'INIT-2222',
    });
    const updateUseCase = createUpdateApartmentUseCase({
      apartmentRepository: repo,
      clock,
      idGenerator: ids,
    });
    const resetUseCase = createResetInviteCodeUseCase({
      apartmentRepository: repo,
      clock,
      generateCode: () => 'NEXT-3333',
    });
    const mediaCleanup = new RecordingMediaCleanup();
    const deleteOrLeaveUseCase = createDeleteOrLeaveApartmentUseCase({
      apartmentRepository: repo,
      mediaCleanup,
      clock,
    });
    const historyUseCase = createListApartmentChangesUseCase({ apartmentRepository: repo });

    await createUseCase.execute({
      apartmentId: 'apt-1',
      ownerId: 'owner-1',
      name: 'Old',
      street: 'Street 1',
      city: 'Warszawa',
    });
    repo.seedMembership({
      apartmentId: 'apt-1',
      userId: 'contrib-1',
      role: 'contributor',
      joinedAt: '2026-11-18T12:05:00.000Z',
    });

    const contribUpdate = await updateUseCase.execute({
      apartmentId: 'apt-1',
      userId: 'contrib-1',
      name: 'Blocked',
    });
    expect(isErr(contribUpdate)).toBe(true);
    if (isErr(contribUpdate)) {
      expect(contribUpdate.error.code).toBe(APARTMENT_ERROR_CODES.APARTMENT_OWNER_REQUIRED);
    }

    clock.advanceBy(60_000);
    const ownerUpdate = await updateUseCase.execute({
      apartmentId: 'apt-1',
      userId: 'owner-1',
      name: 'New',
    });
    expect(isOk(ownerUpdate)).toBe(true);

    const history = await historyUseCase.execute({ apartmentId: 'apt-1', userId: 'contrib-1' });
    expect(isOk(history)).toBe(true);
    if (isOk(history)) {
      expect(history.value).toHaveLength(1);
    }

    const resetRes = await resetUseCase.execute({ apartmentId: 'apt-1', userId: 'owner-1' });
    expect(isOk(resetRes)).toBe(true);
    if (isOk(resetRes)) {
      expect(resetRes.value.apartment.inviteCode).toBe('NEXT-3333');
    }

    expect(
      (await deleteOrLeaveUseCase.execute({ apartmentId: 'apt-1', userId: 'owner-1' })).ok,
    ).toBe(true);
    const afterTransfer = await repo.findById('apt-1');
    if (isOk(afterTransfer)) {
      expect(afterTransfer.value?.ownerId).toBe('contrib-1');
    }

    repo.seedMediaR2Keys('apt-1', ['apartments/apt-1/photo-1.jpg']);
    expect(
      (await deleteOrLeaveUseCase.execute({ apartmentId: 'apt-1', userId: 'contrib-1' })).ok,
    ).toBe(true);
    expect(mediaCleanup.batches).toEqual([
      { userId: 'contrib-1', r2Keys: ['apartments/apt-1/photo-1.jpg'] },
    ]);
    const afterSoloDelete = await repo.findById('apt-1');
    if (isOk(afterSoloDelete)) {
      expect(afterSoloDelete.value).toBeNull();
    }
  });
});
