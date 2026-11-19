import { defineTable } from '@stanmieszkania/d1';
import { z } from 'zod';

export const entryRowSchema = z.object({
  id: z.string(),
  media_id: z.string(),
  author_id: z.string(),
  text: z.string(),
  created_at: z.string(),
  server_received_at: z.string(),
  retracted_at: z.string().nullable(),
});

export type EntryRow = z.infer<typeof entryRowSchema>;

export const ENTRIES_TABLE = defineTable({
  name: 'entries',
  columns: {
    id: 'id',
    mediaId: 'media_id',
    authorId: 'author_id',
    text: 'text',
    createdAt: 'created_at',
    serverReceivedAt: 'server_received_at',
    retractedAt: 'retracted_at',
  } as const,
  rowSchema: entryRowSchema,
});
