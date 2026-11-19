import {
  BYTE_MASK,
  DATE_STAMP_LENGTH,
  HEX_BYTE_WIDTH,
  HEX_RADIX,
  R2_AWS_ALGORITHM,
  R2_AWS_REGION,
  R2_AWS_REQUEST_TYPE,
  R2_AWS_SERVICE,
  R2_EU_HOST_SUFFIX,
  R2_MAX_PRESIGN_EXPIRES_SECONDS,
  R2_MIN_PRESIGN_EXPIRES_SECONDS,
  R2_UNSIGNED_PAYLOAD,
  SECONDS_PER_MILLISECOND,
} from './r2-s3.constants';

export interface PresignR2UrlInput {
  readonly method: 'GET' | 'PUT';
  readonly accountId: string;
  readonly bucketName: string;
  readonly accessKeyId: string;
  readonly secretAccessKey: string;
  readonly r2Key: string;
  readonly nowMs: number;
  readonly expiresInMs: number;
  readonly contentType?: string;
  readonly contentLength?: number;
}

export interface PresignedR2Result {
  readonly url: string;
  readonly expiresAt: string;
}

const textEncoder = new TextEncoder();

export function toHex(bytes: Uint8Array): string {
  let out = '';
  for (const byte of bytes) {
    out += (byte & BYTE_MASK).toString(HEX_RADIX).padStart(HEX_BYTE_WIDTH, '0');
  }
  return out;
}

export function encodeRfc3986(value: string): string {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (ch) => `%${ch.charCodeAt(0).toString(HEX_RADIX).toUpperCase()}`,
  );
}

export function formatAmzDate(nowMs: number): {
  readonly amzDate: string;
  readonly dateStamp: string;
} {
  const iso = new Date(nowMs).toISOString();
  const compact = iso.replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
  return {
    amzDate: compact,
    dateStamp: compact.slice(0, DATE_STAMP_LENGTH),
  };
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', textEncoder.encode(value));
  return toHex(new Uint8Array(digest));
}

async function hmacSha256(
  keyBytes: Uint8Array<ArrayBuffer>,
  message: string,
): Promise<Uint8Array<ArrayBuffer>> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyBytes,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, textEncoder.encode(message));
  return new Uint8Array(sig);
}

async function deriveSigningKey(
  secretAccessKey: string,
  dateStamp: string,
): Promise<Uint8Array<ArrayBuffer>> {
  const kSecret = textEncoder.encode(`AWS4${secretAccessKey}`);
  const kDate = await hmacSha256(kSecret, dateStamp);
  const kRegion = await hmacSha256(kDate, R2_AWS_REGION);
  const kService = await hmacSha256(kRegion, R2_AWS_SERVICE);
  return hmacSha256(kService, R2_AWS_REQUEST_TYPE);
}

// Decision 6.5 (RODO EU jurisdiction): Presign S3v4 URLs against *.eu.r2.cloudflarestorage.com.
export async function presignR2Url(input: PresignR2UrlInput): Promise<PresignedR2Result> {
  const host = `${input.accountId}${R2_EU_HOST_SUFFIX}`;
  const encodedBucket = encodeRfc3986(input.bucketName);
  const encodedKey = input.r2Key
    .split('/')
    .map((segment) => encodeRfc3986(segment))
    .join('/');
  const canonicalUri = `/${encodedBucket}/${encodedKey}`;

  const rawExpiresSeconds = Math.ceil(input.expiresInMs / SECONDS_PER_MILLISECOND);
  const expiresSeconds = Math.min(
    R2_MAX_PRESIGN_EXPIRES_SECONDS,
    Math.max(R2_MIN_PRESIGN_EXPIRES_SECONDS, rawExpiresSeconds),
  );
  const { amzDate, dateStamp } = formatAmzDate(input.nowMs);
  const credentialScope = `${dateStamp}/${R2_AWS_REGION}/${R2_AWS_SERVICE}/${R2_AWS_REQUEST_TYPE}`;

  const headerPairs: [string, string][] = [['host', host]];
  if (input.method === 'PUT') {
    if (input.contentLength !== undefined) {
      headerPairs.push(['content-length', String(input.contentLength)]);
    }
    if (input.contentType !== undefined) {
      headerPairs.push(['content-type', input.contentType]);
    }
  }
  headerPairs.sort(([left], [right]) => left.localeCompare(right));

  const canonicalHeaders = `${headerPairs.map(([name, val]) => `${name}:${val}`).join('\n')}\n`;
  const signedHeaders = headerPairs.map(([name]) => name).join(';');

  const queryParams: [string, string][] = [
    ['X-Amz-Algorithm', R2_AWS_ALGORITHM],
    ['X-Amz-Credential', `${input.accessKeyId}/${credentialScope}`],
    ['X-Amz-Date', amzDate],
    ['X-Amz-Expires', String(expiresSeconds)],
    ['X-Amz-SignedHeaders', signedHeaders],
  ];
  queryParams.sort(([left], [right]) => left.localeCompare(right));
  const canonicalQueryString = queryParams
    .map(([key, value]) => `${encodeRfc3986(key)}=${encodeRfc3986(value)}`)
    .join('&');

  const canonicalRequest = [
    input.method,
    canonicalUri,
    canonicalQueryString,
    canonicalHeaders,
    signedHeaders,
    R2_UNSIGNED_PAYLOAD,
  ].join('\n');

  const canonicalHash = await sha256Hex(canonicalRequest);
  const stringToSign = [R2_AWS_ALGORITHM, amzDate, credentialScope, canonicalHash].join('\n');
  const signingKey = await deriveSigningKey(input.secretAccessKey, dateStamp);
  const signature = toHex(await hmacSha256(signingKey, stringToSign));

  const expiresAt = new Date(input.nowMs + expiresSeconds * SECONDS_PER_MILLISECOND).toISOString();
  return {
    url: `https://${host}${canonicalUri}?${canonicalQueryString}&X-Amz-Signature=${signature}`,
    expiresAt,
  };
}
