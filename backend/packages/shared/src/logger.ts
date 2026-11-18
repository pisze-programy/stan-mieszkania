import { LOG_LEVEL_PRIORITY } from './logger.constants';
import { systemClock, type Clock } from './time';

export type LogLevel = keyof typeof LOG_LEVEL_PRIORITY;

export interface LogContext {
  readonly requestId?: string;
  readonly userId?: string;
  readonly apartmentId?: string;
  readonly [key: string]: unknown;
}

export interface Logger {
  debug(message: string, context?: LogContext): void;
  info(message: string, context?: LogContext): void;
  warn(message: string, context?: LogContext): void;
  error(message: string, context?: LogContext): void;
  child(context: LogContext): Logger;
}

export interface JsonLoggerOptions {
  readonly baseContext?: LogContext;
  readonly minLevel?: LogLevel;
  readonly clock?: Clock;
  readonly write?: (level: LogLevel, line: string) => void;
}

function defaultWrite(level: LogLevel, line: string): void {
  if (level === 'error') {
    console.error(line);
    return;
  }
  if (level === 'warn') {
    console.warn(line);
    return;
  }
  console.log(line);
}

export function createJsonLogger(options: JsonLoggerOptions = {}): Logger {
  const baseContext: LogContext = options.baseContext ?? {};
  const minLevel: LogLevel = options.minLevel ?? 'info';
  const clock: Clock = options.clock ?? systemClock;
  const write = options.write ?? defaultWrite;
  const minPriority = LOG_LEVEL_PRIORITY[minLevel];

  const log = (level: LogLevel, message: string, context?: LogContext): void => {
    if (LOG_LEVEL_PRIORITY[level] < minPriority) {
      return;
    }

    const record: Record<string, unknown> = {
      ...baseContext,
      ...(context ?? {}),
      timestamp: clock.nowIso(),
      level,
      message,
    };
    write(level, JSON.stringify(record));
  };

  return {
    debug: (message, context) => {
      log('debug', message, context);
    },
    info: (message, context) => {
      log('info', message, context);
    },
    warn: (message, context) => {
      log('warn', message, context);
    },
    error: (message, context) => {
      log('error', message, context);
    },
    child: (childContext) =>
      createJsonLogger({
        baseContext: { ...baseContext, ...childContext },
        minLevel,
        clock,
        write,
      }),
  };
}
