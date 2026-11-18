import { minutes } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { FixedClock } from './fixed-clock';
import { DEFAULT_FIXED_TIMESTAMP_ISO } from './testing.constants';

describe('FixedClock', () => {
  it('returns deterministic timestamps and supports advanceBy and setNow', () => {
    const clock = new FixedClock(DEFAULT_FIXED_TIMESTAMP_ISO);

    expect(clock.nowIso()).toBe('2026-11-18T12:00:00.000Z');
    expect(clock.now().toISOString()).toBe('2026-11-18T12:00:00.000Z');
    expect(clock.nowMs()).toBe(Date.parse('2026-11-18T12:00:00.000Z'));

    clock.advanceBy(minutes(15));
    expect(clock.nowIso()).toBe('2026-11-18T12:15:00.000Z');

    clock.setNow(new Date('2027-01-01T00:00:00.000Z'));
    expect(clock.nowIso()).toBe('2027-01-01T00:00:00.000Z');
  });

  it('rejects invalid timestamps or non-finite deltas', () => {
    expect(() => new FixedClock('not-a-date')).toThrow(RangeError);

    const clock = new FixedClock();
    expect(() => {
      clock.advanceBy(Number.NaN);
    }).toThrow(RangeError);
    expect(() => {
      clock.setNow('invalid');
    }).toThrow(RangeError);
  });
});
