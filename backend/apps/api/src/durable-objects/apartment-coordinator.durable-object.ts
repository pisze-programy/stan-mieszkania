import {
  APARTMENT_COORDINATOR_HTTP_STATUS,
  APARTMENT_COORDINATOR_PATHS,
  COORDINATOR_STATE_STORAGE_KEY,
  DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS,
  DEFAULT_LEASE_TTL_MS,
} from './apartment-coordinator.constants';
import { executeApartmentMaintenance } from './apartment-coordinator.maintenance';
import type {
  ApartmentCoordinatorEnv,
  ApartmentCoordinatorStateLike,
  CoordinatorD1PreparedStatementLike,
  CoordinatorPersistedState,
  MaintenanceRunResult,
} from './apartment-coordinator.types';

interface ActiveLease {
  readonly token: string;
  readonly expiresAtMs: number;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function jsonRes(
  payload: unknown,
  status: number = APARTMENT_COORDINATOR_HTTP_STATUS.OK,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function posNum(value: unknown, fallback: number): number {
  return typeof value === 'number' && value > 0 ? value : fallback;
}

// Architecture A17: Per-apartment Durable Object serializes mutations via FIFO lease and executes alarm jobs.
export class ApartmentCoordinator<
  TStatement extends CoordinatorD1PreparedStatementLike<TStatement> =
    CoordinatorD1PreparedStatementLike<never>,
> {
  private readonly ctx: ApartmentCoordinatorStateLike;
  private readonly env: ApartmentCoordinatorEnv<TStatement>;
  private activeLease: ActiveLease | null = null;
  private leaseCounter = 0;
  private readonly waiters: (() => void)[] = [];

  constructor(ctx: ApartmentCoordinatorStateLike, env: ApartmentCoordinatorEnv<TStatement>) {
    this.ctx = ctx;
    this.env = env;
  }

  async acquireLock(
    leaseTtlMs: number = DEFAULT_LEASE_TTL_MS,
    nowMs: number = Date.now(),
  ): Promise<string> {
    while (this.activeLease !== null && this.activeLease.expiresAtMs > nowMs) {
      await new Promise<void>((resolve) => {
        this.waiters.push(resolve);
      });
      nowMs = Date.now();
    }
    this.leaseCounter += 1;
    const token = `lease-${String(this.leaseCounter)}`;
    this.activeLease = { token, expiresAtMs: nowMs + leaseTtlMs };
    return token;
  }

  releaseLock(token: string): boolean {
    if (this.activeLease === null || this.activeLease.token !== token) return false;
    this.activeLease = null;
    this.waiters.shift()?.();
    return true;
  }

  async scheduleOrphanPurge(apartmentId: string, orphanDeleteAfterMs: number): Promise<void> {
    const prev = await this.readState();
    await this.saveAndSyncAlarm({
      apartmentId,
      orphanDeleteAfterMs,
      pendingCleanupAtMs: prev?.pendingCleanupAtMs ?? null,
      abandonedPendingUploadTtlMs:
        prev?.abandonedPendingUploadTtlMs ?? DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS,
    });
  }

  async schedulePendingCleanup(
    apartmentId: string,
    runAtMs: number,
    ttlMs: number = DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS,
  ): Promise<void> {
    const prev = await this.readState();
    const prevPending = prev?.pendingCleanupAtMs;
    await this.saveAndSyncAlarm({
      apartmentId,
      orphanDeleteAfterMs: prev?.orphanDeleteAfterMs ?? null,
      pendingCleanupAtMs:
        prevPending !== null && prevPending !== undefined
          ? Math.min(prevPending, runAtMs)
          : runAtMs,
      abandonedPendingUploadTtlMs: ttlMs,
    });
  }

  async runMaintenance(
    nowMs: number = Date.now(),
    explicitApartmentId?: string,
  ): Promise<MaintenanceRunResult> {
    const token = await this.acquireLock(DEFAULT_LEASE_TTL_MS, nowMs);
    try {
      const stored = await this.readState();
      const state: CoordinatorPersistedState | undefined =
        stored ??
        (explicitApartmentId !== undefined
          ? {
              apartmentId: explicitApartmentId,
              orphanDeleteAfterMs: null,
              pendingCleanupAtMs: null,
              abandonedPendingUploadTtlMs: DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS,
            }
          : undefined);
      if (state === undefined) {
        return { apartmentPurged: false, cleanedPendingMediaCount: 0, nextAlarmMs: null };
      }

      const result = await executeApartmentMaintenance(this.env, state, nowMs);
      if (result.apartmentPurged || result.nextAlarmMs === null) {
        await this.ctx.storage.delete(COORDINATOR_STATE_STORAGE_KEY);
      } else {
        await this.ctx.storage.put(COORDINATOR_STATE_STORAGE_KEY, {
          ...state,
          pendingCleanupAtMs: result.nextAlarmMs,
        });
        await this.ctx.storage.setAlarm(result.nextAlarmMs);
      }
      return result;
    } finally {
      this.releaseLock(token);
    }
  }

  async alarm(): Promise<void> {
    await this.runMaintenance(Date.now());
  }

  async fetch(request: Request): Promise<Response> {
    const { BAD_REQUEST, NOT_FOUND } = APARTMENT_COORDINATOR_HTTP_STATUS;
    if (request.method !== 'POST') return jsonRes({ error: 'Not found' }, NOT_FOUND);
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonRes({ error: 'Invalid JSON' }, BAD_REQUEST);
    }
    if (!isRecord(body)) return jsonRes({ error: 'Invalid payload' }, BAD_REQUEST);
    return this.dispatchAction(new URL(request.url).pathname, body);
  }

  private async dispatchAction(pathname: string, body: Record<string, unknown>): Promise<Response> {
    const { BAD_REQUEST, NOT_FOUND } = APARTMENT_COORDINATOR_HTTP_STATUS;
    const {
      LOCK_ACQUIRE,
      LOCK_RELEASE,
      SCHEDULE_ORPHAN_PURGE,
      SCHEDULE_PENDING_CLEANUP,
      RUN_ALARM,
    } = APARTMENT_COORDINATOR_PATHS;
    if (pathname === LOCK_ACQUIRE) {
      const ttl = posNum(body['leaseTtlMs'], DEFAULT_LEASE_TTL_MS);
      const now = typeof body['nowMs'] === 'number' ? body['nowMs'] : undefined;
      return jsonRes({ leaseToken: await this.acquireLock(ttl, now) });
    }
    if (pathname === LOCK_RELEASE) {
      return typeof body['leaseToken'] === 'string'
        ? jsonRes({ released: this.releaseLock(body['leaseToken']) })
        : jsonRes({ error: 'Invalid leaseToken' }, BAD_REQUEST);
    }
    if (pathname === SCHEDULE_ORPHAN_PURGE) {
      if (
        typeof body['apartmentId'] !== 'string' ||
        typeof body['orphanDeleteAfterMs'] !== 'number'
      ) {
        return jsonRes({ error: 'Invalid payload' }, BAD_REQUEST);
      }
      await this.scheduleOrphanPurge(body['apartmentId'], body['orphanDeleteAfterMs']);
      return jsonRes({ scheduled: true });
    }
    if (pathname === SCHEDULE_PENDING_CLEANUP) {
      if (typeof body['apartmentId'] !== 'string' || typeof body['runAtMs'] !== 'number') {
        return jsonRes({ error: 'Invalid payload' }, BAD_REQUEST);
      }
      const ttl = posNum(body['ttlMs'], DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS);
      await this.schedulePendingCleanup(body['apartmentId'], body['runAtMs'], ttl);
      return jsonRes({ scheduled: true });
    }
    if (pathname === RUN_ALARM) {
      const now = typeof body['nowMs'] === 'number' ? body['nowMs'] : undefined;
      const aptId = typeof body['apartmentId'] === 'string' ? body['apartmentId'] : undefined;
      return jsonRes(await this.runMaintenance(now, aptId));
    }
    return jsonRes({ error: 'Not found' }, NOT_FOUND);
  }

  private readState(): Promise<CoordinatorPersistedState | undefined> {
    return this.ctx.storage.get<CoordinatorPersistedState>(COORDINATOR_STATE_STORAGE_KEY);
  }

  private async saveAndSyncAlarm(state: CoordinatorPersistedState): Promise<void> {
    await this.ctx.storage.put(COORDINATOR_STATE_STORAGE_KEY, state);
    const candidates = [state.orphanDeleteAfterMs, state.pendingCleanupAtMs].filter(
      (value): value is number => value !== null,
    );
    if (candidates.length > 0) await this.ctx.storage.setAlarm(Math.min(...candidates));
  }
}
