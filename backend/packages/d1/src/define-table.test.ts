import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { defineTable } from './define-table';

describe('defineTable', () => {
  const userRowSchema = z.object({
    id: z.string(),
    display_name: z.string(),
    created_at: z.string(),
  });

  it('creates an immutable table definition with column helpers', () => {
    const columns = {
      id: 'id',
      displayName: 'display_name',
      createdAt: 'created_at',
    } as const;

    const usersTable = defineTable({
      name: 'users',
      columns,
      rowSchema: userRowSchema,
    });

    expect(usersTable.name).toBe('users');
    expect(usersTable.columns).toEqual({
      id: 'id',
      displayName: 'display_name',
      createdAt: 'created_at',
    });
    expect(usersTable.columnNames).toEqual(['id', 'display_name', 'created_at']);
    expect(usersTable.columnList()).toBe('id, display_name, created_at');
    expect(usersTable.columnList('')).toBe('id, display_name, created_at');
    expect(usersTable.columnList('u')).toBe('u.id, u.display_name, u.created_at');
    expect(usersTable.rowSchema).toBe(userRowSchema);
    expect(Object.isFrozen(usersTable)).toBe(true);
    expect(Object.isFrozen(usersTable.columns)).toBe(true);
    expect(Object.isFrozen(usersTable.columnNames)).toBe(true);
  });

  it('isolates its columns snapshot from mutations to the input object', () => {
    const mutableColumns: Record<string, string> = {
      id: 'id',
      name: 'name',
    };

    const table = defineTable({
      name: 'apartments',
      columns: mutableColumns,
      rowSchema: z.object({ id: z.string(), name: z.string() }),
    });

    mutableColumns['name'] = 'mutated_name';

    expect(table.columns['name']).toBe('name');
    expect(table.columnNames).toEqual(['id', 'name']);
    expect(table.columnList()).toBe('id, name');
  });
});
