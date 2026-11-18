import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { ENTRY_ERROR_CODES } from './entries.errors';
import { validateDraftMarkers } from './marker.entity';

describe('validateDraftMarkers', () => {
  it('accepts valid markers including exact coordinate boundaries 0 and 1', () => {
    const markers = [
      { id: 'mk-1', localNumber: 1, x: 0, y: 0 },
      { id: 'mk-2', localNumber: 2, x: 0.5, y: 0.25 },
      { id: 'mk-3', localNumber: 5, x: 1, y: 1 },
    ];

    const result = validateDraftMarkers(markers);
    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value).toEqual(markers);
    }
  });

  it('rejects duplicate localNumber values with MARKER_DUPLICATE_LOCAL_NUMBER', () => {
    const result = validateDraftMarkers([
      { id: 'mk-1', localNumber: 2, x: 0.2, y: 0.3 },
      { id: 'mk-2', localNumber: 2, x: 0.6, y: 0.7 },
    ]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(ENTRY_ERROR_CODES.MARKER_DUPLICATE_LOCAL_NUMBER);
      expect(result.error.details).toEqual({ localNumber: 2 });
    }
  });

  it('rejects out-of-bounds or non-finite coordinates with MARKER_INVALID_COORDINATES', () => {
    for (const [x, y] of [
      [-0.01, 0.5],
      [1.01, 0.5],
      [0.5, -0.001],
      [0.5, 1.5],
      [Number.NaN, 0.5],
      [0.5, Number.POSITIVE_INFINITY],
    ] as const) {
      const result = validateDraftMarkers([{ id: 'mk-1', localNumber: 1, x, y }]);
      expect(isErr(result)).toBe(true);
      if (isErr(result)) {
        expect(result.error.code).toBe(ENTRY_ERROR_CODES.MARKER_INVALID_COORDINATES);
      }
    }
  });

  it('rejects non-positive localNumber, blank id, and duplicate id with ENTRY_VALIDATION_FAILED', () => {
    for (const invalidBatch of [
      [{ id: 'mk-1', localNumber: 0, x: 0.5, y: 0.5 }],
      [{ id: 'mk-1', localNumber: -1, x: 0.5, y: 0.5 }],
      [{ id: 'mk-1', localNumber: 1.5, x: 0.5, y: 0.5 }],
      [{ id: '   ', localNumber: 1, x: 0.5, y: 0.5 }],
      [
        { id: 'mk-dup', localNumber: 1, x: 0.1, y: 0.1 },
        { id: 'mk-dup', localNumber: 2, x: 0.2, y: 0.2 },
      ],
    ]) {
      const result = validateDraftMarkers(invalidBatch);
      expect(isErr(result)).toBe(true);
      if (isErr(result)) {
        expect(result.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_VALIDATION_FAILED);
      }
    }
  });
});
