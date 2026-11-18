import { days } from '@stanmieszkania/shared';
import { ORPHAN_APARTMENT_RETENTION_DAYS } from './apartments.constants';

export interface ActiveContributor {
  readonly userId: string;
  readonly joinedAt: string;
}

export type OwnerDepartureTrigger = 'owner_delete_or_leave' | 'account_deletion';

export interface ResolveOwnerDepartureInput {
  readonly activeContributors: readonly ActiveContributor[];
  readonly hasSharedHistory: boolean;
  readonly trigger: OwnerDepartureTrigger;
  readonly nowMs: number;
}

export type OwnerDepartureResolution =
  | { readonly action: 'transfer'; readonly newOwnerId: string }
  | { readonly action: 'hard_delete' }
  | { readonly action: 'schedule_orphan_delete'; readonly orphanDeleteAfter: string };

function compareContributors(left: ActiveContributor, right: ActiveContributor): number {
  const joinedDiff = Date.parse(left.joinedAt) - Date.parse(right.joinedAt);
  if (joinedDiff !== 0) {
    return joinedDiff < 0 ? -1 : 1;
  }
  if (left.userId === right.userId) {
    return 0;
  }
  return left.userId < right.userId ? -1 : 1;
}

// Decision Q5 & S2-9: Transfer ownership to oldest contributor, hard-delete, or schedule orphan purge.
export function resolveOwnerDeparture(input: ResolveOwnerDepartureInput): OwnerDepartureResolution {
  const [oldest] = [...input.activeContributors].sort(compareContributors);
  if (oldest !== undefined) {
    return {
      action: 'transfer',
      newOwnerId: oldest.userId,
    };
  }

  if (input.trigger === 'owner_delete_or_leave' || !input.hasSharedHistory) {
    return { action: 'hard_delete' };
  }

  return {
    action: 'schedule_orphan_delete',
    orphanDeleteAfter: new Date(input.nowMs + days(ORPHAN_APARTMENT_RETENTION_DAYS)).toISOString(),
  };
}
