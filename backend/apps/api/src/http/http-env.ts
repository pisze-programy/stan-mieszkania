import type { AppConfig } from '../config/app-config';

export interface HttpContextVariables {
  requestId: string;
  appVersion: string | undefined;
  appConfig: AppConfig;
}
