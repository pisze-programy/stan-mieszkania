import { mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { renderOpenApiYaml } from '../src/openapi';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const CONTRACTS_DIR = path.resolve(SCRIPT_DIR, '../../../../contracts');
const OPENAPI_OUTPUT_PATH = path.join(CONTRACTS_DIR, 'openapi.yaml');
const GITKEEP_PATH = path.join(CONTRACTS_DIR, '.gitkeep');

async function main(): Promise<void> {
  const yamlContent = renderOpenApiYaml();
  await mkdir(CONTRACTS_DIR, { recursive: true });
  await writeFile(OPENAPI_OUTPUT_PATH, yamlContent, 'utf8');
  await rm(GITKEEP_PATH, { force: true });
}

await main();
