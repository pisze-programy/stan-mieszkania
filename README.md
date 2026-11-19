# Stan Mieszkania

Stan Mieszkania documents apartment condition with shared photos, videos, numbered markers, and append-only notes.
Landlords and tenants record evidence together during move-in, tenancy, and move-out.

## Monorepo Structure

The repository contains four top-level directories:

- `backend/` contains the TypeScript Cloudflare Worker API, D1 SQL migrations, Durable Objects, and deployment scripts.
- `contracts/` contains the generated OpenAPI 3.0.3 specification (`contracts/openapi.yaml`).
- `ios/` contains the Swift 6.3 iOS app (`ios/StanMieszkania.xcodeproj`), XcodeGen specification (`ios/project.yml`), and local Swift packages (`Core` and `Features`).
- `docs/` contains the domain specification, architecture blueprint, and production integrations runbook.

## Prerequisites

Install these tools on macOS before you build or test the system:

- Node.js 22.0 or newer (verified on Node.js 26).
- `pnpm` 9.0 or newer.
- Xcode 26.6 or newer with Swift 6.3 and an iOS 26.5 simulator runtime.
- `swiftlint` installed at `/opt/homebrew/bin/swiftlint`.
- `xcodegen` to regenerate `ios/StanMieszkania.xcodeproj` after changes to `ios/project.yml`.

## Local Development

### Start the Local Backend

1. Open a terminal at the repository root.
2. Install backend dependencies:

```bash
pnpm --dir backend install
```

3. Copy the example environment file for local development:

```bash
cp backend/apps/api/.dev.vars.example backend/apps/api/.dev.vars
```

4. Apply all D1 SQL migrations to the local database:

```bash
pnpm --dir backend --filter @stanmieszkania/api exec wrangler d1 migrations apply stanmieszkania-local --local
```

5. Start the local Cloudflare Worker on `http://127.0.0.1:8787`:

```bash
pnpm --dir backend --filter @stanmieszkania/api exec wrangler dev --local --port 8787
```

The default `wrangler.jsonc` configuration sets `AUTH_MODE=local` and `STORAGE_MODE=local`.
In local mode, the API accepts `Authorization: Bearer dev:<uid>:<displayName>` tokens and stores media objects in local R2 storage.

### Run the iOS App in Local Dev Auth Mode

1. Open `ios/StanMieszkania.xcodeproj` in Xcode.
2. Select the `StanMieszkania` scheme with the `Debug` configuration.
3. Choose an iOS Simulator destination.
4. Press **Run** (`Cmd+R`).

The `Debug` configuration (`ios/App/Config/Debug.xcconfig`) sets `AUTH_MODE=local` and `API_BASE_URL=http://127.0.0.1:8787`.
Use the local sign-in screen in the iOS app to switch between landlord and tenant test accounts without Apple or Firebase credentials.

If you edit `ios/project.yml`, regenerate the Xcode project:

```bash
xcodegen generate --spec ios/project.yml
```

## Contract Codegen and Verification

### Regenerate Shared Contracts

Run these commands after any API schema or shared constant change:

```bash
pnpm --dir backend openapi:generate
pnpm --dir backend swift-constants:generate
```

`ios/Packages/Core/Sources/APIClient/openapi.yaml` links directly to `contracts/openapi.yaml`.
Swift builds regenerate typed API client models from that file automatically.

### Backend Verification

Run each backend quality check from the repository root:

```bash
pnpm --dir backend format:check
pnpm --dir backend typecheck
pnpm --dir backend lint
pnpm --dir backend test
pnpm --dir backend deploy:dry-run
```

### iOS Verification

Run the iOS lint and test commands from the repository root:

```bash
/opt/homebrew/bin/swiftlint lint --config ios/.swiftlint.yml --strict ios
/usr/bin/xcrun swift-format lint --configuration ios/.swift-format --strict --recursive ios
/usr/bin/swift test --package-path ios/Packages/Core
/usr/bin/swift test --package-path ios/Packages/Features
/usr/bin/xcodebuild test \
  -project ios/StanMieszkania.xcodeproj \
  -scheme StanMieszkania \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/sm-dd \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -skipMacroValidation -skipPackagePluginValidation
rm -rf /tmp/sm-dd
```

### Full-Stack Verification and Live Wire Roundtrip

Run one command to execute all contract drift checks, backend checks, live Swift-to-Worker HTTP roundtrip tests, and iOS checks:

```bash
pnpm --dir backend verify:fullstack
```

`verify:fullstack` starts an ephemeral local Cloudflare Worker backed by Miniflare 5 (`D1`, `R2`, `UserGuard`, and `ApartmentCoordinator`).
It then runs `LiveWorkerRoundtripTests` in `ios/Packages/Core` over real TCP HTTP against that Worker, stops the server, and executes the complete iOS verification suite.

## Documentation

- [Domain Specification](docs/domain.md) defines business rules, roles, markers, sync semantics, and privacy boundaries.
- [Architecture Blueprint](docs/architecture.md) defines the modular monolith backend, iOS TCA architecture, OpenAPI contract flow, and infrastructure layout.
- [Production Integrations Runbook](docs/integrations-runbook.md) gives step-by-step instructions to connect Apple Developer, Firebase Auth, Cloudflare EU services, and Xcode Release builds.
