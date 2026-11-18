export interface CursorPageRequest<TCursor = number> {
  readonly after?: TCursor;
  readonly limit?: number;
}

export interface CursorPage<TItem, TCursor = number> {
  readonly items: readonly TItem[];
  readonly nextCursor: TCursor | null;
  readonly hasMore: boolean;
}

// Architecture rule 5.2: exhaust cursor pages without artificial page caps.
export async function exhaustCursorPages<TItem, TCursor = number>(
  fetchPage: (cursor: TCursor | undefined) => Promise<CursorPage<TItem, TCursor>>,
  initialCursor?: TCursor,
): Promise<TItem[]> {
  const collected: TItem[] = [];
  let cursor: TCursor | undefined = initialCursor;
  let hasMore = true;

  while (hasMore) {
    const page = await fetchPage(cursor);
    collected.push(...page.items);
    hasMore = page.hasMore;

    if (hasMore) {
      // Guard against infinite loops if a server reports hasMore=true without advancing the cursor.
      if (page.nextCursor === null || Object.is(page.nextCursor, cursor)) {
        throw new Error('Cursor pagination reported hasMore=true without advancing nextCursor');
      }
      cursor = page.nextCursor;
    }
  }

  return collected;
}
