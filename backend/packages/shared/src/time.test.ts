import { describe, expect, it } from 'vitest';
import { days, hours, minutes, seconds, systemClock, toSeconds } from './time';

describe('time helpers', () => {
  it('converts duration units to milliseconds and back to seconds', () => {
    expect(seconds(5)).toBe(5_000);
    expect(minutes(15)).toBe(900_000);
    expect(hours(2)).toBe(7_200_000);
    expect(days(7)).toBe(604_800_000);
    expect(toSeconds(minutes(3))).toBe(180);
  });

  it('provides coherent Date, ms, and ISO string from systemClock', () => {
    const before = Date.now();
    const nowDate = systemClock.now();
    const nowMs = systemClock.nowMs();
    const nowIso = systemClock.nowIso();
    const after = Date.now();

    expect(nowDate.getTime()).toBeGreaterThanOrEqual(before);
    expect(nowDate.getTime()).toBeLessThanOrEqual(after);
    expect(nowMs).toBeGreaterThanOrEqual(before);
    expect(nowMs).toBeLessThanOrEqual(after);
    expect(Date.parse(nowIso)).toBeGreaterThanOrEqual(before);
    expect(Date.parse(nowIso)).toBeLessThanOrEqual(after);
  });
});
