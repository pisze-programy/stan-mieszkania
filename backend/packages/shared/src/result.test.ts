import { describe, expect, it } from 'vitest';
import { andThen, err, isErr, isOk, mapError, mapResult, ok, type Result } from './result';

describe('Result', () => {
  it('constructs Ok and Err variants and narrows with type guards', () => {
    const success: Result<number, string> = ok(42);
    const failure: Result<number, string> = err('BAD_INPUT');

    expect(isOk(success)).toBe(true);
    expect(isErr(success)).toBe(false);
    if (isOk(success)) {
      expect(success.value).toBe(42);
    }

    expect(isErr(failure)).toBe(true);
    expect(isOk(failure)).toBe(false);
    if (isErr(failure)) {
      expect(failure.error).toBe('BAD_INPUT');
    }
  });

  it('supports void ok() without arguments', () => {
    const empty: Result<void, string> = ok();
    expect(isOk(empty)).toBe(true);
    if (isOk(empty)) {
      expect(empty.value).toBeUndefined();
    }
  });

  it('maps Ok values and short-circuits Err in mapResult', () => {
    const doubled = mapResult(ok(21), (value) => value * 2);
    expect(doubled).toEqual(ok(42));

    const unchanged = mapResult<number, number, string>(err('FAIL'), (value) => value * 2);
    expect(unchanged).toEqual(err('FAIL'));
  });

  it('maps Err values and preserves Ok in mapError', () => {
    const mappedErr = mapError<number, string, string>(err('NOT_FOUND'), (code) => `ERR:${code}`);
    expect(mappedErr).toEqual(err('ERR:NOT_FOUND'));

    const preservedOk = mapError<number, string, string>(ok(10), (code) => `ERR:${code}`);
    expect(preservedOk).toEqual(ok(10));
  });

  it('chains Result-returning operations with andThen', () => {
    const divide = (dividend: number, divisor: number): Result<number, 'DIV_BY_ZERO'> =>
      divisor === 0 ? err('DIV_BY_ZERO') : ok(dividend / divisor);

    const chainedOk = andThen<number, number, 'INVALID', 'DIV_BY_ZERO'>(ok(20), (value) =>
      divide(value, 4),
    );
    expect(chainedOk).toEqual(ok(5));

    const chainedShortCircuit = andThen<number, number, 'INVALID', 'DIV_BY_ZERO'>(
      err('INVALID'),
      (value) => divide(value, 4),
    );
    expect(chainedShortCircuit).toEqual(err('INVALID'));

    const chainedInnerErr = andThen<number, number, 'INVALID', 'DIV_BY_ZERO'>(ok(20), (value) =>
      divide(value, 0),
    );
    expect(chainedInnerErr).toEqual(err('DIV_BY_ZERO'));
  });
});
