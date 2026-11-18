import {
  SystemUuidV7Generator,
  createJsonLogger,
  systemClock,
  type Clock,
  type IdGenerator,
  type Logger,
} from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';
import type { RequestContainer } from './hono-variables';

export interface RequestContainerOverrides {
  readonly clock?: Clock;
  readonly idGenerator?: IdGenerator;
  readonly logger?: Logger;
}

export interface CreateRequestContainerInput {
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

  return {
    clock,
    idGenerator,
    appConfig: input.appConfig,
    logger: baseLogger.child({ requestId: input.requestId }),
  };
}
