import type { Clock, IdGenerator } from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';
import type { MediaCleanupPort } from '../modules/account-deletion';
import {
  createCreateApartmentUseCase,
  createDeleteOrLeaveApartmentUseCase,
  createGetApartmentUseCase,
  createListApartmentChangesUseCase,
  createListMyApartmentsUseCase,
  createResetInviteCodeUseCase,
  createUpdateApartmentUseCase,
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
  createJoinApartmentByCodeUseCase,
  createLeaveApartmentUseCase,
  createListApartmentMembersUseCase,
  createRevokeMemberAccessUseCase,
  type InviteCodeRateLimiterPort,
  type MembershipRepository,
  type MembershipRouteHandlers,
} from '../modules/membership';

export interface BuildModuleHandlersInput {
  readonly appConfig: AppConfig;
  readonly clock: Clock;
  readonly idGenerator: IdGenerator;
  readonly apartmentRepository: ApartmentRepository;
  readonly membershipRepository: MembershipRepository;
  readonly mediaRepository: MediaRepository;
  readonly entryRepository: EntryRepository;
  readonly inviteRateLimiter: InviteCodeRateLimiterPort;
  readonly objectStorage: ObjectStoragePort;
  readonly mediaCleanup: MediaCleanupPort;
  readonly mediaBucket: LocalR2BucketLike | undefined;
}

export interface ModuleHandlersBundle {
  readonly apartments: ApartmentRouteHandlers;
  readonly membership: MembershipRouteHandlers;
  readonly media: MediaRouteHandlers;
  readonly entries: EntriesRouteHandlers;
  readonly localStorage: LocalStorageHandlers;
}

export function buildModuleRouteHandlers(input: BuildModuleHandlersInput): ModuleHandlersBundle {
  const {
    appConfig,
    clock,
    idGenerator,
    apartmentRepository,
    membershipRepository,
    mediaRepository,
    entryRepository,
    inviteRateLimiter,
    objectStorage,
    mediaCleanup,
    mediaBucket,
  } = input;

  return {
    apartments: {
      createApartment: createCreateApartmentUseCase({ apartmentRepository, clock }),
      listMyApartments: createListMyApartmentsUseCase({ apartmentRepository }),
      getApartment: createGetApartmentUseCase({ apartmentRepository }),
      updateApartment: createUpdateApartmentUseCase({ apartmentRepository, clock, idGenerator }),
      resetInviteCode: createResetInviteCodeUseCase({ apartmentRepository, clock }),
      deleteOrLeaveApartment: createDeleteOrLeaveApartmentUseCase({
        apartmentRepository,
        mediaCleanup,
        clock,
      }),
      listApartmentChanges: createListApartmentChangesUseCase({ apartmentRepository }),
    },
    membership: {
      joinApartment: createJoinApartmentByCodeUseCase({
        membershipRepository,
        inviteRateLimiter,
        clock,
      }),
      listMembers: createListApartmentMembersUseCase({ membershipRepository }),
      revokeMember: createRevokeMemberAccessUseCase({ membershipRepository, clock }),
      leaveApartment: createLeaveApartmentUseCase({ membershipRepository, clock }),
    },
    media: {
      initUpload: createInitMediaUploadUseCase({
        mediaRepository,
        objectStorage,
        clock,
        cloudMediaQuota: appConfig.cloudMediaQuotaPerApartment,
        maxBytes: appConfig.jpegMaxBytes,
        presignPutTtlMs: appConfig.presignPutTtlMs,
      }),
      confirmUpload: createConfirmMediaUploadUseCase({ mediaRepository, objectStorage, clock }),
      listMedia: createListApartmentMediaUseCase({ mediaRepository }),
      getMedia: createGetMediaUseCase({ mediaRepository }),
      getDownloadUrl: createGetMediaDownloadUrlUseCase({
        mediaRepository,
        objectStorage,
        presignGetTtlMs: appConfig.presignGetTtlMs,
      }),
      softDelete: createSoftDeleteMediaUseCase({ mediaRepository, clock }),
    },
    entries: {
      createEntry: createCreateEntryUseCase({ entryRepository, clock }),
      listEntries: createListMediaEntriesUseCase({ entryRepository }),
      retractEntry: createRetractEntryUseCase({ entryRepository, clock }),
    },
    localStorage: {
      storageMode: appConfig.storageMode,
      bucket: mediaBucket,
      clock,
      verifySignature: verifyLocalStorageSignature,
    },
  };
}
