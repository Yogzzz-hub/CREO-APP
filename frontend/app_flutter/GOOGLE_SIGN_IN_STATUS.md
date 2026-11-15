# Google sign-in checkpoint

The incorrect creo.agency override is removed. Secure native Google sign-in is now implemented in source using the deployed web /app-oauth bridge, native Android/iOS PKCE generation, strict pending-state validation, one-use code exchange, cancellation/expiry, and the existing AuthSession storage/navigation owner. New Google clients keep the backend's client role behavior; existing roles are preserved.

The backend extension is optional and backward-compatible with existing web requests. See ../../backend/GOOGLE_MOBILE_OAUTH.md for the exact protocol, deployment order and verification limits.

**Live status: blocked on deployment.** After resuming, the Render capability check returned false. No production backend deployment or Google account consent has been performed. Full live sign-in is not claimed.

Verification: 288 Flutter tests and 10 isolated backend checks passed; normal Android APK compiled. Complete backend tests require missing local structlog; emulator runtime and iOS remain unverified. The temporary native probe was not installed; the normal app artifact is restored.

## Publication after resuming

Backend-only commit 68af39b15260de39388debdcd19ca6e5b0e1a028 was approved and pushed to Yogzzz-hub/CREO-APP main. GitHub confirms exactly three changed files: backend/app/routers/auth.py, backend/tests/test_google_pkce_isolated.py and backend/GOOGLE_MOBILE_OAUTH.md. It was prepared from latest main in a separate checkout so newer repository changes and the active Flutter working tree were preserved. Compatibility checks passed again in that checkout.

The live Render root still reports revision e84e0a430a42d7db341eec1ce3fd52a2d61085c1, and the mobile capability remains false. That revision cannot currently be resolved in CREO-APP through GitHub. Render's linked repository/branch or deployment settings need confirmation before further deployment actions. No Render settings were changed.

The existing emulator was launched without resetting data but remained offline after a reconnect. The temporary native probe was built but not installed. The normal lib/main.dart APK was restored and rebuilt successfully.

## Native Android Google sign-in — 2026-11-14

Android now selects `AndroidGoogleSignInFlow` from the normal authentication screen. It loads the supplied public registration from `assets/auth/google_android_client.json`, verifies that Android and server client IDs belong to the same Cloud project, and uses `google_sign_in` 7.2.0 to select an account and request a server authorization code. Google resolves the Android registration from `com.example.app_flutter` and the build signing certificate. The SDK's `serverClientId` is the backend's existing Web client ID, as required by the official Android plugin.

The server code is sent to the optional POST `/api/v1/auth/google/android/callback`. A public GET `/api/v1/auth/google/android/config` supplies the server audience. Shared backend account linking, roles, suspension checks and session issuance are reused. The same Flutter AuthSession owns adoption and rejects cancelled, disposed, timed-out, logged-out and stale operations. Account-picker errors are surfaced without storing Google tokens or logging codes. Pending provider UI must be dismissed before a second native picker can start.

The original JSON contains public registration fields only. The asset contains only client_id and project_id. Server client secrets remain server-owned. The native SDK uses a server code without browser deep-link transport. iOS continues through the existing browser PKCE implementation.

Backend extension is submitted as [PR #73](https://github.com/Yogzzz-hub/creo/pull/73), commit `3361de1f`. Until it merges and deploys, the new Android button shows a setup-pending error before opening account selection. Native production sign-in has not been verified.

Verification passed 14 isolated backend compatibility tests, 35 focused Flutter auth tests, and the full 301-test Flutter suite. An additional normal-app native-entry regression was added afterward and the native file then passed all 11 tests. Android debug APK build passed after disabling Kotlin incremental compilation for the Windows cross-drive Pub cache and using already-installed NDK 28.2.13676358. Static analysis had no errors, two existing BDE warnings and informational notices. Real provider account selection, code exchange and release signing require device/configuration verification after deployment.

## Physical-device check before publication — 2026-11-15

Native Google account selection and return to the signed-in client onboarding screen were observed on the authorized Android phone. Admin password login, the server-loaded client roster and client activation detail were also exercised. The test client subscription remained active after switching accounts and signing in again. The client portal is still gated by incomplete brand onboarding. Authorized sample questionnaire sections A through C were saved, while remaining setup and final portal entry were not verified before switching to publication. Earlier deployment-pending notes describe the state at the time those checks ran.
