import { defineTable } from '@stanmieszkania/d1';
import { z } from 'zod';

export const markerRowSchema = z.object({
  id: z.string(),
  entry_id: z.string(),
  media_id: z.string(),
  number: z.number().int(),
  x: z.number(),
  y: z.number(),
});

export type MarkerRow = z.infer<typeof markerRowSchema>;

export const MARKERS_TABLE = defineTable({
  name: 'markers',
  columns: {
    id: 'id',
    entryId: 'entry_id',
    mediaId: 'media_id',
    number: 'number',
    x: 'x',
    y: 'y',
  } as const,
  rowSchema: markerRowSchema,
});
