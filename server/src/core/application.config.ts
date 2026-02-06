import type { ApplicationLog } from '../schema/application-log.type';

export const applicationConfig: Exclude<ApplicationLog, 'sessionId'> = {
  name: 'logger-server',
  version: '1.0.0',
}