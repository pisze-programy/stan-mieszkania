import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { ALL_DOMAIN_ERROR_CODES } from '../openapi';
import { generateSwiftDomainFiles } from '../openapi-swift-codegen';

const TEST_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(TEST_DIR, '../../../../..');
const OPENAPI_PATH = path.join(REPO_ROOT, 'contracts/openapi.yaml');
const SWIFT_GENERATED_DIR = path.join(REPO_ROOT, 'ios/Packages/Core/Sources/Domain/Generated');
const CONTRACT_CONSTANTS_PATH = path.join(SWIFT_GENERATED_DIR, 'ContractConstants.swift');
const DOMAIN_ERROR_CODE_PATH = path.join(SWIFT_GENERATED_DIR, 'DomainErrorCode.swift');

describe('Swift domain constants & error codes contract', () => {
  it('matches generated ContractConstants.swift and DomainErrorCode.swift byte-for-byte with zero drift', async () => {
    const [openApiYaml, committedConstants, committedErrorCodes] = await Promise.all([
      readFile(OPENAPI_PATH, 'utf8'),
      readFile(CONTRACT_CONSTANTS_PATH, 'utf8'),
      readFile(DOMAIN_ERROR_CODE_PATH, 'utf8'),
    ]);

    const generated = generateSwiftDomainFiles(openApiYaml);

    expect(committedConstants).toBe(generated.contractConstantsSwift);
    expect(committedErrorCodes).toBe(generated.domainErrorCodeSwift);
    expect(generated.domainErrorCodes).toHaveLength(ALL_DOMAIN_ERROR_CODES.length);
    expect(generated.domainErrorCodes).toEqual([...ALL_DOMAIN_ERROR_CODES]);
    for (const code of ALL_DOMAIN_ERROR_CODES) {
      expect(committedErrorCodes).toContain(`"${code}"`);
    }
    expect(committedErrorCodes).toContain('case unknown(String)');
    expect(committedConstants).toContain('public enum ContractConstants: Sendable');
  });
});
