import { describe, expect, it } from 'vitest';
import { createJsonLogger, type LogLevel } from './logger';
import { type Clock } from './time';

const fixedClock: Clock = {
  now: () => new Date('2026-11-18T12:00:00.000Z'),
  nowMs: () => Date.parse('2026-11-18T12:00:00.000Z'),
  nowIso: () => '2026-11-18T12:00:00.000Z',
};

describe('createJsonLogger', () => {
  it('emits structured JSON lines and inherits child context without mutating parent', () => {
    const emitted: Array<{ level: LogLevel; parsed: Record<string, unknown> }> = [];
    const rootLogger = createJsonLogger({
      baseContext: { requestId: 'req-1' },
      minLevel: 'debug',
      clock: fixedClock,
      write: (level, line) => {
        emitted.push({
          level,
          parsed: JSON.parse(line) as Record<string, unknown>, // reason: parsing serialized JSON test output
        });
      },
    });

    const childLogger = rootLogger.child({ userId: 'usr-1', apartmentId: 'apt-1' });
    childLogger.info('media uploaded', { mediaId: 'med-1' });
    rootLogger.warn('quota warning');

    expect(emitted).toEqual([
      {
        level: 'info',
        parsed: {
          timestamp: '2026-11-18T12:00:00.000Z',
          level: 'info',
          message: 'media uploaded',
          requestId: 'req-1',
          userId: 'usr-1',
          apartmentId: 'apt-1',
          mediaId: 'med-1',
        },
      },
      {
        level: 'warn',
        parsed: {
          timestamp: '2026-11-18T12:00:00.000Z',
          level: 'warn',
          message: 'quota warning',
          requestId: 'req-1',
        },
      },
    ]);
  });

  it('filters out logs below minLevel', () => {
    const lines: string[] = [];
    const logger = createJsonLogger({
      minLevel: 'warn',
      clock: fixedClock,
      write: (_level, line) => {
        lines.push(line);
      },
    });

    logger.debug('ignored debug');
    logger.info('ignored info');
    logger.warn('kept warn');
    logger.error('kept error');

    expect(lines).toHaveLength(2);
  });
});
