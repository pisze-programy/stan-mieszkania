import { defineTable, type TableRow } from '@stanmieszkania/d1';
import { z } from 'zod';
import { APARTMENT_CHANGE_FIELDS } from '../domain/apartments.constants';

export const apartmentChangeRowSchema = z.object({
  id: z.string(),
  apartment_id: z.string(),
  author_id: z.string(),
  field: z.enum([
    APARTMENT_CHANGE_FIELDS.NAME,
    APARTMENT_CHANGE_FIELDS.STREET,
    APARTMENT_CHANGE_FIELDS.CITY,
  ]),
  old_value: z.string(),
  new_value: z.string(),
  created_at: z.string(),
});

export const APARTMENT_CHANGES_TABLE = defineTable({
  name: 'apartment_changes',
  columns: {
    id: 'id',
    apartmentId: 'apartment_id',
    authorId: 'author_id',
    field: 'field',
    oldValue: 'old_value',
    newValue: 'new_value',
    createdAt: 'created_at',
  },
  rowSchema: apartmentChangeRowSchema,
});

export type ApartmentChangeRow = TableRow<typeof APARTMENT_CHANGES_TABLE>;
