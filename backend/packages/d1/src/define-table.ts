import type { ZodType } from 'zod';

export type TableColumns = Readonly<Record<string, string>>;

export interface TableSchemaDescriptor {
  readonly name: string;
  readonly columns: TableColumns;
  readonly rowSchema: ZodType;
}

export interface DefineTableInput<TName extends string, TColumns extends TableColumns, TRow> {
  readonly name: TName;
  readonly columns: TColumns;
  readonly rowSchema: ZodType<TRow>;
}

export interface TableDefinition<
  TName extends string = string,
  TColumns extends TableColumns = TableColumns,
  TRow = unknown,
> extends TableSchemaDescriptor {
  readonly name: TName;
  readonly columns: Readonly<TColumns>;
  readonly columnNames: readonly string[];
  readonly columnList: (tableAlias?: string) => string;
  readonly rowSchema: ZodType<TRow>;
}

export type TableRow<TTable extends TableDefinition> =
  TTable extends TableDefinition<string, TableColumns, infer TRow> ? TRow : never;

export function defineTable<const TName extends string, const TColumns extends TableColumns, TRow>(
  input: DefineTableInput<TName, TColumns, TRow>,
): TableDefinition<TName, TColumns, TRow> {
  const frozenColumns: Readonly<TColumns> = Object.freeze({ ...input.columns });
  const columnNames: readonly string[] = Object.freeze(Object.values<string>(frozenColumns));
  const plainColumnList = columnNames.join(', ');

  const columnList = (tableAlias?: string): string => {
    if (tableAlias === undefined || tableAlias.length === 0) {
      return plainColumnList;
    }
    return columnNames.map((column) => `${tableAlias}.${column}`).join(', ');
  };

  return Object.freeze({
    name: input.name,
    columns: frozenColumns,
    columnNames,
    columnList,
    rowSchema: input.rowSchema,
  });
}
