import type { R2Bucket } from '@cloudflare/workers-types';
import type { D1Queryable } from '@stanmieszkania/d1';
import type { Clock, IdGenerator, Logger } from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';
import type { HttpContextVariables } from '../http/http-env';
import type {
  AuthenticateUserUseCase,
  TokenVerifierPort,
  UpdateDisplayNameUseCase,
  UserRepository,
} from '../modules/identity';

export interface AppBindings {
  readonly DB: D1Queryable;
  readonly MEDIA_BUCKET: R2Bucket;
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
  readonly tokenVerifier: TokenVerifierPort;
  readonly authenticateUser: AuthenticateUserUseCase;
  readonly updateDisplayName: UpdateDisplayNameUseCase;
}

export interface AppVariables extends HttpContextVariables {
  container: RequestContainer;
}

export interface AppHonoEnv {
  Bindings: AppBindings;
  Variables: AppVariables;
}
