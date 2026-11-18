import { defineTable, type TableRow } from '@stanmieszkania/d1';
import { z } from 'zod';

export const userRowSchema = z.object({
  id: z.string(),
  firebase_uid: z.string().nullable(),
  display_name: z.string(),
  short_tag: z.string(),
  color: z.string(),
  created_at: z.string(),
  deleted_at: z.string().nullable(),
});

export const USERS_TABLE = defineTable({
  name: 'users',
  columns: {
    id: 'id',
    firebaseUid: 'firebase_uid',
    displayName: 'display_name',
    shortTag: 'short_tag',
    color: 'color',
    createdAt: 'created_at',
    deletedAt: 'deleted_at',
  },
  rowSchema: userRowSchema,
});

export type UserRow = TableRow<typeof USERS_TABLE>;
