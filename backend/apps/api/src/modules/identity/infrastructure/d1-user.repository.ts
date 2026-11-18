import { execute, queryFirst, type D1Queryable } from '@stanmieszkania/d1';
import { mapResult } from '@stanmieszkania/shared';
import type { UserRepository } from '../domain/user.repository';
import { mapUserEntityToRow, mapUserRowToEntity } from './user-row.mapper';
import {
  anonymizeUserStatement,
  findUserByFirebaseUidStatement,
  findUserByIdStatement,
  insertUserStatement,
  updateUserDisplayNameStatement,
} from './users.queries';
import { USERS_TABLE } from './users.table';

export function createD1UserRepository(db: D1Queryable): UserRepository {
  return {
    findById: async (id) => {
      const result = await queryFirst(db, findUserByIdStatement(id), USERS_TABLE.rowSchema);
      return mapResult(result, (row) => (row === null ? null : mapUserRowToEntity(row)));
    },
    findByFirebaseUid: async (firebaseUid) => {
      const result = await queryFirst(
        db,
        findUserByFirebaseUidStatement(firebaseUid),
        USERS_TABLE.rowSchema,
      );
      return mapResult(result, (row) => (row === null ? null : mapUserRowToEntity(row)));
    },
    insert: async (user) => {
      const result = await execute(db, insertUserStatement(mapUserEntityToRow(user)));
      return mapResult(result, () => undefined);
    },
    updateDisplayName: async (id, displayName) => {
      const result = await execute(db, updateUserDisplayNameStatement(id, displayName));
      return mapResult(result, () => undefined);
    },
    anonymize: async (id, deletedAt) => {
      const result = await execute(db, anonymizeUserStatement(id, deletedAt));
      return mapResult(result, () => undefined);
    },
  };
}
