import { defineTable, type TableRow } from '@stanmieszkania/d1';
import { z } from 'zod';

export const changeLogRowSchema = z.object({
  seq: z.number().int(),
  apartment_id: z.string(),
  entity_type: z.string(),
  entity_id: z.string(),
  op: z.string(),
  created_at: z.string(),
});

export const CHANGE_LOG_TABLE = defineTable({
  name: 'change_log',
  columns: {
    seq: 'seq',
    apartmentId: 'apartment_id',
    entityType: 'entity_type',
    entityId: 'entity_id',
    op: 'op',
    createdAt: 'created_at',
  },
  rowSchema: changeLogRowSchema,
});

export type ChangeLogRow = TableRow<typeof CHANGE_LOG_TABLE>;
