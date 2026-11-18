import type { DomainError, Logger, Result } from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';

export interface AuthenticatedUser {
  readonly id: string;
  readonly firebaseUid: string | null;
  readonly displayName: string;
  readonly shortTag: string;
  readonly color: string;
  readonly createdAt: string;
  readonly deletedAt: string | null;
}

export type AuthenticateTokenFn = (
  idToken: string,
) => Promise<Result<AuthenticatedUser, DomainError>>;

export interface HttpContextVariables {
  requestId: string;
  appVersion: string | undefined;
  appConfig: AppConfig;
  logger: Logger;
  authenticateToken?: AuthenticateTokenFn;
  authenticatedUser?: AuthenticatedUser;
}
