import { describe, expect, it } from 'vitest';
import { RecordingLogger } from './recording-logger';

describe('RecordingLogger', () => {
  it('records entries across root and child loggers with merged context', () => {
    const root = new RecordingLogger({ requestId: 'req-1' });
    const child = root.child({ userId: 'usr-1' });

    root.debug('boot');
    child.info('media confirmed', { mediaId: 'med-1' });
    child.warn('retry scheduled');
    child.error('upload failed', { reason: 'hash_mismatch' });

    expect(root.entries).toEqual([
      { level: 'debug', message: 'boot', context: { requestId: 'req-1' } },
      {
        level: 'info',
        message: 'media confirmed',
        context: { requestId: 'req-1', userId: 'usr-1', mediaId: 'med-1' },
      },
      {
        level: 'warn',
        message: 'retry scheduled',
        context: { requestId: 'req-1', userId: 'usr-1' },
      },
      {
        level: 'error',
        message: 'upload failed',
        context: { requestId: 'req-1', userId: 'usr-1', reason: 'hash_mismatch' },
      },
    ]);

    expect(root.entriesForLevel('error')).toHaveLength(1);

    root.clear();
    expect(root.entries).toHaveLength(0);
  });
});
