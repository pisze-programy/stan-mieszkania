export type ErrorDetails = Readonly<Record<string, unknown>>;

export interface DomainError<TCode extends string = string> {
  readonly code: TCode;
  readonly message: string;
  readonly details?: ErrorDetails;
}

export function createDomainError<TCode extends string>(
  code: TCode,
  message: string,
  details?: ErrorDetails,
): DomainError<TCode> {
  if (details === undefined) {
    return { code, message };
  }
  return { code, message, details };
}
