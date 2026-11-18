import { isUuidV7 } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { SequentialUuidV7Generator } from './sequential-id-generator';

describe('SequentialUuidV7Generator', () => {
  it('emits deterministic, strictly increasing RFC 9562 UUIDv7 strings', () => {
    const firstRun = new SequentialUuidV7Generator();
    const secondRun = new SequentialUuidV7Generator();

    const firstIds = [firstRun.nextId(), firstRun.nextId(), firstRun.nextId()];
    const secondIds = [secondRun.nextId(), secondRun.nextId(), secondRun.nextId()];

    expect(firstIds).toEqual(secondIds);
    for (const id of firstIds) {
      expect(isUuidV7(id)).toBe(true);
    }

    const [first, second, third] = firstIds;
    expect(first).toBeDefined();
    expect(second).toBeDefined();
    expect(third).toBeDefined();
    if (first !== undefined && second !== undefined && third !== undefined) {
      expect(first < second).toBe(true);
      expect(second < third).toBe(true);
    }
  });

  it('advances timestamp when stepMs is configured', () => {
    const generator = new SequentialUuidV7Generator({
      timestampMs: 1_700_000_000_000,
      stepMs: 1_000,
      startCounter: 10,
    });

    const a = generator.nextId();
    const b = generator.nextId();

    expect(isUuidV7(a)).toBe(true);
    expect(isUuidV7(b)).toBe(true);
    expect(a.slice(0, 13)).not.toBe(b.slice(0, 13));
    expect(a < b).toBe(true);
  });
});
