import type { DomainError, Result } from '@stanmieszkania/shared';
import type { User } from './user.entity';

export interface UserRepository {
  findById(id: string): Promise<Result<User | null, DomainError>>;
  findByFirebaseUid(firebaseUid: string): Promise<Result<User | null, DomainError>>;
  insert(user: User): Promise<Result<void, DomainError>>;
  updateDisplayName(id: string, displayName: string): Promise<Result<void, DomainError>>;
  anonymize(id: string, deletedAt: string): Promise<Result<void, DomainError>>;
}
