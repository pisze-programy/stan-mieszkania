import { generateUuidV7, type IdGenerator } from '@stanmieszkania/shared';
import {
  BYTE_RADIX,
  COUNTER_MIN_BYTE_INDEX,
  COUNTER_START,
  DEFAULT_FIXED_TIMESTAMP_MS,
  LAST_UUID_BYTE_INDEX,
  UUID_BYTES,
} from './testing.constants';

export interface SequentialUuidV7GeneratorOptions {
  readonly timestampMs?: number;
  readonly stepMs?: number;
  readonly startCounter?: number;
}

export class SequentialUuidV7Generator implements IdGenerator {
  private currentTimestampMs: number;
  private readonly stepMs: number;
  private counter: number;

  constructor(options: SequentialUuidV7GeneratorOptions = {}) {
    this.currentTimestampMs = options.timestampMs ?? DEFAULT_FIXED_TIMESTAMP_MS;
    this.stepMs = options.stepMs ?? 0;
    this.counter = options.startCounter ?? COUNTER_START;
  }

  nextId(): string {
    const randomBytes = new Uint8Array(UUID_BYTES);
    let remaining = this.counter;

    for (
      let index = LAST_UUID_BYTE_INDEX;
      index >= COUNTER_MIN_BYTE_INDEX && remaining > 0;
      index -= 1
    ) {
      randomBytes[index] = remaining % BYTE_RADIX;
      remaining = Math.floor(remaining / BYTE_RADIX);
    }

    const id = generateUuidV7(this.currentTimestampMs, randomBytes);
    this.counter += 1;
    this.currentTimestampMs += this.stepMs;
    return id;
  }
}
