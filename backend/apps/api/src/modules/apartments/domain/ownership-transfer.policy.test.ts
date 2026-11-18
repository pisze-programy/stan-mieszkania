import { days } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { ORPHAN_APARTMENT_RETENTION_DAYS } from './apartments.constants';
import { resolveOwnerDeparture } from './ownership-transfer.policy';

describe('resolveOwnerDeparture policy (Q5 & S2-9)', () => {
  const nowMs = Date.parse('2026-11-18T12:00:00.000Z');

  it('transfers ownership to the oldest active contributor with deterministic userId tie-break', () => {
    const resolution = resolveOwnerDeparture({
      activeContributors: [
        { userId: 'usr-c', joinedAt: '2026-11-18T11:00:00.000Z' },
        { userId: 'usr-b', joinedAt: '2026-11-18T10:00:00.000Z' },
        { userId: 'usr-a', joinedAt: '2026-11-18T10:00:00.000Z' },
      ],
      hasSharedHistory: true,
      trigger: 'owner_delete_or_leave',
      nowMs,
    });

    expect(resolution).toEqual({
      action: 'transfer',
      newOwnerId: 'usr-a',
    });
  });

  it('hard-deletes when no contributors exist on owner_delete_or_leave or private account_deletion', () => {
    expect(
      resolveOwnerDeparture({
        activeContributors: [],
        hasSharedHistory: true,
        trigger: 'owner_delete_or_leave',
        nowMs,
      }),
    ).toEqual({ action: 'hard_delete' });

    expect(
      resolveOwnerDeparture({
        activeContributors: [],
        hasSharedHistory: false,
        trigger: 'account_deletion',
        nowMs,
      }),
    ).toEqual({ action: 'hard_delete' });
  });

  it('schedules 30-day orphan deletion on account_deletion when shared history exists without active contributors', () => {
    const resolution = resolveOwnerDeparture({
      activeContributors: [],
      hasSharedHistory: true,
      trigger: 'account_deletion',
      nowMs,
    });

    expect(resolution).toEqual({
      action: 'schedule_orphan_delete',
      orphanDeleteAfter: new Date(nowMs + days(ORPHAN_APARTMENT_RETENTION_DAYS)).toISOString(),
    });
  });
});
