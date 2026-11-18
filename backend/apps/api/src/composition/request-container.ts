import type { D1Queryable } from '@stanmieszkania/d1';
import {
  SystemUuidV7Generator,
  createJsonLogger,
  systemClock,
  type Clock,
  type IdGenerator,
  type Logger,
} from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';
import {
  createAuthenticateUserUseCase,
  createD1UserRepository,
  createFailClosedTokenVerifier,
  createLocalDevTokenVerifier,
  createUpdateDisplayNameUseCase,
  type TokenVerifierPort,
  type UserRepository,
} from '../modules/identity';
import type { RequestContainer } from './hono-variables';

export interface RequestContainerOverrides {
  readonly clock?: Clock;
  readonly idGenerator?: IdGenerator;
  readonly logger?: Logger;
  readonly userRepository?: UserRepository;
  readonly tokenVerifier?: TokenVerifierPort;
}

export interface CreateRequestContainerInput {
  readonly db: D1Queryable;
  readonly appConfig: AppConfig;
  readonly requestId: string;
  readonly overrides?: RequestContainerOverrides;
}

export function createRequestContainer(input: CreateRequestContainerInput): RequestContainer {
  const clock = input.overrides?.clock ?? systemClock;
  const idGenerator = input.overrides?.idGenerator ?? new SystemUuidV7Generator();
  const baseLogger =
    input.overrides?.logger ??
    createJsonLogger({
      clock,
    });

  const userRepository = input.overrides?.userRepository ?? createD1UserRepository(input.db);
  const tokenVerifier =
    input.overrides?.tokenVerifier ??
    (input.appConfig.authMode === 'local'
      ? createLocalDevTokenVerifier()
      : createFailClosedTokenVerifier());

  const authenticateUser = createAuthenticateUserUseCase({
    tokenVerifier,
    userRepository,
    idGenerator,
    clock,
  });

  const updateDisplayName = createUpdateDisplayNameUseCase({
    userRepository,
  });

  return {
    clock,
    idGenerator,
    appConfig: input.appConfig,
    logger: baseLogger.child({ requestId: input.requestId }),
    userRepository,
    tokenVerifier,
    authenticateUser,
    updateDisplayName,
  };
}
