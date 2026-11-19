import { z } from 'zod';
import {
  APARTMENT_COORDINATOR_ORIGIN,
  APARTMENT_COORDINATOR_PATHS,
  DEFAULT_LEASE_TTL_MS,
} from './apartment-coordinator.constants';
import type {
  ApartmentCommandGateway,
  ApartmentCoordinatorNamespaceLike,
  MaintenanceRunResult,
} from './apartment-coordinator.types';

const AcquireLockResponseSchema = z.object({
  leaseToken: z.string().min(1),
});

const MaintenanceRunResultSchema = z.object({
  apartmentPurged: z.boolean(),
  cleanedPendingMediaCount: z.number().int().min(0),
  nextAlarmMs: z.number().nullable(),
});

function getStub(namespace: ApartmentCoordinatorNamespaceLike, apartmentId: string) {
  return namespace.get(namespace.idFromName(apartmentId));
}

export function createDurableObjectApartmentCommandGateway(
  namespace: ApartmentCoordinatorNamespaceLike,
): ApartmentCommandGateway {
  return {
    runSerialized: async <T>(apartmentId: string, operation: () => Promise<T>): Promise<T> => {
      const stub = getStub(namespace, apartmentId);
      const acquireResponse = await stub.fetch(
        `${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.LOCK_ACQUIRE}`,
        {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ leaseTtlMs: DEFAULT_LEASE_TTL_MS }),
        },
      );
      if (!acquireResponse.ok) {
        throw new Error(
          `ApartmentCoordinator lock acquire failed with status ${String(acquireResponse.status)}`,
        );
      }
      const { leaseToken } = AcquireLockResponseSchema.parse(await acquireResponse.json());

      try {
        return await operation();
      } finally {
        try {
          await stub.fetch(
            `${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.LOCK_RELEASE}`,
            {
              method: 'POST',
              headers: { 'content-type': 'application/json' },
              body: JSON.stringify({ leaseToken }),
            },
          );
        } catch {
          // Liveness invariant: stale leases expire automatically after DEFAULT_LEASE_TTL_MS.
        }
      }
    },

    scheduleOrphanPurge: async (apartmentId, orphanDeleteAfterMs) => {
      const stub = getStub(namespace, apartmentId);
      await stub.fetch(
        `${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.SCHEDULE_ORPHAN_PURGE}`,
        {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ apartmentId, orphanDeleteAfterMs }),
        },
      );
    },

    schedulePendingUploadCleanup: async (apartmentId, runAtMs, ttlMs) => {
      const stub = getStub(namespace, apartmentId);
      await stub.fetch(
        `${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.SCHEDULE_PENDING_CLEANUP}`,
        {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ apartmentId, runAtMs, ttlMs }),
        },
      );
    },

    runMaintenanceNow: async (apartmentId, nowMs): Promise<MaintenanceRunResult> => {
      const stub = getStub(namespace, apartmentId);
      const response = await stub.fetch(
        `${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.RUN_ALARM}`,
        {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ apartmentId, nowMs }),
        },
      );
      if (!response.ok) {
        throw new Error(
          `ApartmentCoordinator alarm RPC failed with status ${String(response.status)}`,
        );
      }
      return MaintenanceRunResultSchema.parse(await response.json());
    },
  };
}

export function createInProcessApartmentCommandGateway(): ApartmentCommandGateway {
  const queues = new Map<string, Promise<void>>();

  return {
    runSerialized: async <T>(apartmentId: string, operation: () => Promise<T>): Promise<T> => {
      const previous = queues.get(apartmentId) ?? Promise.resolve();
      let releaseTurn: () => void = () => undefined;
      const currentTurn = new Promise<void>((resolve) => {
        releaseTurn = resolve;
      });
      const tail = previous.then(() => currentTurn);
      queues.set(apartmentId, tail);

      await previous;
      try {
        return await operation();
      } finally {
        releaseTurn();
        if (queues.get(apartmentId) === tail) {
          queues.delete(apartmentId);
        }
      }
    },

    scheduleOrphanPurge: () => Promise.resolve(),
    schedulePendingUploadCleanup: () => Promise.resolve(),
    runMaintenanceNow: () =>
      Promise.resolve({ apartmentPurged: false, cleanedPendingMediaCount: 0, nextAlarmMs: null }),
  };
}
