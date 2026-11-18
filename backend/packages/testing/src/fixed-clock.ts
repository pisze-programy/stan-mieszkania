import type { Clock } from '@stanmieszkania/shared';
import { DEFAULT_FIXED_TIMESTAMP_MS } from './testing.constants';

function parseTimestampMs(input: Date | number | string): number {
  const ms =
    input instanceof Date ? input.getTime() : typeof input === 'number' ? input : Date.parse(input);
  if (!Number.isFinite(ms)) {
    throw new RangeError(`Invalid FixedClock timestamp: ${String(input)}`);
  }
  return ms;
}

export class FixedClock implements Clock {
  private currentMs: number;

  constructor(initial: Date | number | string = DEFAULT_FIXED_TIMESTAMP_MS) {
    this.currentMs = parseTimestampMs(initial);
  }

  now(): Date {
    return new Date(this.currentMs);
  }

  nowMs(): number {
    return this.currentMs;
  }

  nowIso(): string {
    return new Date(this.currentMs).toISOString();
  }

  advanceBy(milliseconds: number): void {
    if (!Number.isFinite(milliseconds)) {
      throw new RangeError(`Invalid FixedClock delta: ${String(milliseconds)}`);
    }
    this.currentMs += milliseconds;
  }

  setNow(dateOrIso: Date | number | string): void {
    this.currentMs = parseTimestampMs(dateOrIso);
  }
}
