# Stan Mieszkania — Production Integrations Runbook

This runbook gives step-by-step procedures to connect Apple Developer, Firebase Auth, Cloudflare EU services, and Xcode Release builds for Stan Mieszkania.

## Prerequisites

- An active Apple Developer Program account.
- A Google Cloud / Firebase project.
- A Cloudflare account with Workers Paid, D1, R2, and Durable Objects enabled.
- macOS with Xcode 26+, Node.js 22+, `pnpm` 9+, and `wrangler` CLI authenticated (`pnpm --filter @stanmieszkania/api exec wrangler login`).

---

## Section 1: Apple Developer Configuration

### 1.1 Register the App ID

1. Open the Apple Developer portal and select **Certificates, Identifiers & Profiles**.
2. Select **Identifiers** and click the **+** button.
3. Select **App IDs** and click **Continue**.
4. Select **App** and click **Continue**.
5. Enter `Stan Mieszkania` in **Description**.
6. Enter `pl.stanmieszkania.app` in **Explicit Bundle ID**.
7. Enable the **Sign in with Apple** capability.
8. Click **Continue**, then click **Register**.
9. Record your 10-character Team ID as `APPLE_TEAM_ID`.
10. Record `pl.stanmieszkania.app` as `APPLE_CLIENT_ID`.

### 1.2 Create the Sign in with Apple Revocation Key (`.p8`)

The backend uses this key to sign an ES256 client secret and call `https://appleid.apple.com/auth/revoke` during account deletion.

1. In **Certificates, Identifiers & Profiles**, select **Keys** and click the **+** button.
2. Enter `Stan Mieszkania SIwA Revoke` in **Key Name**.
3. Enable **Sign in with Apple**.
4. Click **Configure** next to **Sign in with Apple**.
5. Select `pl.stanmieszkania.app` as the **Primary App ID** and click **Save**.
6. Click **Continue**, then click **Register**.
7. Record the 10-character Key ID as `APPLE_KEY_ID`.
8. Click **Download** to save the `.p8` private key file.
9. Store the full PEM contents of the `.p8` file as `APPLE_PRIVATE_KEY_PEM`.
10. Delete the `.p8` file from insecure folders after storing the secret in Cloudflare.

---

## Section 2: Firebase Auth Configuration

### 2.1 Enable Sign in with Apple in Firebase

1. Open the Firebase Console and select your production project.
2. Record the project ID as `FIREBASE_PROJECT_ID`.
3. Open **Build -> Authentication -> Sign-in method**.
4. Click **Add new provider** and select **Apple**.
5. Toggle **Enable** to ON.
6. Click **Save**.

### 2.2 Register the iOS App and Download `GoogleService-Info.plist`

1. Open **Project settings -> General**.
2. Click **Add app** and select **iOS**.
3. Enter `pl.stanmieszkania.app` as the **Apple bundle ID**.
4. Click **Register app**.
5. Click **Download GoogleService-Info.plist**.
6. Place the downloaded file at `ios/App/GoogleService-Info.plist` (compare keys against `ios/App/Config/GoogleService-Info.template.plist`).
7. Verify that `git status` does not list `ios/App/GoogleService-Info.plist` (`.gitignore` excludes it).
8. Optional alternative: copy `API_KEY` from `GoogleService-Info.plist` into `FIREBASE_WEB_API_KEY` in `ios/App/Config/Release.xcconfig` without committing the key.

### 2.3 Create the Service Account for Account Deletion

The backend uses this service account to call Firebase Identity Toolkit `accounts:delete`.

1. Open **Project settings -> Service accounts**.
2. Click **Generate new private key**, then click **Generate key**.
3. Open the downloaded JSON file.
4. Record `client_email` as `FIREBASE_CLIENT_EMAIL`.
5. Record `private_key` (including `BEGIN PRIVATE KEY` and `END PRIVATE KEY` headers) as `FIREBASE_PRIVATE_KEY_PEM`.
6. Delete the downloaded JSON file after storing the secrets in Cloudflare.

---

## Section 3: Cloudflare EU Setup and Deployment

### 3.1 Create the EU D1 Database

1. Open a terminal in `backend/apps/api`.
2. Run the D1 create command with the Western Europe location hint:

   ```bash
   pnpm exec wrangler d1 create stanmieszkania-production --location=weur
   ```

3. Copy the returned `database_id` UUID from the command output.
4. Open `backend/apps/api/wrangler.jsonc`.
5. Under `env.production.d1_databases[0]`, replace `database_id` with the new UUID.

### 3.2 Create the EU R2 Bucket and S3 API Token

1. In `backend/apps/api`, create the R2 bucket with EU jurisdiction:

   ```bash
   pnpm exec wrangler r2 bucket create stanmieszkania-media-production --jurisdiction=eu
   ```

2. Open the Cloudflare Dashboard and select **R2 Object Storage**.
3. Record your Cloudflare Account ID as `R2_ACCOUNT_ID`.
4. Record `stanmieszkania-media-production` as `R2_BUCKET_NAME`.
5. Click **Manage R2 API Tokens**, then click **Create API token**.
6. Enter `stanmieszkania-media-presign` in **Token name**.
7. Select **Object Read & Write** permissions.
8. Restrict **Specify bucket(s)** to `stanmieszkania-media-production`.
9. Click **Create API Token**.
10. Record **Access Key ID** as `R2_ACCESS_KEY_ID`.
11. Record **Secret Access Key** as `R2_SECRET_ACCESS_KEY`.

### 3.3 Configure Cloudflare Production Secrets

1. Open a terminal in `backend/apps/api`.
2. Run `wrangler secret put` for each of the 11 production secrets (refer to `backend/apps/api/.dev.vars.example` for exact names):

   ```bash
   pnpm exec wrangler secret put FIREBASE_PROJECT_ID --env production
   pnpm exec wrangler secret put FIREBASE_CLIENT_EMAIL --env production
   pnpm exec wrangler secret put FIREBASE_PRIVATE_KEY_PEM --env production
   pnpm exec wrangler secret put APPLE_TEAM_ID --env production
   pnpm exec wrangler secret put APPLE_CLIENT_ID --env production
   pnpm exec wrangler secret put APPLE_KEY_ID --env production
   pnpm exec wrangler secret put APPLE_PRIVATE_KEY_PEM --env production
   pnpm exec wrangler secret put R2_ACCOUNT_ID --env production
   pnpm exec wrangler secret put R2_BUCKET_NAME --env production
   pnpm exec wrangler secret put R2_ACCESS_KEY_ID --env production
   pnpm exec wrangler secret put R2_SECRET_ACCESS_KEY --env production
   ```

3. Bind your custom domain (`api.stanmieszkania.pl`) to the `stanmieszkania-api-production` Worker in the Cloudflare Dashboard under **Workers & Pages -> Settings -> Domains & Routes**.

### 3.4 Verify and Deploy Backend

1. Open a terminal in `backend`.
2. Run the dry-run deployment gate (runs `format:check`, `typecheck`, `lint`, `test`, and additive SQL migration verification):

   ```bash
   pnpm deploy:dry-run
   ```

3. Confirm that `pnpm deploy:dry-run` exits with code `0`.
4. Run the production deployment script (records a D1 Time Travel bookmark in `backend/.deploy-bookmarks/`, applies remote D1 migrations, and deploys the Worker):

   ```bash
   pnpm deploy:production
   ```

5. Verify the live config endpoint returns HTTP `200`:

   ```bash
   curl -fsS https://api.stanmieszkania.pl/v1/config
   ```

---

## Section 4: Xcode Release Archive and App Store Connect Checklist

### 4.1 Prepare and Archive the Release Build

1. Confirm `ios/App/GoogleService-Info.plist` exists locally (or `FIREBASE_WEB_API_KEY` is set in `ios/App/Config/Release.xcconfig`).
2. Confirm `ios/App/Config/Release.xcconfig` contains:
   - `PRODUCT_BUNDLE_IDENTIFIER = pl.stanmieszkania.app`
   - `API_BASE_URL = https:/$()/api.stanmieszkania.pl`
   - `AUTH_MODE = firebase`
   - 3-part SemVer `MARKETING_VERSION` (for example `1.0.0`) and incremented `CURRENT_PROJECT_VERSION`.
3. Regenerate the Xcode project if `ios/project.yml` or resources changed:

   ```bash
   xcodegen generate --spec ios/project.yml
   ```

4. Open `ios/StanMieszkania.xcodeproj` in Xcode.
5. Select the `StanMieszkania` target and open **Signing & Capabilities**.
6. Set **Team** to your Apple Developer Team (`APPLE_TEAM_ID`).
7. Confirm **Sign in with Apple** appears under **Capabilities** (`ios/App/StanMieszkania.entitlements`).
8. Select **Any iOS Device (arm64)** as the build destination.
9. Click **Product -> Archive**.
10. In **Organizer**, click **Validate App**, then click **Distribute App -> App Store Connect -> Upload**.

### 4.2 App Store Connect App Privacy Checklist

Ensure App Store Connect App Privacy declarations match `ios/App/PrivacyInfo.xcprivacy`:

1. Confirm **Data Used to Track You** is set to **No** (`NSPrivacyTracking = false`).
2. Declare **User ID** (`NSPrivacyCollectedDataTypeUserID`): **Linked to User = Yes**, **Tracking = No**, **Purpose = App Functionality**.
3. Declare **Name** (`NSPrivacyCollectedDataTypeName`): **Linked to User = Yes**, **Tracking = No**, **Purpose = App Functionality**.
4. Declare **Photos or Videos** (`NSPrivacyCollectedDataTypePhotosorVideos`): **Linked to User = Yes**, **Tracking = No**, **Purpose = App Functionality**.
5. Declare **Precise Location** (`NSPrivacyCollectedDataTypePreciseLocation`): **Linked to User = Yes**, **Tracking = No**, **Purpose = App Functionality** (optional capture verification metadata; never displayed in UI).
6. Confirm Required Reason APIs in `ios/App/PrivacyInfo.xcprivacy` declare `UserDefaults` (`CA92.1`), `FileTimestamp` (`C617.1`), and `DiskSpace` (`E174.1`).
7. Confirm App Review Notes explain the two-step in-app account deletion path (**Profil -> Usuń konto**) for App Review Guideline 5.1.1(v).
