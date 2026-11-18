import type { D1Database } from '@cloudflare/workers-types';
import type { Clock, IdGenerator, Logger } from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';
import type {
  UserGuardNamespaceLike,
  UserGuardR2BucketLike,
} from '../durable-objects/user-guard.types';
import type { HttpContextVariables } from '../http/http-env';
import type {
  AccountDeletionRepository,
  AppleTokenRevokerPort,
  DeleteMyAccountUseCase,
  IdentityProviderDeleterPort,
  MediaCleanupPort,
} from '../modules/account-deletion';
import type { ApartmentRepository, ApartmentRouteHandlers } from '../modules/apartments';
import type {
  AuthenticateUserUseCase,
  TokenVerifierPort,
  UpdateDisplayNameUseCase,
  UserRepository,
} from '../modules/identity';
import type {
  InviteCodeRateLimiterPort,
  MembershipRepository,
  MembershipRouteHandlers,
} from '../modules/membership';

export interface AppBindings {
  readonly DB: D1Database;
  readonly MEDIA_BUCKET?: UserGuardR2BucketLike;
  readonly USER_GUARD?: UserGuardNamespaceLike;
  readonly CLOUD_MEDIA_QUOTA_PER_APARTMENT?: string;
  readonly PRESIGN_PUT_TTL_SECONDS?: string;
  readonly PRESIGN_GET_TTL_SECONDS?: string;
  readonly INVITE_CODE_RATE_LIMIT_MAX_ATTEMPTS?: string;
  readonly INVITE_CODE_RATE_LIMIT_WINDOW_SECONDS?: string;
  readonly JPEG_MAX_DIMENSION_PX?: string;
  readonly JPEG_QUALITY?: string;
  readonly JPEG_MAX_BYTES?: string;
  readonly MIN_SUPPORTED_APP_VERSION?: string;
  readonly AUTH_MODE?: string;
  readonly STORAGE_MODE?: string;
  readonly FIREBASE_PROJECT_ID?: string;
}

export interface RequestContainer {
  readonly clock: Clock;
  readonly idGenerator: IdGenerator;
  readonly appConfig: AppConfig;
  readonly logger: Logger;
  readonly userRepository: UserRepository;
  readonly apartmentRepository: ApartmentRepository;
  readonly membershipRepository: MembershipRepository;
  readonly accountDeletionRepository: AccountDeletionRepository;
  readonly inviteRateLimiter: InviteCodeRateLimiterPort;
  readonly mediaCleanup: MediaCleanupPort;
  readonly appleTokenRevoker: AppleTokenRevokerPort;
  readonly identityProviderDeleter: IdentityProviderDeleterPort;
  readonly tokenVerifier: TokenVerifierPort;
  readonly authenticateUser: AuthenticateUserUseCase;
  readonly updateDisplayName: UpdateDisplayNameUseCase;
  readonly deleteMyAccount: DeleteMyAccountUseCase;
  readonly apartments: ApartmentRouteHandlers;
  readonly membership: MembershipRouteHandlers;
}

export interface AppVariables extends HttpContextVariables {
  container: RequestContainer;
}

export interface AppHonoEnv {
  Bindings: AppBindings;
  Variables: AppVariables;
}
