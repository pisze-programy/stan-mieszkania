import { describe, expect, it } from 'vitest';
import { exhaustCursorPages, type CursorPage } from './pagination';

describe('exhaustCursorPages', () => {
  it('collects all items across multiple pages until hasMore is false', async () => {
    const pages: Record<string, CursorPage<string>> = {
      initial: { items: ['a', 'b'], nextCursor: 2, hasMore: true },
      '2': { items: ['c', 'd'], nextCursor: 4, hasMore: true },
      '4': { items: ['e'], nextCursor: null, hasMore: false },
    };
    const seenCursors: Array<number | undefined> = [];

    const allItems = await exhaustCursorPages((cursor) => {
      seenCursors.push(cursor);
      const key = cursor === undefined ? 'initial' : String(cursor);
      const page = pages[key];
      if (page === undefined) {
        throw new Error(`Unexpected cursor: ${key}`);
      }
      return Promise.resolve(page);
    });

    expect(allItems).toEqual(['a', 'b', 'c', 'd', 'e']);
    expect(seenCursors).toEqual([undefined, 2, 4]);
  });

  it('respects an explicit initialCursor and handles empty final pages', async () => {
    const allItems = await exhaustCursorPages<string, string>(
      (cursor) =>
        Promise.resolve({
          items: cursor === 'c1' ? ['x'] : [],
          nextCursor: null,
          hasMore: false,
        }),
      'c1',
    );

    expect(allItems).toEqual(['x']);
  });

  it('throws if hasMore is true without an advancing cursor', async () => {
    await expect(
      exhaustCursorPages(() =>
        Promise.resolve({
          items: ['stuck'],
          nextCursor: null,
          hasMore: true,
        }),
      ),
    ).rejects.toThrow(/without advancing nextCursor/);

    await expect(
      exhaustCursorPages(
        (cursor) =>
          Promise.resolve({
            items: ['same'],
            nextCursor: cursor ?? 1,
            hasMore: true,
          }),
        1,
      ),
    ).rejects.toThrow(/without advancing nextCursor/);
  });
});
