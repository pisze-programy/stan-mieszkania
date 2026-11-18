import { ok } from '@stanmieszkania/shared';
import type {
  AccountDeletionRepository,
  LeaveApartmentAsContributorParams,
  ScheduleOrphanDeleteParams,
  TransferApartmentOwnershipParams,
  UserApartmentContext,
} from '../domain/account-deletion.repository';
import type {
  AppleTokenRevokerPort,
  IdentityProviderDeleterPort,
  MediaCleanupPort,
} from '../domain/external-auth-cleanup.port';

export class InMemoryAccountDeletionRepository implements AccountDeletionRepository {
  readonly hardDeletedApartmentIds: string[] = [];
  readonly transfers: TransferApartmentOwnershipParams[] = [];
  readonly orphanSchedules: ScheduleOrphanDeleteParams[] = [];
  readonly contributorDepartures: LeaveApartmentAsContributorParams[] = [];
  readonly anonymizedUsers: {
    readonly userId: string;
    readonly displayName: string;
    readonly deletedAt: string;
  }[] = [];

  private readonly contextsByUserId: Map<string, readonly UserApartmentContext[]>;

  constructor(initial: Readonly<Record<string, readonly UserApartmentContext[]>> = {}) {
    this.contextsByUserId = new Map(Object.entries(initial));
  }

  listUserApartments(userId: string) {
    return Promise.resolve(ok(this.contextsByUserId.get(userId) ?? []));
  }

  hardDeletePrivateApartment(apartmentId: string) {
    this.hardDeletedApartmentIds.push(apartmentId);
    return Promise.resolve(ok());
  }

  transferOwnershipAndLeave(params: TransferApartmentOwnershipParams) {
    this.transfers.push(params);
    return Promise.resolve(ok());
  }

  scheduleOrphanDeleteAndLeave(params: ScheduleOrphanDeleteParams) {
    this.orphanSchedules.push(params);
    return Promise.resolve(ok());
  }

  leaveAsContributor(params: LeaveApartmentAsContributorParams) {
    this.contributorDepartures.push(params);
    return Promise.resolve(ok());
  }

  anonymizeUserPreservingUid(userId: string, displayName: string, deletedAt: string) {
    this.anonymizedUsers.push({ userId, displayName, deletedAt });
    return Promise.resolve(ok());
  }
}

export class RecordingAppleTokenRevoker implements AppleTokenRevokerPort {
  readonly revokedCodes: string[] = [];

  revokeAuthorizationCode(authorizationCode: string) {
    this.revokedCodes.push(authorizationCode);
    return Promise.resolve(ok());
  }
}

export class RecordingIdentityProviderDeleter implements IdentityProviderDeleterPort {
  readonly deletedFirebaseUids: string[] = [];

  deleteProviderUser(firebaseUid: string) {
    this.deletedFirebaseUids.push(firebaseUid);
    return Promise.resolve(ok());
  }
}

export class RecordingMediaCleanup implements MediaCleanupPort {
  readonly batches: { readonly userId: string; readonly r2Keys: readonly string[] }[] = [];

  deletePrivateMediaObjects(userId: string, r2Keys: readonly string[]) {
    this.batches.push({ userId, r2Keys: [...r2Keys] });
    return Promise.resolve(ok());
  }
}
