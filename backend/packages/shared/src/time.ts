import { MS_PER_DAY, MS_PER_HOUR, MS_PER_MINUTE, MS_PER_SECOND } from './time.constants';

export interface Clock {
  now(): Date;
  nowMs(): number;
  nowIso(): string;
}

export const systemClock: Clock = {
  now: () => new Date(),
  nowMs: () => Date.now(),
  nowIso: () => new Date().toISOString(),
};

export function seconds(count: number): number {
  return count * MS_PER_SECOND;
}

export function minutes(count: number): number {
  return count * MS_PER_MINUTE;
}

export function hours(count: number): number {
  return count * MS_PER_HOUR;
}

export function days(count: number): number {
  return count * MS_PER_DAY;
}

export function toSeconds(milliseconds: number): number {
  return milliseconds / MS_PER_SECOND;
}
