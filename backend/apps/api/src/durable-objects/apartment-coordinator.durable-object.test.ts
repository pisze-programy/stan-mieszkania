import { describe, expect, it } from 'vitest';
import {
  APARTMENT_COORDINATOR_HTTP_STATUS,
  APARTMENT_COORDINATOR_ORIGIN,
  APARTMENT_COORDINATOR_PATHS,
  COORDINATOR_STATE_STORAGE_KEY,
} from './apartment-coordinator.constants';
import { ApartmentCoordinator } from './apartment-coordinator.durable-object';
import type { CoordinatorPersistedState } from './apartment-coordinator.types';
import type { UserGuardStorageLike } from './user-guard.types';

class InMemoryCoordinatorStorage implements UserGuardStorageLike {
  readonly data = new Map<string, unknown>();
  readonly alarms: number[] = [];

  get<T = unknown>(key: string): Promise<T | undefined> {
    // reason: Generic test storage mirrors DurableObjectStorage.get<T> lookup semantics.
    return Promise.resolve(this.data.get(key) as T | undefined);
  }

  put(key: string, value: unknown): Promise<void> {
    this.data.set(key, value);
    return Promise.resolve();
  }

  delete(key: string): Promise<boolean> {
    return Promise.resolve(this.data.delete(key));
  }

  setAlarm(scheduledTime: number | Date): Promise<void> {
    const timeMs = scheduledTime instanceof Date ? scheduledTime.getTime() : scheduledTime;
    this.alarms.push(timeMs);
    return Promise.resolve();
  }
}

describe('ApartmentCoordinator Durable Object', () => {
  it('serializes concurrent lock acquisitions in FIFO order and expires stale leases', async () => {
    const storage = new InMemoryCoordinatorStorage();
    const coordinator = new ApartmentCoordinator({ storage }, {});
    const events: string[] = [];

    const firstToken = await coordinator.acquireLock(10_000, 1_000);
    events.push(`acquired:${firstToken}`);

    const secondPromise = coordinator.acquireLock(10_000, 1_500).then((token) => {
      events.push(`acquired:${token}`);
      return token;
    });
    const thirdPromise = coordinator.acquireLock(10_000, 1_500).then((token) => {
      events.push(`acquired:${token}`);
      return token;
    });

    expect(coordinator.releaseLock('wrong-token')).toBe(false);
    expect(events).toEqual(['acquired:lease-1']);

    expect(coordinator.releaseLock(firstToken)).toBe(true);
    const secondToken = await secondPromise;
    expect(events).toEqual(['acquired:lease-1', 'acquired:lease-2']);

    expect(coordinator.releaseLock(secondToken)).toBe(true);
    const thirdToken = await thirdPromise;
    expect(events).toEqual(['acquired:lease-1', 'acquired:lease-2', 'acquired:lease-3']);

    const staleBypassToken = await coordinator.acquireLock(5_000, Date.now() + 60_000);
    expect(staleBypassToken).toBe('lease-4');
    expect(coordinator.releaseLock(thirdToken)).toBe(false);
    expect(coordinator.releaseLock(staleBypassToken)).toBe(true);
  });

  it('tracks orphan purge and pending cleanup schedules using the earliest alarm timestamp', async () => {
    const storage = new InMemoryCoordinatorStorage();
    const coordinator = new ApartmentCoordinator({ storage }, {});

    await coordinator.scheduleOrphanPurge('apt-1', 500_000);
    expect(storage.alarms).toEqual([500_000]);

    await coordinator.schedulePendingCleanup('apt-1', 200_000, 86_400_000);
    expect(storage.alarms).toEqual([500_000, 200_000]);

    await coordinator.schedulePendingCleanup('apt-1', 350_000, 86_400_000);
    expect(storage.alarms).toEqual([500_000, 200_000, 200_000]);

    const persisted = await storage.get<CoordinatorPersistedState>(COORDINATOR_STATE_STORAGE_KEY);
    expect(persisted).toEqual({
      apartmentId: 'apt-1',
      orphanDeleteAfterMs: 500_000,
      pendingCleanupAtMs: 200_000,
      abandonedPendingUploadTtlMs: 86_400_000,
    });

    const releaseGate = await coordinator.acquireLock(10_000);
    const concurrentSchedule = coordinator.schedulePendingCleanup('apt-1', 150_000, 86_400_000);
    await Promise.resolve();
    expect(storage.alarms).toEqual([500_000, 200_000, 200_000]);
    expect(coordinator.releaseLock(releaseGate)).toBe(true);
    await concurrentSchedule;
    expect(storage.alarms).toEqual([500_000, 200_000, 200_000, 150_000]);
  });

  it('handles HTTP RPC endpoints and rejects malformed requests', async () => {
    const storage = new InMemoryCoordinatorStorage();
    const coordinator = new ApartmentCoordinator({ storage }, {});

    const acquireRes = await coordinator.fetch(
      new Request(`${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.LOCK_ACQUIRE}`, {
        method: 'POST',
        body: JSON.stringify({ leaseTtlMs: 5_000, nowMs: 1_000 }),
      }),
    );
    expect(acquireRes.status).toBe(APARTMENT_COORDINATOR_HTTP_STATUS.OK);
    const acquired = (await acquireRes.json()) as { leaseToken: string }; // reason: Narrowing validated test DO RPC response JSON.

    const releaseRes = await coordinator.fetch(
      new Request(`${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.LOCK_RELEASE}`, {
        method: 'POST',
        body: JSON.stringify({ leaseToken: acquired.leaseToken }),
      }),
    );
    expect(releaseRes.status).toBe(APARTMENT_COORDINATOR_HTTP_STATUS.OK);
    expect(await releaseRes.json()).toEqual({ released: true });

    const getRes = await coordinator.fetch(
      new Request(`${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.LOCK_ACQUIRE}`, {
        method: 'GET',
      }),
    );
    expect(getRes.status).toBe(APARTMENT_COORDINATOR_HTTP_STATUS.NOT_FOUND);

    const badJsonRes = await coordinator.fetch(
      new Request(`${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.LOCK_ACQUIRE}`, {
        method: 'POST',
        body: '{invalid',
      }),
    );
    expect(badJsonRes.status).toBe(APARTMENT_COORDINATOR_HTTP_STATUS.BAD_REQUEST);

    const badPayloadRes = await coordinator.fetch(
      new Request(
        `${APARTMENT_COORDINATOR_ORIGIN}${APARTMENT_COORDINATOR_PATHS.SCHEDULE_ORPHAN_PURGE}`,
        {
          method: 'POST',
          body: JSON.stringify({ apartmentId: 123 }),
        },
      ),
    );
    expect(badPayloadRes.status).toBe(APARTMENT_COORDINATOR_HTTP_STATUS.BAD_REQUEST);
  });
});
