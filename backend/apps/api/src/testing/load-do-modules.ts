import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import path from 'node:path';

export interface MiniflareEsmModule {
  readonly type: 'esm';
  readonly contents: string;
}

const WORKER_ENTRY_SCRIPT = [
  "export { UserGuard } from './user-guard.durable-object.js';",
  "export { ApartmentCoordinator } from './apartment-coordinator.durable-object.js';",
  'export default { fetch() { return new Response("ok"); } };',
].join('\n');

function rewriteRelativeImports(jsSource: string, baseNames: readonly string[]): string {
  let result = jsSource;
  for (const baseName of baseNames) {
    result = result.replaceAll(`'./${baseName}'`, `'./${baseName}.js'`);
  }
  return result;
}

export async function loadDurableObjectManifestModules(
  durableObjectsDir: string,
): Promise<Record<string, MiniflareEsmModule>> {
  const fileBaseNames = [
    'user-guard.constants',
    'user-guard.durable-object',
    'apartment-coordinator.constants',
    'apartment-coordinator.maintenance',
    'lease-lock-queue',
    'apartment-coordinator.durable-object',
  ] as const;

  const sources = await Promise.all(
    fileBaseNames.map(async (baseName) => {
      const tsSource = await readFile(path.join(durableObjectsDir, `${baseName}.ts`), 'utf8');
      const stripped = stripTypeScriptTypes(tsSource);
      const rewritten = rewriteRelativeImports(stripped, fileBaseNames);
      return [baseName, rewritten] as const;
    }),
  );

  const modules: Record<string, MiniflareEsmModule> = {
    'index.js': {
      type: 'esm',
      contents: WORKER_ENTRY_SCRIPT,
    },
  };

  for (const [baseName, contents] of sources) {
    modules[`${baseName}.js`] = {
      type: 'esm',
      contents,
    };
  }

  return modules;
}
