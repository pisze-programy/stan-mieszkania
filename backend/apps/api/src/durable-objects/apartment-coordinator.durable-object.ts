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

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function defaultState(apartmentId: string): CoordinatorPersistedState {
  return {
    apartmentId,
    orphanDeleteAfterMs: null,
    pendingCleanupAtMs: null,
    abandonedPendingUploadTtlMs: DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS,
  };
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

// Architecture A17: Per-apartment Durable Object serializes mutations via FIFO lease and executes alarm jobs.
export class ApartmentCoordinator<
  TStatement extends CoordinatorD1PreparedStatementLike<TStatement> =
    CoordinatorD1PreparedStatementLike<never>,
> {
  private readonly ctx: ApartmentCoordinatorStateLike;
  private readonly env: ApartmentCoordinatorEnv<TStatement>;
  private activeLease: { readonly token: string; readonly expiresAtMs: number } | null = null;
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
    await this.updateSchedule(apartmentId, (prev) => ({ ...prev, orphanDeleteAfterMs }));
  }

  async schedulePendingCleanup(
    apartmentId: string,
    runAtMs: number,
    ttlMs: number = DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS,
  ): Promise<void> {
    await this.updateSchedule(apartmentId, (prev) => ({
      ...prev,
      pendingCleanupAtMs:
        prev.pendingCleanupAtMs !== null ? Math.min(prev.pendingCleanupAtMs, runAtMs) : runAtMs,
      abandonedPendingUploadTtlMs: ttlMs,
    }));
  }

  async runMaintenance(
    nowMs: number = Date.now(),
    explicitApartmentId?: string,
  ): Promise<MaintenanceRunResult> {
    return this.withLock(async () => {
      const stored = await this.ctx.storage.get<CoordinatorPersistedState>(
        COORDINATOR_STATE_STORAGE_KEY,
      );
      const state =
        stored ??
        (explicitApartmentId !== undefined ? defaultState(explicitApartmentId) : undefined);
      if (state === undefined)
        return { apartmentPurged: false, cleanedPendingMediaCount: 0, nextAlarmMs: null };
      const result = await executeApartmentMaintenance(this.env, state, nowMs);
      if (result.apartmentPurged || result.nextAlarmMs === null) {
        await this.ctx.storage.delete(COORDINATOR_STATE_STORAGE_KEY);
      } else {
        await this.saveAndSyncAlarm({ ...state, pendingCleanupAtMs: result.nextAlarmMs });
      }
      return result;
    }, nowMs);
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
    return isRecord(body)
      ? this.dispatchAction(new URL(request.url).pathname, body)
      : jsonRes({ error: 'Invalid payload' }, BAD_REQUEST);
  }

  private async dispatchAction(pathname: string, body: Record<string, unknown>): Promise<Response> {
    const { BAD_REQUEST, NOT_FOUND } = APARTMENT_COORDINATOR_HTTP_STATUS;
    const paths = APARTMENT_COORDINATOR_PATHS;
    const pos = (v: unknown, fb: number): number => (typeof v === 'number' && v > 0 ? v : fb);
    const num = (v: unknown): number | undefined => (typeof v === 'number' ? v : undefined);
    if (pathname === paths.LOCK_ACQUIRE) {
      return jsonRes({
        leaseToken: await this.acquireLock(
          pos(body['leaseTtlMs'], DEFAULT_LEASE_TTL_MS),
          num(body['nowMs']),
        ),
      });
    }
    if (pathname === paths.LOCK_RELEASE) {
      return typeof body['leaseToken'] === 'string'
        ? jsonRes({ released: this.releaseLock(body['leaseToken']) })
        : jsonRes({ error: 'Invalid leaseToken' }, BAD_REQUEST);
    }
    if (pathname === paths.SCHEDULE_ORPHAN_PURGE) {
      if (
        typeof body['apartmentId'] !== 'string' ||
        typeof body['orphanDeleteAfterMs'] !== 'number'
      ) {
        return jsonRes({ error: 'Invalid payload' }, BAD_REQUEST);
      }
      await this.scheduleOrphanPurge(body['apartmentId'], body['orphanDeleteAfterMs']);
      return jsonRes({ scheduled: true });
    }
    if (pathname === paths.SCHEDULE_PENDING_CLEANUP) {
      if (typeof body['apartmentId'] !== 'string' || typeof body['runAtMs'] !== 'number') {
        return jsonRes({ error: 'Invalid payload' }, BAD_REQUEST);
      }
      await this.schedulePendingCleanup(
        body['apartmentId'],
        body['runAtMs'],
        pos(body['ttlMs'], DEFAULT_ABANDONED_PENDING_UPLOAD_TTL_MS),
      );
      return jsonRes({ scheduled: true });
    }
    if (pathname === paths.RUN_ALARM) {
      const aptId = typeof body['apartmentId'] === 'string' ? body['apartmentId'] : undefined;
      return jsonRes(await this.runMaintenance(num(body['nowMs']), aptId));
    }
    return jsonRes({ error: 'Not found' }, NOT_FOUND);
  }

  private async updateSchedule(
    apartmentId: string,
    mutate: (prev: CoordinatorPersistedState) => CoordinatorPersistedState,
  ): Promise<void> {
    await this.withLock(async () => {
      const prev =
        (await this.ctx.storage.get<CoordinatorPersistedState>(COORDINATOR_STATE_STORAGE_KEY)) ??
        defaultState(apartmentId);
      await this.saveAndSyncAlarm({ ...mutate(prev), apartmentId });
    });
  }

  private async withLock<T>(operation: () => Promise<T>, nowMs?: number): Promise<T> {
    const token = await this.acquireLock(DEFAULT_LEASE_TTL_MS, nowMs);
    try {
      return await operation();
    } finally {
      this.releaseLock(token);
    }
  }

  private async saveAndSyncAlarm(state: CoordinatorPersistedState): Promise<void> {
    await this.ctx.storage.put(COORDINATOR_STATE_STORAGE_KEY, state);
    const candidates = [state.orphanDeleteAfterMs, state.pendingCleanupAtMs].filter(
      (value): value is number => value !== null,
    );
    if (candidates.length > 0) await this.ctx.storage.setAlarm(Math.min(...candidates));
  }
}
