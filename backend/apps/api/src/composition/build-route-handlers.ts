import { err, type Clock, type IdGenerator } from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';
import type { ApartmentCommandGateway } from '../durable-objects/apartment-coordinator.types';
import type { MediaCleanupPort } from '../modules/account-deletion';
import {
  createCreateApartmentUseCase,
  createDeleteOrLeaveApartmentUseCase,
  createGetApartmentUseCase,
  createListApartmentChangesUseCase,
  createListMyApartmentsUseCase,
  createResetInviteCodeUseCase,
  createUpdateApartmentUseCase,
  normalizeInviteCode,
  type ApartmentRepository,
  type ApartmentRouteHandlers,
} from '../modules/apartments';
import {
  createCreateEntryUseCase,
  createListMediaEntriesUseCase,
  createRetractEntryUseCase,
  type EntriesRouteHandlers,
  type EntryRepository,
} from '../modules/entries';
import {
  createConfirmMediaUploadUseCase,
  createGetMediaDownloadUrlUseCase,
  createGetMediaUseCase,
  createInitMediaUploadUseCase,
  createListApartmentMediaUseCase,
  createSoftDeleteMediaUseCase,
  verifyLocalStorageSignature,
  type LocalR2BucketLike,
  type LocalStorageHandlers,
  type MediaRepository,
  type MediaRouteHandlers,
  type ObjectStoragePort,
} from '../modules/media';
import {
  createAllowAllInviteRateLimiter,
  createJoinApartmentByCodeUseCase,
  createLeaveApartmentUseCase,
  createListApartmentMembersUseCase,
  createRevokeMemberAccessUseCase,
  inviteCodeInvalidError,
  inviteCodeNotFoundError,
  type InviteCodeRateLimiterPort,
  type MembershipRepository,
  type MembershipRouteHandlers,
} from '../modules/membership';
import {
  createListApartmentChangesFeedUseCase,
  createListMyApartmentsSyncUseCase,
  type SyncRepository,
  type SyncRouteHandlers,
} from '../modules/sync';

export interface BuildModuleHandlersInput {
  readonly appConfig: AppConfig;
  readonly clock: Clock;
  readonly idGenerator: IdGenerator;
  readonly apartmentRepository: ApartmentRepository;
  readonly membershipRepository: MembershipRepository;
  readonly mediaRepository: MediaRepository;
  readonly entryRepository: EntryRepository;
  readonly syncRepository: SyncRepository;
  readonly inviteRateLimiter: InviteCodeRateLimiterPort;
  readonly apartmentGateway: ApartmentCommandGateway;
  readonly objectStorage: ObjectStoragePort;
  readonly mediaCleanup: MediaCleanupPort;
  readonly mediaBucket: LocalR2BucketLike | undefined;
}

export interface ModuleHandlersBundle {
  readonly apartments: ApartmentRouteHandlers;
  readonly membership: MembershipRouteHandlers;
  readonly media: MediaRouteHandlers;
  readonly entries: EntriesRouteHandlers;
  readonly sync: SyncRouteHandlers;
  readonly localStorage: LocalStorageHandlers;
}

function serialize<TCommand extends { readonly apartmentId: string }, TResult>(
  gateway: ApartmentCommandGateway,
  useCase: { execute(command: TCommand): Promise<TResult> },
): { execute(command: TCommand): Promise<TResult> } {
  return {
    execute: (command) =>
      gateway.runSerialized(command.apartmentId, () => useCase.execute(command)),
  };
}

// Architecture A17 & 3.4: Route all per-apartment mutations through ApartmentCommandGateway; keep reads direct to D1.
export function buildModuleRouteHandlers(i: BuildModuleHandlersInput): ModuleHandlersBundle {
  const gw = i.apartmentGateway;
  const joinInner = createJoinApartmentByCodeUseCase({
    membershipRepository: i.membershipRepository,
    inviteRateLimiter: createAllowAllInviteRateLimiter(),
    clock: i.clock,
  });
  const initUploadInner = createInitMediaUploadUseCase({
    mediaRepository: i.mediaRepository,
    objectStorage: i.objectStorage,
    clock: i.clock,
    cloudMediaQuota: i.appConfig.cloudMediaQuotaPerApartment,
    maxBytes: i.appConfig.jpegMaxBytes,
    presignPutTtlMs: i.appConfig.presignPutTtlMs,
  });

  return {
    apartments: {
      createApartment: serialize(gw, createCreateApartmentUseCase(i)),
      listMyApartments: createListMyApartmentsUseCase(i),
      getApartment: createGetApartmentUseCase(i),
      updateApartment: serialize(gw, createUpdateApartmentUseCase(i)),
      resetInviteCode: serialize(gw, createResetInviteCodeUseCase(i)),
      deleteOrLeaveApartment: serialize(gw, createDeleteOrLeaveApartmentUseCase(i)),
      listApartmentChanges: createListApartmentChangesUseCase(i),
    },
    membership: {
      joinApartment: {
        execute: async (cmd) => {
          const rateLimit = await i.inviteRateLimiter.checkAndRecordJoinAttempt(cmd.userId);
          if (!rateLimit.ok) return rateLimit;
          const normalized = normalizeInviteCode(cmd.inviteCode);
          if (!normalized.ok) return err(inviteCodeInvalidError(normalized.error.message));
          const found = await i.membershipRepository.findApartmentByInviteCode(normalized.value);
          if (!found.ok) return found;
          if (found.value === null) return err(inviteCodeNotFoundError());
          return gw.runSerialized(found.value.id, () => joinInner.execute(cmd));
        },
      },
      listMembers: createListApartmentMembersUseCase(i),
      revokeMember: serialize(gw, createRevokeMemberAccessUseCase(i)),
      leaveApartment: serialize(gw, createLeaveApartmentUseCase(i)),
    },
    media: {
      initUpload: {
        execute: async (cmd) => {
          const result = await gw.runSerialized(cmd.apartmentId, () =>
            initUploadInner.execute(cmd),
          );
          if (result.ok) {
            await gw.schedulePendingUploadCleanup(
              cmd.apartmentId,
              i.clock.nowMs() + i.appConfig.abandonedPendingUploadTtlMs,
              i.appConfig.abandonedPendingUploadTtlMs,
            );
          }
          return result;
        },
      },
      confirmUpload: serialize(gw, createConfirmMediaUploadUseCase(i)),
      listMedia: createListApartmentMediaUseCase(i),
      getMedia: createGetMediaUseCase(i),
      getDownloadUrl: createGetMediaDownloadUrlUseCase({
        mediaRepository: i.mediaRepository,
        objectStorage: i.objectStorage,
        presignGetTtlMs: i.appConfig.presignGetTtlMs,
      }),
      softDelete: serialize(gw, createSoftDeleteMediaUseCase(i)),
    },
    entries: {
      createEntry: serialize(gw, createCreateEntryUseCase(i)),
      listEntries: createListMediaEntriesUseCase(i),
      retractEntry: serialize(gw, createRetractEntryUseCase(i)),
    },
    sync: {
      listApartmentChanges: createListApartmentChangesFeedUseCase(i),
      listMyApartmentsSync: createListMyApartmentsSyncUseCase(i),
    },
    localStorage: {
      storageMode: i.appConfig.storageMode,
      bucket: i.mediaBucket,
      clock: i.clock,
      verifySignature: verifyLocalStorageSignature,
    },
  };
}
