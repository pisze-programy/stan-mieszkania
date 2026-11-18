import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { ENTRY_ERROR_CODES } from './entries.errors';
import { assignGlobalMarkerNumbers } from './marker-numbering.policy';

describe('assignGlobalMarkerNumbers', () => {
  it('rewrites overlapping local marker ranges in a single pass without cascading', () => {
    const result = assignGlobalMarkerNumbers({
      entryId: 'entry-1',
      mediaId: 'media-1',
      text: 'Scratch [2] near dent [3], repeating [2] and leaving [99] and [02] untouched.',
      draftMarkers: [
        { id: 'mk-a', localNumber: 2, x: 0.2, y: 0.3 },
        { id: 'mk-b', localNumber: 3, x: 0.7, y: 0.8 },
      ],
      currentMaxMarkerNumber: 2,
    });

    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value.text).toBe(
        'Scratch [3] near dent [4], repeating [3] and leaving [99] and [02] untouched.',
      );
      expect(result.value.markers).toEqual([
        { id: 'mk-a', entryId: 'entry-1', mediaId: 'media-1', number: 3, x: 0.2, y: 0.3 },
        { id: 'mk-b', entryId: 'entry-1', mediaId: 'media-1', number: 4, x: 0.7, y: 0.8 },
      ]);
      expect(result.value.numberMapping).toEqual([
        { localNumber: 2, assignedNumber: 3, markerId: 'mk-a' },
        { localNumber: 3, assignedNumber: 4, markerId: 'mk-b' },
      ]);
      expect(result.value.nextMaxMarkerNumber).toBe(4);
    }
  });

  it('assigns monotonic global numbers across multiple authors and entries', () => {
    const firstAuthor = assignGlobalMarkerNumbers({
      entryId: 'entry-a',
      mediaId: 'media-1',
      text: 'Door crack [1] and floor stain [2]',
      draftMarkers: [
        { id: 'mk-1', localNumber: 1, x: 0.1, y: 0.2 },
        { id: 'mk-2', localNumber: 2, x: 0.8, y: 0.9 },
      ],
      currentMaxMarkerNumber: 0,
    });
    expect(isOk(firstAuthor)).toBe(true);
    if (!isOk(firstAuthor)) {
      return;
    }

    expect(firstAuthor.value.text).toBe('Door crack [1] and floor stain [2]');
    expect(firstAuthor.value.nextMaxMarkerNumber).toBe(2);

    const secondAuthor = assignGlobalMarkerNumbers({
      entryId: 'entry-b',
      mediaId: 'media-1',
      text: 'Also chipped paint [1] right next to [1]',
      draftMarkers: [{ id: 'mk-3', localNumber: 1, x: 0.4, y: 0.5 }],
      currentMaxMarkerNumber: firstAuthor.value.nextMaxMarkerNumber,
    });
    expect(isOk(secondAuthor)).toBe(true);
    if (isOk(secondAuthor)) {
      expect(secondAuthor.value.text).toBe('Also chipped paint [3] right next to [3]');
      expect(secondAuthor.value.markers.map((marker) => marker.number)).toEqual([3]);
      expect(secondAuthor.value.nextMaxMarkerNumber).toBe(3);
    }
  });

  it('keeps text unchanged when draftMarkers is empty and rejects negative max number', () => {
    const emptyResult = assignGlobalMarkerNumbers({
      entryId: 'entry-c',
      mediaId: 'media-1',
      text: 'No markers here, reference [1] stays verbatim',
      draftMarkers: [],
      currentMaxMarkerNumber: 5,
    });
    expect(isOk(emptyResult)).toBe(true);
    if (isOk(emptyResult)) {
      expect(emptyResult.value.text).toBe('No markers here, reference [1] stays verbatim');
      expect(emptyResult.value.markers).toEqual([]);
      expect(emptyResult.value.nextMaxMarkerNumber).toBe(5);
    }

    const negativeMax = assignGlobalMarkerNumbers({
      entryId: 'entry-d',
      mediaId: 'media-1',
      text: 'Invalid max',
      draftMarkers: [],
      currentMaxMarkerNumber: -1,
    });
    expect(isErr(negativeMax)).toBe(true);
    if (isErr(negativeMax)) {
      expect(negativeMax.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_VALIDATION_FAILED);
    }
  });
});
