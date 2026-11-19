import type { ApartmentCommandGateway } from '../durable-objects/apartment-coordinator.types';
import type { AccountDeletionRepository } from '../modules/account-deletion';

// Architecture A17: Serialize per-apartment account-deletion mutations and schedule 30-day orphan alarms.
export function createSerializedAccountDeletionRepository(
  inner: AccountDeletionRepository,
  gateway: ApartmentCommandGateway,
): AccountDeletionRepository {
  return {
    listUserApartments: (userId) => inner.listUserApartments(userId),
    hardDeletePrivateApartment: (apartmentId) =>
      gateway.runSerialized(apartmentId, () => inner.hardDeletePrivateApartment(apartmentId)),
    transferOwnershipAndLeave: (params) =>
      gateway.runSerialized(params.apartmentId, () => inner.transferOwnershipAndLeave(params)),
    scheduleOrphanDeleteAndLeave: async (params) => {
      const result = await gateway.runSerialized(params.apartmentId, () =>
        inner.scheduleOrphanDeleteAndLeave(params),
      );
      if (result.ok) {
        const orphanDeleteAfterMs = Date.parse(params.orphanDeleteAfter);
        if (Number.isFinite(orphanDeleteAfterMs)) {
          await gateway.scheduleOrphanPurge(params.apartmentId, orphanDeleteAfterMs);
        }
      }
      return result;
    },
    leaveAsContributor: (params) =>
      gateway.runSerialized(params.apartmentId, () => inner.leaveAsContributor(params)),
    anonymizeUserPreservingUid: (userId, displayName, deletedAt) =>
      inner.anonymizeUserPreservingUid(userId, displayName, deletedAt),
  };
}
