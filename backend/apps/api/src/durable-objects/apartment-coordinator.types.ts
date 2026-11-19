import type { DurableObjectId } from '@cloudflare/workers-types';
import type {
  UserGuardR2BucketLike,
  UserGuardResponseLike,
  UserGuardStorageLike,
} from './user-guard.types';

export interface CoordinatorD1MetaLike {
  readonly changes: number;
}

export interface CoordinatorD1ResultLike<T = Record<string, unknown>> {
  readonly results: readonly T[];
  readonly meta: CoordinatorD1MetaLike;
}

export interface CoordinatorD1PreparedStatementLike<TSelf = unknown> {
  bind(...values: unknown[]): TSelf;
  all<T = Record<string, unknown>>(): Promise<CoordinatorD1ResultLike<T>>;
  run<T = Record<string, unknown>>(): Promise<CoordinatorD1ResultLike<T>>;
}

export interface CoordinatorD1DatabaseLike<
  TStatement extends CoordinatorD1PreparedStatementLike<TStatement> =
    CoordinatorD1PreparedStatementLike<never>,
> {
  prepare(query: string): TStatement;
  batch<T = unknown>(statements: TStatement[]): Promise<CoordinatorD1ResultLike<T>[]>;
}

export interface ApartmentCoordinatorStateLike {
  readonly storage: UserGuardStorageLike;
}

export interface ApartmentCoordinatorEnv<
  TStatement extends CoordinatorD1PreparedStatementLike<TStatement> =
    CoordinatorD1PreparedStatementLike<never>,
> {
  readonly DB?: CoordinatorD1DatabaseLike<TStatement>;
  readonly MEDIA_BUCKET?: UserGuardR2BucketLike;
}

export interface ApartmentCoordinatorStubLike {
  fetch(
    input: string,
    init?: {
      readonly method?: string;
      readonly headers?: Record<string, string>;
      readonly body?: string;
    },
  ): Promise<UserGuardResponseLike>;
}

export interface ApartmentCoordinatorNamespaceLike {
  idFromName(name: string): DurableObjectId;
  get(id: DurableObjectId): ApartmentCoordinatorStubLike;
}

export interface CoordinatorPersistedState {
  readonly apartmentId: string;
  readonly orphanDeleteAfterMs: number | null;
  readonly pendingCleanupAtMs: number | null;
  readonly abandonedPendingUploadTtlMs: number;
}

export interface MaintenanceRunResult {
  readonly apartmentPurged: boolean;
  readonly cleanedPendingMediaCount: number;
  readonly nextAlarmMs: number | null;
}

export interface ApartmentCommandGateway {
  runSerialized<T>(apartmentId: string, operation: () => Promise<T>): Promise<T>;
  scheduleOrphanPurge(apartmentId: string, orphanDeleteAfterMs: number): Promise<void>;
  schedulePendingUploadCleanup(apartmentId: string, runAtMs: number, ttlMs: number): Promise<void>;
  runMaintenanceNow(apartmentId: string, nowMs: number): Promise<MaintenanceRunResult>;
}
