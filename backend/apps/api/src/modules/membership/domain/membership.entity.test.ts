import { describe, expect, it } from 'vitest';
import { isActiveMembership, type Membership } from './membership.entity';

describe('membership.entity', () => {
  it('treats null leftAt as active and non-null leftAt as inactive', () => {
    const active: Membership = {
      apartmentId: 'apt-1',
      userId: 'usr-1',
      role: 'contributor',
      joinedAt: '2026-11-18T12:00:00.000Z',
      leftAt: null,
    };
    const left: Membership = {
      ...active,
      leftAt: '2026-11-18T13:00:00.000Z',
    };

    expect(isActiveMembership(active)).toBe(true);
    expect(isActiveMembership(left)).toBe(false);
  });
});
