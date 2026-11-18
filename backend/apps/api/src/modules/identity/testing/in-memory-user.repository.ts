import { ok, type DomainError, type Result } from '@stanmieszkania/shared';
import { DELETED_USER_DISPLAY_NAME } from '../domain/identity.constants';
import type { User } from '../domain/user.entity';
import type { UserRepository } from '../domain/user.repository';

export class InMemoryUserRepository implements UserRepository {
  private readonly users = new Map<string, User>();

  seed(user: User): void {
    this.users.set(user.id, user);
  }

  getAll(): readonly User[] {
    return Array.from(this.users.values());
  }

  findById(id: string): Promise<Result<User | null, DomainError>> {
    return Promise.resolve(ok(this.users.get(id) ?? null));
  }

  findByFirebaseUid(firebaseUid: string): Promise<Result<User | null, DomainError>> {
    for (const user of this.users.values()) {
      if (user.firebaseUid === firebaseUid) {
        return Promise.resolve(ok(user));
      }
    }
    return Promise.resolve(ok(null));
  }

  insert(user: User): Promise<Result<void, DomainError>> {
    this.users.set(user.id, user);
    return Promise.resolve(ok(undefined));
  }

  updateDisplayName(id: string, displayName: string): Promise<Result<void, DomainError>> {
    const existing = this.users.get(id);
    if (existing !== undefined && existing.deletedAt === null) {
      this.users.set(id, { ...existing, displayName });
    }
    return Promise.resolve(ok(undefined));
  }

  anonymize(id: string, deletedAt: string): Promise<Result<void, DomainError>> {
    const existing = this.users.get(id);
    if (existing !== undefined && existing.deletedAt === null) {
      this.users.set(id, {
        ...existing,
        firebaseUid: null,
        displayName: DELETED_USER_DISPLAY_NAME,
        deletedAt,
      });
    }
    return Promise.resolve(ok(undefined));
  }
}
