export const DEFAULT_LOCAL_SIGNING_SECRET = 'stanmieszkania-local-r2-dev-signing-secret';
const HEX_RADIX = 16;
const HEX_PAD_WIDTH = 2;
const BYTE_HIGH_NIBBLE_MASK = 0xff;
const textEncoder = new TextEncoder();

export function toHex(bytes: Uint8Array): string {
  let out = '';
  for (const byte of bytes) {
    out += (byte & BYTE_HIGH_NIBBLE_MASK).toString(HEX_RADIX).padStart(HEX_PAD_WIDTH, '0');
  }
  return out;
}

function fromHex(hex: string): Uint8Array<ArrayBuffer> | null {
  if (hex.length === 0 || hex.length % HEX_PAD_WIDTH !== 0 || !/^[0-9a-f]+$/i.test(hex)) {
    return null;
  }
  const bytes = new Uint8Array(new ArrayBuffer(hex.length / HEX_PAD_WIDTH));
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(
      hex.slice(index * HEX_PAD_WIDTH, (index + 1) * HEX_PAD_WIDTH),
      HEX_RADIX,
    );
  }
  return bytes;
}

async function importHmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    textEncoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify'],
  );
}

export function buildCanonicalSigningPayload(
  method: 'PUT' | 'GET',
  r2Key: string,
  expiresMs: number,
  bytes?: number,
  contentType?: string,
): string {
  return method === 'PUT'
    ? `PUT\n${r2Key}\n${String(expiresMs)}\n${String(bytes)}\n${contentType ?? ''}`
    : `GET\n${r2Key}\n${String(expiresMs)}`;
}

export async function signPayload(secret: string, payload: string): Promise<string> {
  const key = await importHmacKey(secret);
  const sig = await crypto.subtle.sign('HMAC', key, textEncoder.encode(payload));
  return toHex(new Uint8Array(sig));
}

export async function verifyLocalStorageSignature(params: {
  readonly method: string;
  readonly r2Key: string;
  readonly expiresMs: number;
  readonly bytes?: number;
  readonly contentType?: string;
  readonly signatureHex: string;
  readonly nowMs: number;
  readonly signingSecret?: string;
}): Promise<boolean> {
  if (!Number.isSafeInteger(params.expiresMs) || params.nowMs > params.expiresMs) return false;
  const normalizedMethod = params.method.toUpperCase();
  if (normalizedMethod !== 'PUT' && normalizedMethod !== 'GET') return false;
  if (
    normalizedMethod === 'PUT' &&
    (params.bytes === undefined ||
      !Number.isSafeInteger(params.bytes) ||
      params.bytes <= 0 ||
      params.contentType === undefined ||
      params.contentType.length === 0)
  ) {
    return false;
  }
  const sigBytes = fromHex(params.signatureHex);
  if (sigBytes === null) return false;
  const payload = buildCanonicalSigningPayload(
    normalizedMethod,
    params.r2Key,
    params.expiresMs,
    params.bytes,
    params.contentType,
  );
  const key = await importHmacKey(params.signingSecret ?? DEFAULT_LOCAL_SIGNING_SECRET);
  return crypto.subtle.verify('HMAC', key, sigBytes, textEncoder.encode(payload));
}
