import { defineTable, type TableRow } from '@stanmieszkania/d1';
import { z } from 'zod';

export const apartmentRowSchema = z.object({
  id: z.string(),
  owner_id: z.string(),
  name: z.string(),
  street: z.string(),
  city: z.string(),
  invite_code: z.string(),
  invite_code_rotated_at: z.string().nullable(),
  cloud_media_count: z.number().int(),
  orphan_delete_after: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  deleted_at: z.string().nullable(),
});

export const APARTMENTS_TABLE = defineTable({
  name: 'apartments',
  columns: {
    id: 'id',
    ownerId: 'owner_id',
    name: 'name',
    street: 'street',
    city: 'city',
    inviteCode: 'invite_code',
    inviteCodeRotatedAt: 'invite_code_rotated_at',
    cloudMediaCount: 'cloud_media_count',
    orphanDeleteAfter: 'orphan_delete_after',
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    deletedAt: 'deleted_at',
  },
  rowSchema: apartmentRowSchema,
});

export type ApartmentRow = TableRow<typeof APARTMENTS_TABLE>;
