import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateSwiftDomainFiles } from '../src/openapi-swift-codegen';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(SCRIPT_DIR, '../../../..');
const OPENAPI_PATH = path.join(REPO_ROOT, 'contracts/openapi.yaml');
const SWIFT_GENERATED_DIR = path.join(REPO_ROOT, 'ios/Packages/Core/Sources/Domain/Generated');
const CONTRACT_CONSTANTS_PATH = path.join(SWIFT_GENERATED_DIR, 'ContractConstants.swift');
const DOMAIN_ERROR_CODE_PATH = path.join(SWIFT_GENERATED_DIR, 'DomainErrorCode.swift');

async function main(): Promise<void> {
  const openApiYaml = await readFile(OPENAPI_PATH, 'utf8');
  const { contractConstantsSwift, domainErrorCodeSwift } = generateSwiftDomainFiles(openApiYaml);
  await mkdir(SWIFT_GENERATED_DIR, { recursive: true });
  await Promise.all([
    writeFile(CONTRACT_CONSTANTS_PATH, contractConstantsSwift, 'utf8'),
    writeFile(DOMAIN_ERROR_CODE_PATH, domainErrorCodeSwift, 'utf8'),
  ]);
}

await main();
