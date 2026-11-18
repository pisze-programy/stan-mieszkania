import { defineTable, type TableRow } from '@stanmieszkania/d1';
import { z } from 'zod';
import { MEMBERSHIP_ROLES } from '../domain/membership.constants';

export const membershipRowSchema = z.object({
  apartment_id: z.string(),
  user_id: z.string(),
  role: z.enum([MEMBERSHIP_ROLES.OWNER, MEMBERSHIP_ROLES.CONTRIBUTOR]),
  joined_at: z.string(),
  left_at: z.string().nullable(),
});

export const MEMBERSHIPS_TABLE = defineTable({
  name: 'memberships',
  columns: {
    apartmentId: 'apartment_id',
    userId: 'user_id',
    role: 'role',
    joinedAt: 'joined_at',
    leftAt: 'left_at',
  },
  rowSchema: membershipRowSchema,
});

export type MembershipRow = TableRow<typeof MEMBERSHIPS_TABLE>;
