import type { LogContext, Logger, LogLevel } from '@stanmieszkania/shared';

export interface RecordedLogEntry {
  readonly level: LogLevel;
  readonly message: string;
  readonly context: LogContext;
}

export class RecordingLogger implements Logger {
  private readonly store: RecordedLogEntry[];
  private readonly baseContext: LogContext;

  constructor(baseContext: LogContext = {}, sharedStore: RecordedLogEntry[] = []) {
    this.baseContext = baseContext;
    this.store = sharedStore;
  }

  get entries(): readonly RecordedLogEntry[] {
    return this.store;
  }

  entriesForLevel(level: LogLevel): readonly RecordedLogEntry[] {
    return this.store.filter((entry) => entry.level === level);
  }

  clear(): void {
    this.store.length = 0;
  }

  debug(message: string, context?: LogContext): void {
    this.record('debug', message, context);
  }

  info(message: string, context?: LogContext): void {
    this.record('info', message, context);
  }

  warn(message: string, context?: LogContext): void {
    this.record('warn', message, context);
  }

  error(message: string, context?: LogContext): void {
    this.record('error', message, context);
  }

  child(context: LogContext): Logger {
    return new RecordingLogger({ ...this.baseContext, ...context }, this.store);
  }

  private record(level: LogLevel, message: string, context?: LogContext): void {
    this.store.push({
      level,
      message,
      context: { ...this.baseContext, ...(context ?? {}) },
    });
  }
}
